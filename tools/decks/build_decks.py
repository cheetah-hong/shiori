#!/usr/bin/env python3
"""Build the built-in deck asset the app ships: JLPT N5-N1 대비 word lists, each word with its
reading and its JMdict entry, for learners without a textbook.

  python3 tools/decks/build_decks.py --built-on YYYY-MM-DD [--source <original_data>] [--source-commit <sha>]
      [--jmdict <JMdict_e.gz>] [--supplement <supplement.tsv>] [--lookup-overrides <tsv>]
      [--expect-sha256 n5=HEX ...]
      [--expect-jmdict-sha256 HEX] [--out-dir app/assets/decks]
  python3 tools/decks/build_decks.py --check [--out-dir app/assets/decks]

Sources (not in the repository, nothing is downloaded here; docs/dictionary.md 15 has the
commands). By default they are read from the private folder ($SHIORI_PRIVATE_DIR, default
<repo>/.private): decks/yomitan-jlpt-vocab/original_data (a clone of the list repository, its
commit read from git), decks/supplement.tsv, and JMdict_e.gz from tools/dict's download cache.
- The word lists: Jonathan Waller's JLPT Resources (tanos.co.uk, CC BY) as linked to JMdict
  entries by Stephen Kraus, github.com/stephenmk/yomitan-jlpt-vocab, original_data/n5.csv ...
  n1.csv (columns jmdict_seq,kana,kanji,waller_definition; CC BY-SA 4.0). The commit and the
  sha256 of every list go into the edition file; --expect-sha256 stops a build on another file.
- JMdict_e.gz (EDRDG, CC BY-SA 4.0), the same file the app's dictionary asset is built from:
  kanji forms with their priority tags, readings, "usually written in kana" senses.
- decks/supplement.tsv (private folder): Korean meanings written for this project for words the
  app's dictionaries give none (columns level, entry, headword, meaning, reviewed; others are
  left alone). A row nobody has reviewed, a row twice or a row without its word stops the
  build. The app uses one only when its dictionaries have no meaning for the word.
- decks/lookup-overrides.tsv (private folder, optional): the lookup spelling of a few words
  whose meaning the rule below asks under a spelling the glossary gives a wrong first sense for
  (columns level, entry, headword, lookup, reviewed; same checks as the supplement).

Rules (docs/dictionary.md 15):
- A row without a JMdict entry, or whose entry the JMdict file lacks, is left out.
- Shown spelling: the list's kana stays; the list's kanji stays when it is a common form of
  the entry; a rare kanji form becomes the reading when the entry is usually written in kana,
  else the entry's common form with the same kanji (okurigana only: 戸締り → 戸締まり), else
  it stays. The reading is the entry's reading the list gives.
- Lookup spelling ("l"): the entry's first common kanji form read so that holds every kanji
  of the shown one (たいへん → 大変, 話合い → 話し合い; 軍 is not asked as 戦), when it
  differs: the app asks the Korean glossary for it first. A row of the lookup overrides
  sets it instead (色々 asked as いろいろ, like the N5 word of its entry).
- One word per headword (the app's word key) and per JMdict entry (川 and 河, こちら and
  こっち are one word), each in its easiest level: N5 first, then the list's order. One
  exception: an entry an easier level shows only in kana comes back once in a harder level
  in kanji (いちばん in N5, 一番 in N1), read as that row reads it. Its spelling is another
  word key, so the app keeps it as another word.
- Order inside a level: the entry's JMdict frequency band (nf, lowest first), then common
  entries, then the list's order.
Writes jlpt.json (one word per line) and jlpt.edition.json into --out-dir (git-ignored, like the
dictionary assets). The same inputs give byte-identical files. --check compares the asset with its
edition file and, when the private inputs are the ones the edition names, rebuilds it and compares
the bytes (else says why it skips that). Only the Python 3 standard library is used.
"""
from __future__ import annotations

import argparse
import contextlib
import csv
import gzip
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import unicodedata
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUT = ROOT / "app" / "assets" / "decks"
DEFAULT_JMDICT = ROOT / "tools" / "dict" / ".cache" / "refresh" / "download" / "JMdict_e.gz"


def private_dir() -> Path:
    """$SHIORI_PRIVATE_DIR, else <repo>/.private."""
    return Path(os.environ.get("SHIORI_PRIVATE_DIR") or ROOT / ".private")


def default_source() -> Path:
    return private_dir() / "decks" / "yomitan-jlpt-vocab" / "original_data"


def default_supplement() -> Path:
    return private_dir() / "decks" / "supplement.tsv"


def default_lookup_overrides() -> Path:
    return private_dir() / "decks" / "lookup-overrides.tsv"


DECKS_NAME = "jlpt.json"
EDITION_NAME = "jlpt.edition.json"
FORMAT = "shiori-decks"
VERSION = 1
LEVELS = ("N5", "N4", "N3", "N2", "N1")
COMMON = frozenset({"news1", "ichi1", "spec1", "spec2", "gai1"})
NO_NF = 99
UK = "word usually written using kana alone"
SOURCE_URL = "https://github.com/stephenmk/yomitan-jlpt-vocab"
SOURCES = (
    {"name": "JLPT Resources", "author": "Jonathan Waller", "license": "CC BY",
     "licenseUrl": "https://www.tanos.co.uk/jlpt/sharing/", "url": "https://www.tanos.co.uk/jlpt/"},
    {"name": "yomitan-jlpt-vocab", "author": "Stephen Kraus", "license": "CC BY-SA 4.0",
     "licenseUrl": "https://creativecommons.org/licenses/by-sa/4.0/", "url": SOURCE_URL},
)
ATTRIBUTION = ("단어 목록: Jonathan Waller, JLPT Resources(tanos.co.uk), CC BY · Stephen Kraus, "
               "yomitan-jlpt-vocab, CC BY-SA 4.0을 가공함. 일본어능력시험 주최 측의 목록이 아닙니다.")
BUILD_COMMAND = "python3 tools/decks/build_decks.py --built-on <day> (inputs in $SHIORI_PRIVATE_DIR/decks)"
_HEX64 = re.compile(r"[0-9a-f]{64}")
_KANA = re.compile(r"^[ぁ-ヿ]+$")


class BuildError(Exception):
    """A build stops: wrong input file, a supplement row without its word, an empty level."""


def is_kanji(c: str) -> bool:
    o = ord(c)
    return 0x4E00 <= o <= 0x9FFF or 0x3400 <= o <= 0x4DBF or 0xF900 <= o <= 0xFAFF or o in (0x3005, 0x3006)


def word_key(headword: str) -> str:
    """The app's word key (core wordKey): NFKC without spaces, a な-adjective's だ left off."""
    h = re.sub(r"\s+", "", unicodedata.normalize("NFKC", headword))
    if len(h) > 1 and h.endswith("だ") and any(is_kanji(c) for c in h):
        return h[:-1]
    return h


def hira(s: str) -> str:
    return "".join(chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c for c in s)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


# ---------------------------------------------------------------- JMdict


@dataclass(frozen=True)
class Form:
    text: str
    pri: frozenset[str]
    restr: tuple[str, ...] = ()
    nokanji: bool = False

    @property
    def common(self) -> bool:
        return bool(self.pri & COMMON)

    @property
    def nf(self) -> int:
        bands = [int(p[2:]) for p in self.pri if p.startswith("nf") and p[2:].isdigit()]
        return min(bands, default=NO_NF)


@dataclass(frozen=True)
class Entry:
    seq: int
    kanji: tuple[Form, ...]
    readings: tuple[Form, ...]
    usually_kana: bool

    def readings_of(self, kanji: str) -> list[str]:
        return [r.text for r in self.readings if not r.nokanji and (not r.restr or kanji in r.restr)]

    @property
    def nf(self) -> int:
        return min([f.nf for f in self.kanji + self.readings], default=NO_NF)

    @property
    def common(self) -> bool:
        return any(f.common for f in self.kanji + self.readings)


def read_jmdict(path: Path) -> tuple[dict[int, Entry], str]:
    """Entries by ent_seq and the file's "JMdict created" day."""
    with gzip.open(path, "rb") as f:
        head = f.read(1 << 16).decode("utf-8", "replace")
    created = re.search(r"JMdict created: (\d{4}-\d{2}-\d{2})", head)
    entries: dict[int, Entry] = {}
    with gzip.open(path, "rb") as f:
        for _, el in ET.iterparse(f, events=("end",)):
            if el.tag != "entry":
                continue
            seq = int(el.findtext("ent_seq"))
            kanji = tuple(Form(k.findtext("keb"), frozenset(p.text for p in k.findall("ke_pri")))
                          for k in el.findall("k_ele"))
            readings = tuple(Form(r.findtext("reb"), frozenset(p.text for p in r.findall("re_pri")),
                                  tuple(x.text for x in r.findall("re_restr")), r.find("re_nokanji") is not None)
                             for r in el.findall("r_ele"))
            senses = el.findall("sense")
            uk = [any((m.text or "") == UK for m in s.findall("misc")) for s in senses]
            # Usually kana: the first sense says so, or at least half of them do.
            usually = bool(uk) and (uk[0] or 2 * sum(uk) >= len(uk))
            entries[seq] = Entry(seq, kanji, readings, usually)
            el.clear()
    return entries, created.group(1) if created else ""


# ---------------------------------------------------------------- words


@dataclass
class Word:
    level: str
    index: int
    headword: str
    reading: str
    entry: Entry
    lookup: str | None = None
    meaning: str | None = None

    def as_json(self) -> dict:
        out: dict = {"h": self.headword, "r": self.reading, "e": self.entry.seq}
        if self.lookup:
            out["l"] = self.lookup
        if self.meaning:
            out["m"] = self.meaning
        return out


@dataclass
class LeftOut:
    no_entry: int = 0
    not_in_jmdict: int = 0
    duplicate: int = 0
    kanji_again: int = 0


def _kanji_set(text: str) -> frozenset[str]:
    return frozenset(c for c in text if is_kanji(c)) - {"御"}


def shown_and_lookup(printed: str, kana: str, entry: Entry) -> tuple[str, str, str | None]:
    """(shown headword, reading, lookup spelling or None) by the rules in the module text."""
    want = hira(kana)
    reading = next((r.text for r in entry.readings if hira(r.text) == want), kana)
    common_read = [k for k in entry.kanji if k.common and any(hira(r) == want for r in entry.readings_of(k.text))]
    if _KANA.match(printed):
        shown = printed
    elif any(k.text == printed and k.common for k in entry.kanji):
        shown = printed
    elif entry.usually_kana:
        shown = reading
    else:
        same = [k.text for k in common_read if _kanji_set(k.text) == _kanji_set(printed)]
        shown = same[0] if same else printed
    # A word is asked under a common kanji form of its entry that has every kanji it shows
    # (たいへん → 大変, 話合い → 話し合い, とり肉 → 鶏肉), never under other kanji (軍 is not
    # asked as 戦: a glossary key of other kanji may be another word).
    lookup = next((k.text for k in common_read
                   if k.text != shown and _kanji_set(shown) <= _kanji_set(k.text)), None)
    return shown, reading, lookup


def read_lists(source: Path) -> dict[str, list[dict]]:
    out = {}
    for level in LEVELS:
        path = source / f"{level.lower()}.csv"
        with path.open(encoding="utf-8", newline="") as f:
            out[level] = list(csv.DictReader(f))
    return out


SUPPLEMENT_COLUMNS = ("level", "entry", "headword", "meaning", "reviewed")
OVERRIDE_COLUMNS = ("level", "entry", "headword", "lookup", "reviewed")


def read_word_table(path: Path, name: str, columns: tuple[str, ...]) -> list[dict]:
    """A private table of rows about deck words: every column given, each row reviewed, each
    word (level, entry, headword) once. No file, no rows."""
    if not path.exists():
        return []
    with path.open(encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f, delimiter="\t")
        rows = list(reader)
        missing = [c for c in columns if c not in (reader.fieldnames or [])]
    if missing:
        raise BuildError(f"{name} needs the columns {', '.join(missing)}")
    seen = set()
    for r in rows:
        if not all((r.get(k) or "").strip() for k in columns):
            raise BuildError(f"{name} row needs {', '.join(columns)}: {r}")
        if not r["entry"].strip().isdigit():
            raise BuildError(f"{name} entry {r['entry']!r} is not a number")
        word = (r["level"].strip(), int(r["entry"]), r["headword"].strip())
        if word in seen:
            raise BuildError(f"{name} has a word twice: {' '.join(map(str, word))}")
        seen.add(word)
    return rows


def read_supplement(path: Path) -> list[dict]:
    """The supplement's rows, each reviewed, each word once."""
    return read_word_table(path, "supplement", SUPPLEMENT_COLUMNS)


def read_lookup_overrides(path: Path) -> list[dict]:
    """The lookup overrides' rows, each reviewed, each word once."""
    return read_word_table(path, "lookup overrides", OVERRIDE_COLUMNS)


def _row_word(decks: dict[str, list[Word]], r: dict, name: str) -> Word:
    """The deck word a table row is about; a row without one stops the build."""
    match = [w for w in decks.get(r["level"].strip(), [])
             if w.entry.seq == int(r["entry"]) and w.headword == r["headword"].strip()]
    if not match:
        raise BuildError(f"{name} row without its word: {r['level']} {r['entry']} {r['headword']}")
    return match[0]


def _kanji_again(shown: str, seq: int, level: str, first_level: dict[int, str], in_kanji: set[int]) -> bool:
    """Whether [shown] is an entry an easier level showed only in kana, back in kanji."""
    return not _KANA.match(shown) and seq not in in_kanji and first_level[seq] != level


def build_words(lists: dict[str, list[dict]], entries: dict[int, Entry], supplement: list[dict],
                overrides: list[dict] | None = None) -> tuple[dict[str, list[Word]], LeftOut]:
    left = LeftOut()
    seen: set[str] = set()
    # The level each entry first came in, and the entries shown in kanji so far.
    first_level: dict[int, str] = {}
    in_kanji: set[int] = set()
    decks: dict[str, list[Word]] = {}
    for level in LEVELS:
        words = []
        for i, row in enumerate(lists[level]):
            seq = (row.get("jmdict_seq") or "").strip()
            if not seq:
                left.no_entry += 1
                continue
            if not seq.isdigit():
                raise BuildError(f"{level} row {i + 2}: jmdict_seq {seq!r} is not a number")
            entry = entries.get(int(seq))
            if entry is None:
                left.not_in_jmdict += 1
                continue
            printed = (row.get("kanji") or "").strip() or row["kana"].strip()
            shown, reading, lookup = shown_and_lookup(printed, row["kana"].strip(), entry)
            key = word_key(shown)
            again = entry.seq in first_level
            if key in seen or (again and not _kanji_again(shown, entry.seq, level, first_level, in_kanji)):
                left.duplicate += 1
                continue
            seen.add(key)
            first_level.setdefault(entry.seq, level)
            if not _KANA.match(shown):
                in_kanji.add(entry.seq)
            if again:
                left.kanji_again += 1
            words.append(Word(level, i, shown, reading, entry, lookup))
        if not words:
            raise BuildError(f"{level} has no words")
        words.sort(key=lambda w: (w.entry.nf, not w.entry.common, w.index))
        decks[level] = words
    for r in supplement:
        _row_word(decks, r, "supplement").meaning = r["meaning"].strip()
    for r in overrides or []:
        word = _row_word(decks, r, "lookup overrides")
        lookup = r["lookup"].strip()
        if lookup == word.headword:
            raise BuildError(f"lookup overrides row asks {word.headword} as itself")
        word.lookup = lookup
    return decks, left


# ---------------------------------------------------------------- files


def render(decks: dict[str, list[Word]], built_on: str) -> bytes:
    """The deck file: a JSON document with one word per line."""
    dump = lambda o: json.dumps(o, ensure_ascii=False, separators=(",", ":"))  # noqa: E731
    lines = ["{" + f'"format":{dump(FORMAT)},"version":{VERSION},"edition":{dump(built_on)},'
             + f'"sources":{dump(list(SOURCES))},"decks":[']
    for d, level in enumerate(LEVELS):
        head = {"id": f"jlpt-{level.lower()}", "name": f"JLPT {level} 대비", "level": level}
        lines.append(dump(head)[:-1] + ',"words":[')
        words = decks[level]
        lines += [dump(w.as_json()) + ("," if i < len(words) - 1 else "") for i, w in enumerate(words)]
        lines.append("]}" + ("," if d < len(LEVELS) - 1 else ""))
    lines.append("]}")
    return ("\n".join(lines) + "\n").encode("utf-8")


def edition(raw: bytes, decks: dict[str, list[Word]], left: LeftOut, *, built_on: str, commit: str,
            files: dict[str, str], jmdict_created: str, jmdict_sha: str, supplement_sha: str,
            supplement_rows: int, overrides_sha: str, overrides_rows: int) -> bytes:
    doc = {
        "attribution": ATTRIBUTION,
        "built_on": built_on,
        "counts": {level: len(decks[level]) for level in LEVELS},
        "format": FORMAT,
        "jmdict": {"created": jmdict_created, "source_sha256": jmdict_sha},
        "json_bytes": len(raw),
        "json_sha256": hashlib.sha256(raw).hexdigest(),
        "kanji_again": left.kanji_again,
        "left_out": {"no_entry": left.no_entry, "not_in_jmdict": left.not_in_jmdict, "duplicate": left.duplicate},
        "license": "CC BY-SA 4.0",
        "lookup_overrides_rows": overrides_rows,
        "lookup_overrides_sha256": overrides_sha,
        "source": {"commit": commit, "files": files, "url": SOURCE_URL},
        "supplement_rows": supplement_rows,
        "supplement_sha256": supplement_sha,
        "version": VERSION,
    }
    return (json.dumps(doc, ensure_ascii=False, indent=1, sort_keys=True) + "\n").encode("utf-8")


def check(out_dir: Path) -> list[str]:
    """What is wrong with the deck asset in [out_dir] against its edition file."""
    decks_path, edition_path = out_dir / DECKS_NAME, out_dir / EDITION_NAME
    missing = [p.name for p in (decks_path, edition_path) if not p.exists()]
    if missing:
        return [f"decks: {', '.join(missing)} missing in {out_dir} (build: {BUILD_COMMAND})"]
    raw = decks_path.read_bytes()
    try:
        ed = json.loads(edition_path.read_text(encoding="utf-8"))
        doc = json.loads(raw)
    except (ValueError, UnicodeDecodeError) as e:
        return [f"decks: unreadable file ({e}) (build: {BUILD_COMMAND})"]
    problems = []
    if ed.get("json_sha256") != hashlib.sha256(raw).hexdigest() or ed.get("json_bytes") != len(raw):
        problems.append(f"decks: {DECKS_NAME} sha256/size differ from {EDITION_NAME} (build: {BUILD_COMMAND})")
    if doc.get("format") != FORMAT or doc.get("version") != VERSION:
        problems.append(f"decks: not a {FORMAT} v{VERSION} file")
    counts = {d.get("level"): len(d.get("words", [])) for d in doc.get("decks", [])}
    for level in LEVELS:
        if counts.get(level) != (ed.get("counts") or {}).get(level):
            problems.append(f"decks: {level} has {counts.get(level)} words, the edition says "
                            f"{(ed.get('counts') or {}).get(level)}")
    return problems


def _git_commit(source: Path) -> str | None:
    """The commit of the git clone [source] is in, if it is one (not this repository, which git
    would find above a plain folder of lists)."""
    def git(*args: str) -> str | None:
        try:
            out = subprocess.run(["git", "-C", str(source), *args], capture_output=True, text=True, check=True)
        except (OSError, subprocess.CalledProcessError):
            return None
        return out.stdout.strip() or None
    top = git("rev-parse", "--show-toplevel")
    if top is None or Path(top).resolve() == ROOT.resolve():
        return None
    return git("rev-parse", "HEAD")


def rebuild_problems(a: argparse.Namespace) -> list[str]:
    """With the private inputs the edition names at hand, a rebuild must give the same bytes; else
    (a checkout without them, other inputs) the byte check is skipped with a line saying why."""
    ed = json.loads((a.out_dir / EDITION_NAME).read_text(encoding="utf-8"))
    inputs = [a.source / f"{lv.lower()}.csv" for lv in LEVELS] + [a.jmdict]
    missing = [str(p) for p in inputs if not p.exists()]
    if missing:
        print(f"decks: byte check skipped: private inputs not found ({missing[0]} ...)")
        return []
    files = {lv.lower(): sha256(a.source / f"{lv.lower()}.csv") for lv in LEVELS}
    supplement = sha256(a.supplement) if a.supplement.exists() else ""
    overrides = sha256(a.lookup_overrides) if a.lookup_overrides.exists() else ""
    if (files != ed.get("source", {}).get("files") or sha256(a.jmdict) != ed.get("jmdict", {}).get("source_sha256")
            or supplement != ed.get("supplement_sha256")
            or overrides != ed.get("lookup_overrides_sha256", "")):
        print("decks: byte check skipped: the private inputs are not the ones the edition names")
        return []
    with tempfile.TemporaryDirectory() as tmp:
        again = argparse.Namespace(source=a.source, source_commit=ed["source"]["commit"], jmdict=a.jmdict,
                                   supplement=a.supplement, lookup_overrides=a.lookup_overrides,
                                   built_on=ed["built_on"], out_dir=Path(tmp),
                                   expect_sha256=[], expect_jmdict_sha256=None)
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                build(again)
        except (BuildError, OSError, ET.ParseError) as e:
            return [f"decks: a rebuild of its inputs fails: {e}"]
        return [f"decks: {name} differs from a rebuild of its inputs (build: {BUILD_COMMAND})"
                for name in (DECKS_NAME, EDITION_NAME)
                if (Path(tmp) / name).read_bytes() != (a.out_dir / name).read_bytes()]


def _expected(pairs: list[str]) -> dict[str, str]:
    out = {}
    for p in pairs:
        name, _, value = p.partition("=")
        value = value.strip().lower()
        if name not in [lv.lower() for lv in LEVELS] or not _HEX64.fullmatch(value):
            raise BuildError(f"--expect-sha256 needs n5..n1=<sha256>, got {p}")
        out[name] = value
    return out


def build(a: argparse.Namespace) -> None:
    files = {lv.lower(): sha256(a.source / f"{lv.lower()}.csv") for lv in LEVELS}
    for name, want in _expected(a.expect_sha256).items():
        if files[name] != want:
            raise BuildError(f"{name}.csv has sha256 {files[name]}, expected {want}")
    jmdict_sha = sha256(a.jmdict)
    want_jmdict = (a.expect_jmdict_sha256 or "").strip().lower()
    if want_jmdict and not _HEX64.fullmatch(want_jmdict):
        raise BuildError(f"--expect-jmdict-sha256 needs a sha256, got {a.expect_jmdict_sha256}")
    if want_jmdict and jmdict_sha != want_jmdict:
        raise BuildError(f"JMdict has sha256 {jmdict_sha}, expected {a.expect_jmdict_sha256}")
    entries, created = read_jmdict(a.jmdict)
    supplement = read_supplement(a.supplement)
    overrides = read_lookup_overrides(a.lookup_overrides)
    decks, left = build_words(read_lists(a.source), entries, supplement, overrides)
    raw = render(decks, a.built_on)
    ed = edition(raw, decks, left, built_on=a.built_on, commit=a.source_commit, files=files,
                 jmdict_created=created, jmdict_sha=jmdict_sha,
                 supplement_sha=sha256(a.supplement) if a.supplement.exists() else "",
                 supplement_rows=len(supplement),
                 overrides_sha=sha256(a.lookup_overrides) if a.lookup_overrides.exists() else "",
                 overrides_rows=len(overrides))
    a.out_dir.mkdir(parents=True, exist_ok=True)
    (a.out_dir / DECKS_NAME).write_bytes(raw)
    (a.out_dir / EDITION_NAME).write_bytes(ed)
    counts = ", ".join(f"{lv} {len(decks[lv])}" for lv in LEVELS)
    print(f"decks: {counts}; left out {left}; {len(raw)} bytes -> {a.out_dir}")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--check", action="store_true", help="build nothing: check the asset against its edition file")
    ap.add_argument("--source", type=Path,
                    help="folder of n5.csv ... n1.csv (default: $SHIORI_PRIVATE_DIR/decks/yomitan-jlpt-vocab/original_data)")
    ap.add_argument("--source-commit", help="commit of the word lists (default: read from the source's git)")
    ap.add_argument("--expect-sha256", action="append", default=[], metavar="NAME=HEX",
                    help="stop unless that list has this sha256 (n5 ... n1)")
    ap.add_argument("--jmdict", type=Path, default=DEFAULT_JMDICT,
                    help="JMdict_e.gz (default: tools/dict/.cache/refresh/download/JMdict_e.gz)")
    ap.add_argument("--expect-jmdict-sha256", help="stop unless JMdict_e.gz has this sha256")
    ap.add_argument("--supplement", type=Path,
                    help="meanings written for words without one (default: $SHIORI_PRIVATE_DIR/decks/supplement.tsv)")
    ap.add_argument("--lookup-overrides", type=Path,
                    help="lookup spellings set by hand (default: $SHIORI_PRIVATE_DIR/decks/lookup-overrides.tsv)")
    ap.add_argument("--built-on", help="build day written to the files (YYYY-MM-DD)")
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT, help="default: app/assets/decks")
    a = ap.parse_args(argv)
    a.source = a.source or default_source()
    a.supplement = a.supplement or default_supplement()
    a.lookup_overrides = a.lookup_overrides or default_lookup_overrides()
    if a.check:
        problems = check(a.out_dir)
        if not problems:
            problems = rebuild_problems(a)
        for p in problems:
            print(p)
        if not problems:
            print(f"decks: ok ({a.out_dir / DECKS_NAME})")
        return 1 if problems else 0
    if not a.built_on:
        ap.error("a build needs --built-on")
    a.source_commit = a.source_commit or _git_commit(a.source)
    if not a.source_commit:
        ap.error(f"no commit for {a.source}: give --source-commit")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", a.built_on):
        ap.error("--built-on is YYYY-MM-DD")
    try:
        build(a)
    except (BuildError, OSError, ET.ParseError) as e:
        print(f"decks: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
