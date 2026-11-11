"""How many words without a printed example each source can fill.

Reads (all local, under ``$SHIORI_PRIVATE_DIR/examples`` and ``.../meaning``):
- ``raw/JMdict_e_examp.gz``: the word universe (entries) and the ``jmdict``
  source;
- ``raw/tatoeba/``: Tatoeba per-language exports and ``jpn_indices.tar.bz2``;
- the kaikki extracts (Korean, Japanese edition) and the Japanese entries of
  the English edition (``work/enwikt-ja-entries.jsonl.gz``, grepped from the
  raw dump);
- the extractor dump ``meaning/work/after.json`` (``entries``: every entry of
  the scored sets with its example, ``ex_ja`` null = none);
- the JLPT N5-N3 lists (``meaning/raw/jlpt-n?.csv``).

Prints numbers only. ``--samples DIR`` writes sentences to judge by eye,
``--assets DIR`` the size probes and ``--picks FILE`` the Tatoeba pick per
JLPT word (all local).
"""
from __future__ import annotations

import argparse
import bz2
import gzip
import json
import os
import random
import sqlite3
import tarfile
from collections import defaultdict
from pathlib import Path

from example_sources import (SOURCES, EntryIndex, Example, kanji_of, parse_indices_row,
                             is_kana_only, parse_jmdict, parse_sentence_row, pick,
                             reading_agrees, unknown_kanji, usable, wikt_examples)

PRIVATE = Path(os.environ.get("SHIORI_PRIVATE_DIR", Path(__file__).resolve().parents[3] / ".private"))
SAMPLE_SIZE = 30
SEED = 20261111
COMBOS = {
    "tatoeba>kowikt": ("tatoeba", "kowikt"),
    "kowikt>tatoeba": ("kowikt", "tatoeba"),
}


# --- loading ---------------------------------------------------------------

def _lines_bz2(path: Path):
    with bz2.open(path, "rt", encoding="utf-8") as f:
        yield from f


def load_jmdict(path: Path) -> tuple[EntryIndex, dict[str, list[Example]]]:
    entries, by_seq = [], defaultdict(list)
    with gzip.open(path, "rb") as f:
        for entry, exs in parse_jmdict(f):
            entries.append(entry)
            by_seq[entry.seq].extend(exs)
    return EntryIndex(entries), by_seq


def _links(path: Path) -> dict[str, list[str]]:
    out = defaultdict(list)
    for row in _lines_bz2(path):
        a, _, b = row.rstrip("\n").partition("\t")
        out[a].append(b)
    return out


def load_tatoeba(d: Path, idx: EntryIndex) -> tuple[dict[str, list[Example]], dict]:
    """Examples by entry seq, and the sentence tables (for the jmdict source)."""
    jpn, author = {}, {}
    for row in _lines_bz2(d / "jpn_sentences_detailed.tsv.bz2"):
        p = parse_sentence_row(row)
        if p:
            jpn[p[0]], author[p[0]] = p[2], p[3]
    kor = {p[0]: p[2] for p in map(parse_sentence_row, _lines_bz2(d / "kor_sentences_detailed.tsv.bz2")) if p}
    eng = {}
    for row in _lines_bz2(d / "eng_sentences.tsv.bz2"):
        c = row.rstrip("\n").split("\t")
        if len(c) == 3:
            eng[c[0]] = c[2]
    tags = defaultdict(set)
    for row in _lines_bz2(d / "jpn_tags.tsv.bz2"):
        c = row.rstrip("\n").split("\t")
        if len(c) == 2:
            tags[c[0]].add(c[1])
    jk, je, ek = (_links(d / f) for f in ("jpn-kor_links.tsv.bz2", "jpn-eng_links.tsv.bz2",
                                          "eng-kor_links.tsv.bz2"))

    def ko_of(sid: str) -> tuple[str | None, bool]:
        for k in jk.get(sid, ()):
            if k in kor:
                return kor[k], True
        for e in je.get(sid, ()):  # through an English translation
            for k in ek.get(e, ()):
                if k in kor:
                    return kor[k], False
        return None, False

    def en_of(sid: str) -> str | None:
        return next((eng[e] for e in je.get(sid, ()) if e in eng), None)

    stats = {"jpn": len(jpn), "kor_direct": 0, "kor_indirect": 0, "indexed": 0}
    tables = {"jpn": jpn, "author": author, "tags": tags, "ko_of": ko_of, "en_of": en_of}
    by_seq = defaultdict(list)
    with tarfile.open(d / "jpn_indices.tar.bz2", "r:bz2") as tar:
        member = tar.extractfile("jpn_indices.csv")
        for raw in member:
            p = parse_indices_row(raw.decode("utf-8"))
            if not p or p[0] not in jpn:
                continue
            sid, words = p
            stats["indexed"] += 1
            ko, direct = ko_of(sid)
            if ko:
                stats["kor_direct" if direct else "kor_indirect"] += 1
            en = en_of(sid)
            forms = tuple(w.headword for w in words)
            done: set[str] = set()  # one Example per sentence and entry
            for w in words:
                # ``が(#2028930)``: the reading slot names the entry itself.
                hits = (idx.by_seq(w.reading[1:]) if w.reading and w.reading.startswith("#")
                        else idx.lookup(w.headword, [w.reading] if w.reading else ()))
                for e in hits:
                    if e.seq in done:
                        continue
                    done.add(e.seq)
                    by_seq[e.seq].append(Example(
                        "tatoeba", w.headword, jpn[sid], ko=ko, ko_direct=direct, en=en, ref=sid,
                        author=author.get(sid), checked=w.checked, words=forms,
                        reading=_reading_of(w),
                        tags=frozenset(tags.get(sid, ()))))
    return by_seq, {"stats": stats, **tables}


def _reading_of(w) -> str | None:
    if w.reading and not w.reading.startswith("#"):
        return w.reading
    return w.surface if w.surface and is_kana_only(w.surface) else None


def jmdict_with_tatoeba(by_seq: dict[str, list[Example]], t: dict) -> dict[str, list[Example]]:
    """JMdict examples carry Tatoeba ids: add the Korean, author and tags."""
    out = {}
    for seq, exs in by_seq.items():
        out[seq] = [Example("jmdict", e.key, e.ja, ko=t["ko_of"](e.ref)[0],
                            ko_direct=t["ko_of"](e.ref)[1], en=e.en, ref=e.ref,
                            author=t["author"].get(e.ref), checked=True,
                            tags=frozenset(t["tags"].get(e.ref, ()))) for e in exs]
    return out


def load_wikt(source: str, path: Path, idx: EntryIndex) -> dict[str, list[Example]]:
    opener = gzip.open if path.suffix == ".gz" else open
    by_seq = defaultdict(list)
    with opener(path, "rt", encoding="utf-8") as f:
        for line in f:
            if '"lang_code": "ja"' not in line:
                continue
            exs = wikt_examples(source, json.loads(line))
            if not exs:
                continue
            for e in idx.lookup(exs[0].key):
                by_seq[e.seq].extend(exs)
    return by_seq


# --- word lists ------------------------------------------------------------

def jlpt_words(meaning_raw: Path) -> list[dict]:
    """Same reading of the lists as the meaning survey's dump."""
    out = []
    for level in ("n5", "n4", "n3"):
        rows = (meaning_raw / f"jlpt-{level}.csv").read_text(encoding="utf-8").splitlines()[1:]
        for row in rows:
            cells = row.split(",")
            if len(cells) < 2 or not cells[0]:
                continue
            alts = [a.replace("～", "").strip() for a in cells[0].split(";")]
            hs = [a for a in alts if a]
            rs = [r.replace("～", "").strip() for r in cells[1].split(";")]
            rs = [r[:-2] if r.endswith("する") and not any(h.endswith("する") for h in hs) else r
                  for r in rs if r and r not in hs]
            out.append({"level": level, "hs": hs, "r": rs})
    return out


def set_words(dump: Path) -> list[dict]:
    """Distinct words of the scored sets that came out without an example."""
    seen, out = set(), []
    for e in json.loads(dump.read_text(encoding="utf-8"))["entries"]:
        if e.get("ex_ja"):
            continue
        group = "synthetic" if e["set"].startswith("syn") else "local"
        k = (group, e["h"])
        if k in seen:
            continue
        seen.add(k)
        out.append({"group": group, "hs": [e["h"]], "r": e.get("r") or [],
                    "true": e.get("want") is not None})
    return out


def seqs_of(word: dict, idx: EntryIndex) -> list[str]:
    for h in word["hs"]:
        hits = idx.lookup(h, word["r"])
        if hits:
            return [e.seq for e in hits]
    return []


# --- measuring -------------------------------------------------------------

def candidates(word_seqs: list[str], sources: dict[str, dict], names: tuple[str, ...],
               readings: list[str] | tuple[str, ...] = ()) -> list[Example]:
    return [x for n in names for s in word_seqs for x in sources[n].get(s, ())
            if reading_agrees(x.reading, readings)]


def measure(words: list[dict], idx: EntryIndex, sources: dict, names: tuple[str, ...],
            known: set[str]) -> dict:
    n = found = any_ex = ko = ko_direct = en = easy = ko_any = ko_any_direct = 0
    lengths = []
    for w in words:
        seqs = seqs_of(w, idx)
        n += 1
        if not seqs:
            continue
        found += 1
        cands = candidates(seqs, sources, names, w["r"])
        if cands:
            any_ex += 1
        ok = [c for c in cands if usable(c)]
        ko_any += any(c.ko for c in ok)
        ko_any_direct += any(c.ko and c.ko_direct for c in ok)
        best = _best(cands, names, known)
        if not best:
            continue
        b = best[0]
        lengths.append(len(b.ja))
        ko += b.ko is not None
        ko_direct += b.ko is not None and b.ko_direct
        en += b.en is not None
        easy += unknown_kanji(b.ja, known) == 0
    filled = len(lengths)
    return {"words": n, "in_jmdict": found, "any": any_ex, "filled": filled, "ko": ko, "ko_direct": ko_direct, "ko_any": ko_any,
            "ko_any_direct": ko_any_direct,
            "en": en, "easy": easy,
            "median_len": sorted(lengths)[len(lengths) // 2] if lengths else 0}


def _best(cands: list[Example], names: tuple[str, ...], known: set[str], n: int = 2) -> list[Example]:
    """Per combo the sources are tried in order; one source fills a word."""
    for name in names:
        got = pick([c for c in cands if c.source == name], known, n)
        if got:
            return got
    return []


def write_sample(path: Path, words: list[dict], idx: EntryIndex, sources: dict,
                 names: tuple[str, ...], known: set[str]) -> None:
    rng = random.Random(SEED)
    filled = []
    for w in words:
        best = _best(candidates(seqs_of(w, idx), sources, names, w["r"]), names, known, 1)
        if best:
            filled.append((w, best[0]))
    rows = rng.sample(filled, min(SAMPLE_SIZE, len(filled)))
    with path.open("w", encoding="utf-8") as f:
        for w, b in rows:
            f.write(f"{w.get('level', w.get('group'))}\t{w['hs'][0]}\t{b.ja}\t{b.ko or ''}\t{b.en or ''}"
                    f"\t{b.ref}\t{'~' if b.checked else ''}\n")


def write_pivot_sample(path: Path, words: list[dict], idx: EntryIndex, sources: dict,
                       known: set[str]) -> None:
    """Tatoeba picks whose Korean came through English, to judge by eye."""
    rng = random.Random(SEED)
    rows = []
    for w in words:
        best = _best(candidates(seqs_of(w, idx), sources, ("tatoeba",), w["r"]), ("tatoeba",), known, 1)
        if best and best[0].ko and not best[0].ko_direct:
            rows.append((w, best[0]))
    with path.open("w", encoding="utf-8") as f:
        for w, b in rng.sample(rows, min(SAMPLE_SIZE, len(rows))):
            f.write(f"{w['level']}\t{w['hs'][0]}\t{b.ja}\t{b.ko}\t{b.en or ''}\n")


def asset_bytes(path: Path, sources: dict, names: tuple[str, ...], known: set[str], per_word: int,
                seqs: set[str] | None, with_en: bool) -> tuple[int, int, int]:
    """SQLite with ``per_word`` picked examples for every entry (or ``seqs``)
    that has one: (entries, sqlite bytes, gzip -9 bytes)."""
    if path.exists():
        path.unlink()
    db = sqlite3.connect(path)
    db.execute("CREATE TABLE example (seq INTEGER, ja TEXT NOT NULL, ko TEXT, en TEXT, "
               "src INTEGER, ref TEXT, author TEXT)")
    universe = set().union(*(sources[n].keys() for n in names))
    if seqs is not None:
        universe &= seqs
    entries = 0
    for seq in universe:
        best = _best(candidates([seq], sources, names), names, known, per_word)
        if not best:
            continue
        entries += 1
        db.executemany("INSERT INTO example VALUES (?,?,?,?,?,?,?)", [
            (int(seq), b.ja, b.ko, b.en if with_en else None, SOURCES.index(b.source), b.ref, b.author)
            for b in best])
    db.execute("CREATE INDEX example_seq ON example(seq)")
    db.commit()
    db.execute("VACUUM")
    db.close()
    raw = path.read_bytes()
    return entries, len(raw), len(gzip.compress(raw, 9, mtime=0))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--private", type=Path, default=PRIVATE)
    ap.add_argument("--samples", type=Path)
    ap.add_argument("--assets", type=Path)
    ap.add_argument("--picks", type=Path, help="JSON of the Tatoeba pick per JLPT word (local)")
    a = ap.parse_args()
    ex, me = a.private / "examples", a.private / "meaning"

    idx, jm = load_jmdict(ex / "raw/JMdict_e_examp.gz")
    tat, tables = load_tatoeba(ex / "raw/tatoeba", idx)
    sources = {
        "tatoeba": tat,
        "jmdict": jmdict_with_tatoeba(jm, tables),
        "kowikt": load_wikt("kowikt", me / "raw/ko-extract.jsonl.gz", idx),
        "jawikt": load_wikt("jawikt", me / "raw/ja-extract.jsonl.gz", idx),
        "enwikt": load_wikt("enwikt", ex / "work/enwikt-ja-entries.jsonl.gz", idx),
    }
    print("tatoeba", json.dumps(tables["stats"]))
    for name, by_seq in sources.items():
        exs = [e for v in by_seq.values() for e in v]
        print(f"{name}: entries {len(by_seq)}, examples {len(exs)}, usable {sum(map(usable, exs))}, "
              f"with ko {sum(e.ko is not None for e in exs)}")

    jlpt = jlpt_words(me / "raw")
    known = {k for w in jlpt for h in w["hs"] for k in kanji_of(h)}
    sets = set_words(me / "work/after.json")
    lists = {
        "jlpt-n5": [w for w in jlpt if w["level"] == "n5"],
        "jlpt-n4": [w for w in jlpt if w["level"] == "n4"],
        "jlpt-n3": [w for w in jlpt if w["level"] == "n3"],
        "sets-local": [w for w in sets if w["group"] == "local"],
        "sets-local-true": [w for w in sets if w["group"] == "local" and w["true"]],
        "sets-synthetic": [w for w in sets if w["group"] == "synthetic"],
    }
    combos = {**{s: (s,) for s in SOURCES}, **COMBOS}
    for lname, words in lists.items():
        for cname, names in combos.items():
            print(lname, cname, json.dumps(measure(words, idx, sources, names, known)))

    if a.samples:
        a.samples.mkdir(parents=True, exist_ok=True)
        for cname, names in combos.items():
            write_sample(a.samples / f"sample-{cname}.tsv", jlpt, idx, sources, names, known)
        write_pivot_sample(a.samples / "sample-tatoeba-pivot-ko.tsv", jlpt, idx, sources, known)
    if a.picks:
        rows = []
        for w in jlpt:
            best = _best(candidates(seqs_of(w, idx), sources, ("tatoeba",), w["r"]), ("tatoeba",), known, 1)
            if best:
                rows.append({"h": w["hs"][0], "r": w["r"], "ja": best[0].ja})
        a.picks.write_text(json.dumps(rows, ensure_ascii=False), encoding="utf-8")
    if a.assets:
        a.assets.mkdir(parents=True, exist_ok=True)
        jlpt_seqs = {s for w in jlpt for s in seqs_of(w, idx)}
        for cname, names in combos.items():
            for per in (1, 2):
                for scope, seqs in (("all", None), ("jlpt", jlpt_seqs)):
                    for with_en in (False, True):
                        n, b, g = asset_bytes(a.assets / "probe.sqlite", sources, names, known,
                                              per, seqs, with_en)
                        print("asset", cname, f"per={per}", scope, "en" if with_en else "no-en",
                              f"entries={n} sqlite={b} gzip={g}")


if __name__ == "__main__":
    main()
