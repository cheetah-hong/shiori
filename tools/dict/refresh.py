#!/usr/bin/env python3
"""Refresh the app's dictionary assets from the latest sources, behind an accuracy gate.

  python3 tools/dict/refresh.py [--assets app/assets/dict] [--work tools/dict/.cache/refresh]
                                [--krdict-source <JSON zip>] [--dry-run]

Steps (docs/dictionary.md, 정기 갱신):
  1. JMdict: a conditional request (If-Modified-Since: the edition's Last-Modified).
     304, or the same file again: unchanged.
  2. The Basic Korean Dictionary is downloaded by hand (its site refuses scripts):
     --krdict-source gives the zip; the same sha256 as the edition is unchanged.
  3. Nothing changed: "변화 없음", no file is touched (exit 0).
  4. A changed source is downloaded completely (length, gzip, header date) or nothing
     is touched (exit 2). The new assets are built next to the old ones in --work and
     checked (asset_check.py).
  5. Accuracy gate: the word extractor's score table with the old and the new assets
     on the same code (packages/jmdict_block/tool/eval_extract_dict.dart), then the
     local floor tests with the new assets. Worse anywhere: not adopted (exit 1).
  6. Passed: the new assets replace the old ones in --assets (unless --dry-run).
A report (report.md, report.json) is written to --work either way.
Only the Python 3 standard library is used; the gate runs `dart`.
"""
from __future__ import annotations

import argparse
import datetime as dt
import gzip
import hashlib
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import urllib.error
import urllib.request
import zipfile
import zlib
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Callable, Protocol

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import asset_check  # noqa: E402
import build_app_asset  # noqa: E402
import build_jmdict_db as jmdict  # noqa: E402
import build_ko_glossary  # noqa: E402

REPO = HERE.parent.parent
DEFAULT_ASSETS = REPO / "app" / "assets" / "dict"
DEFAULT_WORK = HERE / ".cache" / "refresh"
JMDICT = "jmdict-full-lean"
KRDICT = "ko-glossary"
KRDICT_PAGE = build_ko_glossary.KRDICT["url"]

# Outcome status -> exit code.
EXIT_CODES = {"unchanged": 0, "adopted": 0, "candidate": 0, "rejected": 1, "failed": 2}
STATUS_TEXT = {
    "unchanged": "변화 없음",
    "adopted": "새 판 채택",
    "candidate": "관문 통과, 채택하지 않음 (--dry-run)",
    "rejected": "관문 미달, 채택하지 않음",
    "failed": "실패 (assets는 그대로; 채택 중 실패면 이유에 바뀐 사전을 적음)",
}


class FetchError(Exception):
    """The download did not complete."""


class RefreshFailed(Exception):
    """A step failed; nothing in the assets folder was touched."""


@dataclass(frozen=True)
class Download:
    """A completed response body: its Last-Modified and Content-Length headers."""
    last_modified: str
    content_length: int | None


class Fetcher(Protocol):
    def get(self, url: str, dest: Path, *, if_modified_since: str | None) -> Download | None:
        """Write the body to [dest] and return its headers; None when not modified (304).
        Raises FetchError when the download fails."""


@dataclass(frozen=True)
class GateResult:
    passed: bool
    reasons: tuple[str, ...] = ()
    rows: tuple[dict, ...] = ()


# (folder of the current assets, folder of the new assets, work folder) -> result
Gate = Callable[[Path, Path, Path], GateResult]


@dataclass(frozen=True)
class Outcome:
    status: str                 # unchanged | adopted | candidate | rejected | failed
    reasons: tuple[str, ...]    # why (failed, rejected) or what was done
    changed: tuple[str, ...]    # asset names rebuilt from a new source
    report: Path | None         # report.md in the work folder


@dataclass
class _Run:
    """What a refresh found, for the report."""
    built_on: str
    notes: list[str] = field(default_factory=list)
    old: dict = field(default_factory=dict)
    new: dict = field(default_factory=dict)
    changed: list[str] = field(default_factory=list)
    gate: GateResult | None = None


# ------------------------------------------------------------------ download


class UrlFetcher:
    """HTTPS download with a conditional request (urllib, the standard library)."""

    def __init__(self, timeout: float = 120) -> None:
        self.timeout = timeout

    def get(self, url: str, dest: Path, *, if_modified_since: str | None) -> Download | None:
        if not url.startswith("https://"):
            raise FetchError(f"{url} is not https")
        headers = {"If-Modified-Since": if_modified_since} if if_modified_since else {}
        request = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as r, dest.open("wb") as f:  # noqa: S310
                shutil.copyfileobj(r, f)
                length = r.headers.get("Content-Length")
                return Download(last_modified=r.headers.get("Last-Modified", ""),
                                content_length=int(length) if length and length.isdigit() else None)
        except urllib.error.HTTPError as e:
            if e.code == 304:
                return None
            raise FetchError(f"{url}: HTTP {e.code}") from e
        except (urllib.error.URLError, OSError, ValueError) as e:
            raise FetchError(f"{url}: {e}") from e


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def _check_jmdict_download(path: Path, got: Download) -> None:
    """Complete (length, gzip stream and CRC) and a JMdict file (header date)."""
    size = path.stat().st_size
    if got.content_length is not None and size != got.content_length:
        raise RefreshFailed(f"JMdict download cut short: {size} of {got.content_length} bytes")
    try:
        text = jmdict.decompress(path.read_bytes()).decode("utf-8")
    except (OSError, EOFError, zlib.error, UnicodeDecodeError) as e:
        raise RefreshFailed(f"JMdict download is not a complete gzip ({e})") from e
    except SystemExit as e:  # decompress refuses a file far too large
        raise RefreshFailed(f"JMdict download refused: {e}") from e
    if not jmdict.CREATED.search(text):
        raise RefreshFailed("JMdict download has no 'JMdict created' header date")


def _fetch_jmdict(fetcher: Fetcher, url: str, edition: dict, folder: Path) -> Path | None:
    """The new JMdict source in [folder], or None when it did not change."""
    if folder.exists():
        shutil.rmtree(folder)
    folder.mkdir(parents=True)
    dest = folder / "JMdict_e.gz"
    part = folder / "JMdict_e.gz.part"
    try:
        try:
            got = fetcher.get(url, part, if_modified_since=edition.get("source_last_modified") or None)
        except FetchError as e:
            raise RefreshFailed(f"JMdict download failed: {e}") from e
        if got is None:
            return None
        if not part.is_file():
            raise RefreshFailed("JMdict download wrote no file")
        if _sha256(part) == edition.get("source_sha256"):
            return None
        _check_jmdict_download(part, got)
        os.replace(part, dest)
        (folder / "JMdict_e.gz.last-modified").write_text(got.last_modified, encoding="utf-8")
        return dest
    finally:
        part.unlink(missing_ok=True)


def _krdict_changed(source: Path, edition: dict) -> bool:
    if not source.exists():
        raise RefreshFailed(f"--krdict-source not found: {source}")
    sources = edition.get("sources") or [{}]
    return build_ko_glossary._sha256(source) != sources[0].get("source_sha256")  # noqa: SLF001


# ------------------------------------------------------------------ build and adopt


def _read_editions(folder: Path) -> dict[str, dict]:
    return {name: json.loads((folder / edition).read_text(encoding="utf-8"))
            for name, (_, edition) in asset_check.ASSETS.items()}


def _build_candidate(assets: Path, candidate: Path, *, jmdict_source: Path | None,
                     krdict_source: Path | None, url: str, built_on: str) -> None:
    if candidate.exists():
        shutil.rmtree(candidate)
    candidate.mkdir(parents=True)
    for gz_name, edition_name in asset_check.ASSETS.values():
        for name in (gz_name, edition_name):
            shutil.copy2(assets / name, candidate / name)
    try:
        if jmdict_source is not None:
            build_app_asset.build_asset(jmdict_source, candidate, built_on=built_on, url=url)
        if krdict_source is not None:
            build_ko_glossary.build_asset(krdict_source, candidate, built_on=built_on)
    except SystemExit as e:  # the builders exit on a source they refuse
        raise RefreshFailed(f"build failed: {e}") from e
    except (zipfile.BadZipFile, sqlite3.Error, ValueError, EOFError, zlib.error) as e:  # a damaged source
        raise RefreshFailed(f"build failed: {type(e).__name__}: {e}") from e
    problems = asset_check.check_dir(candidate)
    if problems:
        raise RefreshFailed("new assets fail the check: " + "; ".join(problems))


def _adopt(candidate: Path, assets: Path, names: list[str]) -> None:
    """Replace [names] in [assets]. Every new file is copied next to its target first; then,
    per asset, the old edition goes, the gzip and the new edition last (as the builders do: a
    run cut short leaves no edition file, and the app then runs without that dictionary, never
    a mismatch). A failure says which assets were already replaced; no copy is left behind."""
    staged: list[Path] = []
    replaced: list[str] = []
    try:
        for name in names:
            for file in asset_check.ASSETS[name]:
                part = assets / f"{file}.part"
                staged.append(part)
                shutil.copy2(candidate / file, part)
        for name in names:
            gz_name, edition_name = asset_check.ASSETS[name]
            (assets / edition_name).unlink(missing_ok=True)
            os.replace(assets / f"{gz_name}.part", assets / gz_name)
            os.replace(assets / f"{edition_name}.part", assets / edition_name)
            replaced.append(name)
    except OSError as e:
        raise RefreshFailed(f"adopting failed ({e}); already replaced: {', '.join(replaced) or 'none'}") from e
    finally:
        for part in staged:
            part.unlink(missing_ok=True)
    problems = asset_check.check_dir(assets, names=tuple(names))
    if problems:
        raise RefreshFailed(f"adopted assets ({', '.join(names)}) fail the check: " + "; ".join(problems))


# ------------------------------------------------------------------ refresh


def refresh(assets: Path, work: Path, *, fetcher: Fetcher, gate: Gate, built_on: str,
            krdict_source: Path | None = None, url: str | None = None,
            dry_run: bool = False) -> Outcome:
    """One refresh run (module docstring). Never raises for a failed step: the outcome says."""
    url = url or jmdict.DEFAULT_URL
    work.mkdir(parents=True, exist_ok=True)
    run = _Run(built_on=built_on)
    try:
        problems = asset_check.check_dir(assets)
        if problems:
            raise RefreshFailed("current assets fail the check: " + "; ".join(problems))
        run.old = _read_editions(assets)
        jm_source = _fetch_jmdict(fetcher, url, run.old[JMDICT], work / "download")
        if krdict_source is None:
            run.notes.append(f"한국어기초사전은 수동: {KRDICT_PAGE} 의 '올린 날짜'가 "
                             f"{run.old[KRDICT]['sources'][0]['edition']}보다 새로우면 브라우저로 JSON zip을 받아 "
                             "--krdict-source 로 다시 돌립니다")
            ko_source = None
        else:
            ko_source = krdict_source if _krdict_changed(krdict_source, run.old[KRDICT]) else None
        run.changed = [name for name, src in ((JMDICT, jm_source), (KRDICT, ko_source)) if src is not None]
        if not run.changed:
            return _finish(work, run, "unchanged", ())
        candidate = work / "candidate"
        _build_candidate(assets, candidate, jmdict_source=jm_source, krdict_source=ko_source,
                         url=url, built_on=built_on)
        run.new = _read_editions(candidate)
        try:
            run.gate = gate(assets, candidate, work)
        except (OSError, subprocess.SubprocessError, ValueError) as e:
            raise RefreshFailed(f"accuracy gate did not run: {e}") from e
        if not run.gate.passed:
            return _finish(work, run, "rejected", run.gate.reasons or ("accuracy gate failed",))
        if dry_run:
            return _finish(work, run, "candidate", (f"candidate in {candidate}",))
        _adopt(candidate, assets, run.changed)
        return _finish(work, run, "adopted", tuple(f"{name} replaced" for name in run.changed))
    except (RefreshFailed, OSError, json.JSONDecodeError, KeyError) as e:
        return _finish(work, run, "failed", (str(e) or type(e).__name__,))


# ------------------------------------------------------------------ report


EDITION_KEYS = {
    JMDICT: ("jmdict_created", "source_last_modified", "built_on", "gzip_bytes", "sqlite_bytes"),
    KRDICT: ("built_on", "gzip_bytes", "sqlite_bytes"),
}


def _edition_row(name: str, edition: dict) -> dict:
    row = {k: edition.get(k) for k in EDITION_KEYS[name]}
    if name == KRDICT and edition.get("sources"):
        row["edition"] = edition["sources"][0].get("edition")
    return row


def _finish(work: Path, run: _Run, status: str, reasons: tuple[str, ...]) -> Outcome:
    data = {
        "status": status,
        "status_text": STATUS_TEXT[status],
        "built_on": run.built_on,
        "reasons": list(reasons),
        "notes": run.notes,
        "changed": run.changed,
        "old": {n: _edition_row(n, e) for n, e in run.old.items()},
        "new": {n: _edition_row(n, e) for n, e in run.new.items()},
        "gate": asdict(run.gate) if run.gate else None,
    }
    (work / "report.json").write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    report = work / "report.md"
    report.write_text(_markdown(data), encoding="utf-8")
    return Outcome(status=status, reasons=reasons, changed=tuple(run.changed), report=report)


def _markdown(data: dict) -> str:
    lines = [f"# 사전 갱신 ({data['built_on']}): {data['status_text']}", ""]
    lines += [f"- {r}" for r in data["reasons"]] + [f"- {n}" for n in data["notes"]]
    if data["old"]:
        lines += ["", "| 사전 | 항목 | 지금 | 새 판 |", "|---|---|---|---|"]
        for name, old in data["old"].items():
            new = data["new"].get(name, {})
            for key, value in old.items():
                lines.append(f"| {name} | {key} | {value} | {new.get(key, '')} |")
    gate = data["gate"]
    if gate:
        lines += ["", f"## 정확도 관문: {'통과' if gate['passed'] else '미달'}", ""]
        lines += [f"- {r}" for r in gate["reasons"]]
        rows = gate["rows"]
        if rows:
            keys = list(rows[0])
            lines += ["", "| " + " | ".join(keys) + " |", "|" + "---|" * len(keys)]
            lines += ["| " + " | ".join(str(r.get(k, "")) for k in keys) + " |" for r in rows]
    return "\n".join(lines) + "\n"


# ------------------------------------------------------------------ accuracy gate

TOTAL = re.compile(r"^TOTAL (.*)$", re.M)
HIGHER_IS_BETTER = ("found", "reading", "meaning", "sentence_recall", "sentence_precision", "high")
LOWER_IS_BETTER = ("extras", "duplicates", "high_wrong", "extra_high")


def parse_totals(output: str) -> dict[str, float]:
    """The first `TOTAL key=value …` line of eval_extract_dict.dart (`a/b` gives a)."""
    m = TOTAL.search(output)
    if not m:
        raise ValueError("no TOTAL line in the score table output")
    totals = {}
    for pair in m.group(1).split():
        key, _, value = pair.partition("=")
        totals[key] = float(value.split("/")[0])
    return totals


def regressions(old: dict[str, float], new: dict[str, float]) -> list[str]:
    """Where [new] is worse than [old], one line each (time per page is not compared)."""
    worse = []
    for key in HIGHER_IS_BETTER:
        if key in old and new.get(key, 0) < old[key]:
            worse.append(f"{key} {old[key]:g} → {new.get(key, 0):g}")
    for key in LOWER_IS_BETTER:
        if key in old and new.get(key, 0) > old[key]:
            worse.append(f"{key} {old[key]:g} → {new.get(key, 0):g}")
    return worse


BLOCK = REPO / "packages" / "jmdict_block"
SYNTHETIC_SETS = (
    ("synthetic_general", "../core/test/fixtures/synthetic_general", None),
    ("synthetic", "../core/test/fixtures/synthetic", None),
    ("synthetic_mlkit", "../core/test/fixtures/synthetic_mlkit", None),
)
# Recorded pages, local only ($SHIORI_PRIVATE_DIR/textbook; the same sets as the local
# tests of packages/jmdict_block). Only the numbers reach the report.
LOCAL_SETS = (
    ("local: word-list pages, Vision", "vocab_n5n3", "vocab_n5n3/general/ground_truth.json"),
    ("local: word-list pages, ML Kit", "ocr-android/fixtures_segment", "vocab_n5n3/general/ground_truth.json"),
    ("local: curled phone page", "device-iphone13mini/fixtures", "device-iphone13mini/general/ground_truth.json"),
    ("local: other textbook", "other-books/fixtures", "other-books/ground_truth.json"),
    ("local: example pages, photo", "scan-pairs/fx_raw_vb", "scan-pairs/gt_vb.json"),
    ("local: example pages, scanner app", "scan-pairs/fx_vflat_vb", "scan-pairs/gt_vb.json"),
)
SHOWN = ("found", "reading", "meaning", "extras", "high", "high_wrong", "extra_high")


def _private_dir() -> Path:
    return Path(os.environ.get("SHIORI_PRIVATE_DIR") or REPO / ".private")


def _gate_sets() -> list[tuple[str, str, str | None]]:
    sets = list(SYNTHETIC_SETS)
    textbook = _private_dir() / "textbook"
    for label, fixtures, truth in LOCAL_SETS:
        if (textbook / fixtures).is_dir() and (textbook / truth).is_file():
            sets.append((label, str(textbook / fixtures), str(textbook / truth)))
    return sets


def _unpack_pair(folder: Path, out: Path) -> tuple[Path, Path]:
    out.mkdir(parents=True, exist_ok=True)
    paths = []
    for name, (gz_name, _) in asset_check.ASSETS.items():
        path = out / f"{name}.sqlite"
        path.write_bytes(gzip.decompress((folder / gz_name).read_bytes()))
        paths.append(path)
    return paths[0], paths[1]


def _score(db: Path, glossary: Path, fixtures: str, truth: str | None) -> dict[str, float]:
    cmd = ["dart", "run", "tool/eval_extract_dict.dart", "--db", str(db), "--glossary", str(glossary),
           "--fixtures", fixtures]
    if truth:
        cmd += ["--gt", truth]
    done = subprocess.run(cmd, cwd=BLOCK, capture_output=True, text=True, timeout=600, check=False)
    if done.returncode != 0:
        raise ValueError(f"score table failed ({fixtures}): {done.stderr.strip()[-300:]}")
    return parse_totals(done.stdout)


def extract_gate(old: Path, new: Path, work: Path) -> GateResult:
    """The real gate: score tables on the same code with both asset folders, then the
    local floor tests with the new assets (packages/jmdict_block, `dart test`)."""
    gate_dir = work / "gate"
    old_db, old_ko = _unpack_pair(old, gate_dir / "old")
    new_db, new_ko = _unpack_pair(new, gate_dir / "new")
    subprocess.run(["dart", "pub", "get", "--offline"], cwd=BLOCK, capture_output=True, check=False, timeout=600)
    rows, reasons = [], []
    for label, fixtures, truth in _gate_sets():
        before = _score(old_db, old_ko, fixtures, truth)
        after = _score(new_db, new_ko, fixtures, truth)
        worse = regressions(before, after)
        reasons += [f"{label}: {w}" for w in worse]
        rows.append({"set": label, **{k: f"{before.get(k, 0):g} → {after.get(k, 0):g}" for k in SHOWN},
                     "verdict": "worse" if worse else "ok"})
    env = {**os.environ, "SHIORI_JMDICT_DB": str(new_db), "SHIORI_KO_GLOSSARY_DB": str(new_ko),
           "SHIORI_PRIVATE_DIR": str(_private_dir())}
    floors = sorted(str(p.relative_to(BLOCK)) for p in (BLOCK / "test").glob("*_local_test.dart"))
    if floors:
        done = subprocess.run(["dart", "test", *floors], cwd=BLOCK, env=env, capture_output=True, text=True,
                              timeout=1200, check=False)
        last = (done.stdout.strip().splitlines() or [""])[-1]
        rows.append({"set": "local floor tests (new assets)", **{k: "" for k in SHOWN},
                     "verdict": f"{'ok' if done.returncode == 0 else 'worse'} ({last[-60:]})"})
        if done.returncode != 0:
            reasons.append(f"local floor tests failed: {last[-200:]}")
    return GateResult(passed=not reasons, reasons=tuple(reasons), rows=tuple(rows))


# ------------------------------------------------------------------ command line


def main(argv: list[str], *, fetcher: Fetcher | None = None, gate: Gate | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--assets", type=Path, default=DEFAULT_ASSETS, help="default: app/assets/dict")
    ap.add_argument("--work", type=Path, default=DEFAULT_WORK, help="default: tools/dict/.cache/refresh")
    ap.add_argument("--krdict-source", type=Path,
                    help="the Basic Korean Dictionary JSON zip, downloaded by hand in a browser")
    ap.add_argument("--url", default=jmdict.DEFAULT_URL, help="JMdict download URL")
    ap.add_argument("--built-on", default=dt.datetime.now(dt.timezone.utc).date().isoformat(),
                    help="build day for new editions (default: today, UTC)")
    ap.add_argument("--dry-run", action="store_true", help="build and gate, adopt nothing")
    a = ap.parse_args(argv)
    out = refresh(a.assets, a.work, fetcher=fetcher or UrlFetcher(), gate=gate or extract_gate,
                  built_on=a.built_on, krdict_source=a.krdict_source, url=a.url, dry_run=a.dry_run)
    print(f"{STATUS_TEXT[out.status]} ({out.status})")
    for line in out.reasons:
        print(f"- {line}")
    data = json.loads((a.work / "report.json").read_text(encoding="utf-8"))
    for line in data["notes"]:
        print(f"- {line}")
    if out.report:
        print(f"report: {out.report}")
    return EXIT_CODES[out.status]


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
