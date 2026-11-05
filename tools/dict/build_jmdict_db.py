#!/usr/bin/env python3
"""Build the compact JMdict SQLite used by packages/dict_jmdict.

Source: EDRDG JMdict_e.gz (English-only JMdict XML). License: CC BY-SA 4.0
(EDRDG licence, https://www.edrdg.org/edrdg/licence.html). The download is kept in
tools/dict/.cache/ (git-ignored); the output is deterministic for a given source file.

Usage:
  python3 tools/dict/build_jmdict_db.py                         # full entries, first-sense glosses
  python3 tools/dict/build_jmdict_db.py --entries common --glosses none --out out/common-lean.sqlite
  python3 tools/dict/build_jmdict_db.py --matrix                # build every variant, print a size table
  python3 tools/dict/build_jmdict_db.py --matrix --expect-sha256 7f6dc7a4…  # refuse any other source file
  python3 tools/dict/build_jmdict_db.py --only tools/dict/test_forms.txt --glosses first \
      --sql packages/dict_jmdict/test/fixtures/mini_jmdict.sql   # small test fixture as SQL text

Only the Python 3 standard library is used.
"""
from __future__ import annotations

import argparse
import contextlib
import gzip
import hashlib
import io
import os
import re
import shutil
import sqlite3
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Iterable, Iterator

HERE = Path(__file__).resolve().parent
CACHE = HERE / ".cache"
OUT = HERE / "out"
# Same file as http://ftp.edrdg.org/pub/Nihongo/JMdict_e.gz, over TLS (ftp.edrdg.org has no matching cert).
DEFAULT_URL = "https://www.edrdg.org/pub/Nihongo/JMdict_e.gz"
MAX_XML_BYTES = 512 * 1024 * 1024  # JMdict_e is ~60 MB uncompressed; refuse anything far larger
DEFAULT_SOURCE = CACHE / "JMdict_e.gz"

SCHEMA_VERSION = 1
LICENSE = "CC BY-SA 4.0"
LICENSE_URL = "https://www.edrdg.org/edrdg/licence.html"
PROJECT_URL = "https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project"
# EDRDG's sample acknowledgement. Apps must show it on a separate screen (About / Sources)
# with links to the project and licence pages (licence section 3).
ATTRIBUTION = (
    "This application uses the JMdict dictionary files. These files are the property of the "
    "Electronic Dictionary Research and Development Group, and are used in conformance with "
    f"the Group's licence. JMdict: {PROJECT_URL} Licence: {LICENSE_URL}"
)

# Priority tags (ke_pri / re_pri) as bits. nfXX is stored separately as a number.
PRI_BITS = {"news1": 1, "news2": 2, "ichi1": 4, "ichi2": 8, "spec1": 16, "spec2": 32, "gai1": 64, "gai2": 128}
# JMdict's own definition of a "common" word (the P marker in EDICT / WWWJDIC).
COMMON_MASK = PRI_BITS["news1"] | PRI_BITS["ichi1"] | PRI_BITS["spec1"] | PRI_BITS["spec2"] | PRI_BITS["gai1"]

SCHEMA = f"""
PRAGMA user_version = {SCHEMA_VERSION};
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) WITHOUT ROWID;
CREATE TABLE tag (code TEXT PRIMARY KEY, description TEXT NOT NULL) WITHOUT ROWID;
CREATE TABLE entry (
  id INTEGER PRIMARY KEY,   -- JMdict ent_seq
  pos TEXT NOT NULL,        -- POS codes of all senses, space separated, first-seen order
  misc TEXT NOT NULL        -- misc codes of all senses (uk, abbr, ...), space separated
);
CREATE TABLE kanji (
  entry_id INTEGER NOT NULL,
  ord INTEGER NOT NULL,     -- order inside the entry, 0-based
  text TEXT NOT NULL,       -- keb
  pri INTEGER NOT NULL,     -- bitmask of news1 news2 ichi1 ichi2 spec1 spec2 gai1 gai2
  nf INTEGER,               -- nfXX band (1 = 500 most frequent words in the news corpus)
  inf TEXT NOT NULL,        -- ke_inf codes (ateji iK oK rK sK io ik), space separated
  PRIMARY KEY (entry_id, ord)
) WITHOUT ROWID;
CREATE TABLE reading (
  entry_id INTEGER NOT NULL,
  ord INTEGER NOT NULL,
  text TEXT NOT NULL,       -- reb
  pri INTEGER NOT NULL,
  nf INTEGER,
  inf TEXT NOT NULL,        -- re_inf codes (gikun ik ok rk sk), space separated
  nokanji INTEGER NOT NULL, -- 1: not a true reading of the kanji forms (re_nokanji)
  restr TEXT NOT NULL,      -- kanji forms this reading is limited to, tab separated; '' = all
  PRIMARY KEY (entry_id, ord)
) WITHOUT ROWID;
CREATE TABLE sense (
  entry_id INTEGER NOT NULL,
  ord INTEGER NOT NULL,
  pos TEXT NOT NULL,
  gloss TEXT NOT NULL,      -- English glosses joined by '; '
  PRIMARY KEY (entry_id, ord)
) WITHOUT ROWID;
CREATE INDEX kanji_by_text ON kanji(text);
CREATE INDEX reading_by_text ON reading(text);
"""

ENTITY_DECL = re.compile(r'<!ENTITY\s+([^\s]+)\s+"([^"]*)">')
ENTITY_REF = re.compile(r"&([A-Za-z0-9_-]+);")
CREATED = re.compile(r"<!-- JMdict created: (\d{4}-\d{2}-\d{2}) -->")


# ---------------------------------------------------------------- source

def fetch(url: str, dest: Path) -> None:
    """Download to a temporary file first, so an interrupted download never looks complete."""
    if not url.startswith("https://"):
        print(f"warning: {url} is not https; check the file with --expect-sha256", file=sys.stderr)
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_name(dest.name + ".part")
    print(f"downloading {url} -> {dest}", file=sys.stderr)
    with urllib.request.urlopen(url, timeout=120) as r, part.open("wb") as f:  # noqa: S310 (EDRDG or user URL)
        shutil.copyfileobj(r, f)
        last_modified = r.headers.get("Last-Modified", "")
    os.replace(part, dest)
    (dest.parent / (dest.name + ".last-modified")).write_text(last_modified, encoding="utf-8")


def decompress(raw: bytes) -> bytes:
    with gzip.GzipFile(fileobj=io.BytesIO(raw)) as f:
        data = f.read(MAX_XML_BYTES + 1)
    if len(data) > MAX_XML_BYTES:
        sys.exit(f"decompressed source is larger than {MAX_XML_BYTES} bytes; refusing to build")
    return data


def read_source(path: Path) -> tuple[str, dict[str, str]]:
    raw = path.read_bytes()
    text = (decompress(raw) if path.suffix == ".gz" else raw).decode("utf-8")
    created = CREATED.search(text)
    lm = path.parent / (path.name + ".last-modified")
    info = {
        "source_file": path.name,
        "source_sha256": hashlib.sha256(raw).hexdigest(),
        "jmdict_created": created.group(1) if created else "",
        "source_last_modified": lm.read_text(encoding="utf-8").strip() if lm.exists() else "",
    }
    return text, info


def split_dtd(text: str) -> tuple[dict[str, str], str]:
    """Return entity code -> description, and the body with declared entity refs replaced by their codes.

    The DTD (with its entity declarations) is dropped, so the XML parser never expands anything.
    References that the DTD did not declare are left alone and make the parser fail loudly.
    """
    end = text.find("]>")
    if end < 0:
        sys.exit("no internal DTD found; is this a JMdict XML file?")
    entities = dict(ENTITY_DECL.findall(text[:end]))
    body = ENTITY_REF.sub(lambda m: m.group(1) if m.group(1) in entities else m.group(0), text[end + 2:])
    return entities, body


# ---------------------------------------------------------------- parse

def parse_entries(body: str) -> Iterator[dict]:
    """Yield one dict per <entry>, in file order."""
    root = None
    for event, el in ET.iterparse(io.StringIO(body), events=("start", "end")):
        if root is None:
            root = el  # <JMdict>
        if event != "end" or el.tag != "entry":
            continue
        seq = int(el.findtext("ent_seq"))
        kanji = [
            {"text": k.findtext("keb"),
             "pri": [p.text for p in k.findall("ke_pri")],
             "inf": [i.text for i in k.findall("ke_inf")]}
            for k in el.findall("k_ele")
        ]
        readings = [
            {"text": r.findtext("reb"),
             "pri": [p.text for p in r.findall("re_pri")],
             "inf": [i.text for i in r.findall("re_inf")],
             "nokanji": r.find("re_nokanji") is not None,
             "restr": [x.text for x in r.findall("re_restr")]}
            for r in el.findall("r_ele")
        ]
        senses, last_pos = [], []
        for s in el.findall("sense"):
            pos = [p.text for p in s.findall("pos")] or last_pos  # POS carries over to later senses
            last_pos = pos
            senses.append({"pos": pos,
                           "misc": [m.text for m in s.findall("misc")],
                           "gloss": [g.text for g in s.findall("gloss") if g.text]})
        root.clear()  # el.clear() alone would leave ~220k empty <entry> stubs under the root
        yield {"seq": seq, "kanji": kanji, "readings": readings, "senses": senses}


def pri_value(tags: list[str]) -> tuple[int, int | None]:
    bits, nf = 0, None
    for t in tags:
        if t in PRI_BITS:
            bits |= PRI_BITS[t]
        elif t.startswith("nf"):
            nf = int(t[2:])
    return bits, nf


def is_common(e: dict) -> bool:
    return any(pri_value(f["pri"])[0] & COMMON_MASK for f in e["kanji"] + e["readings"])


def uniq(xs: Iterable[str]) -> list[str]:
    seen, out = set(), []
    for x in xs:
        if x not in seen:
            seen.add(x); out.append(x)
    return out


def load_only(path: Path) -> set[str]:
    forms = set()
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            forms.add(line)
    return forms


# ---------------------------------------------------------------- build

def build(entities: dict[str, str], body: str, info: dict[str, str], *, entries: str, glosses: str,
          out: Path | None = None, sql_out: Path | None = None, only: set[str] | None = None,
          only_label: str = "") -> dict[str, int]:
    """Build one variant in memory, then write it to [out] (.sqlite) or [sql_out] (SQL text)."""
    meta = {
        "schema_version": str(SCHEMA_VERSION),
        **info,
        "entries": entries,
        "glosses": glosses,
        "license": LICENSE,
        "license_url": LICENSE_URL,
        "project_url": PROJECT_URL,
        "attribution": ATTRIBUTION,
    }
    if only is not None:
        meta["subset"] = f"entries with a form listed in {only_label}"
    with contextlib.closing(sqlite3.connect(":memory:")) as db:
        db.executescript(SCHEMA)
        db.executemany("INSERT INTO tag VALUES (?, ?)", sorted(entities.items()))
        n = 0
        for e in parse_entries(body):
            if entries == "common" and not is_common(e):
                continue
            if only is not None and not any(f["text"] in only for f in e["kanji"] + e["readings"]):
                continue
            n += 1
            insert_entry(db, e, glosses)
        meta["entry_count"] = str(n)
        db.executemany("INSERT INTO meta VALUES (?, ?)", sorted(meta.items()))
        db.commit()

        stats = {"entries": n}
        for t in ("kanji", "reading", "sense"):
            stats[t] = db.execute(f"SELECT count(*) FROM {t}").fetchone()[0]  # noqa: S608 (fixed names)
        if sql_out is not None:
            write_sql(db, sql_out)
            stats["bytes"] = sql_out.stat().st_size
        if out is not None:
            out.parent.mkdir(parents=True, exist_ok=True)
            if out.exists():
                out.unlink()
            with contextlib.closing(sqlite3.connect(out)) as disk:
                db.backup(disk)
                disk.execute("VACUUM")
            data = out.read_bytes()
            stats["bytes"] = len(data)
            stats["gzip"] = len(gzip.compress(data, compresslevel=9, mtime=0))
    return stats


def insert_entry(db: sqlite3.Connection, e: dict, glosses: str) -> None:
    pos = uniq(p for s in e["senses"] for p in s["pos"])
    misc = uniq(m for s in e["senses"] for m in s["misc"])
    db.execute("INSERT INTO entry VALUES (?, ?, ?)", (e["seq"], " ".join(pos), " ".join(misc)))
    for i, k in enumerate(e["kanji"]):
        bits, nf = pri_value(k["pri"])
        db.execute("INSERT INTO kanji VALUES (?, ?, ?, ?, ?, ?)",
                   (e["seq"], i, k["text"], bits, nf, " ".join(k["inf"])))
    for i, r in enumerate(e["readings"]):
        bits, nf = pri_value(r["pri"])
        db.execute("INSERT INTO reading VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                   (e["seq"], i, r["text"], bits, nf, " ".join(r["inf"]), int(r["nokanji"]),
                    "\t".join(r["restr"])))
    senses = e["senses"] if glosses == "all" else e["senses"][:1] if glosses == "first" else []
    for i, s in enumerate(senses):
        db.execute("INSERT INTO sense VALUES (?, ?, ?, ?)",
                   (e["seq"], i, " ".join(s["pos"]), "; ".join(s["gloss"])))


def write_sql(db: sqlite3.Connection, path: Path) -> None:
    lines = [
        "-- JMdict subset for dict_jmdict unit tests. Generated by tools/dict/build_jmdict_db.py --only.",
        f"-- Data: JMdict (EDRDG), {LICENSE}. {ATTRIBUTION}",
        f"PRAGMA user_version = {SCHEMA_VERSION};",
    ]
    lines += [l for l in db.iterdump() if l not in ("BEGIN TRANSACTION;", "COMMIT;")]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


# ---------------------------------------------------------------- cli

MATRIX = [
    ("full-all", "all", "all", "전체 항목 · 모든 뜻"),
    ("full-first", "all", "first", "전체 항목 · 첫 뜻만"),
    ("full-lean", "all", "none", "전체 항목 · 뜻 없음"),
    ("common-all", "common", "all", "상용어만 · 모든 뜻"),
    ("common-first", "common", "first", "상용어만 · 첫 뜻만"),
    ("common-lean", "common", "none", "상용어만 · 뜻 없음"),
]


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--source", type=Path, default=DEFAULT_SOURCE, help="JMdict_e(.gz) path")
    ap.add_argument("--url", default=DEFAULT_URL, help="download URL when --source is missing")
    ap.add_argument("--expect-sha256", help="stop unless the source file has this sha256")
    ap.add_argument("--entries", choices=["all", "common"], help="default: all")
    ap.add_argument("--glosses", choices=["all", "first", "none"], help="default: first")
    ap.add_argument("--only", type=Path, help="keep only entries that have one of these forms (one per line)")
    ap.add_argument("--out", type=Path,
                    help="output .sqlite (default: tools/dict/out/jmdict-<full|common>-<glosses>.sqlite)")
    ap.add_argument("--sql", type=Path, help="write a SQL text dump instead of a .sqlite file")
    ap.add_argument("--matrix", action="store_true", help="build every variant into tools/dict/out and print sizes")
    a = ap.parse_args(argv)
    if a.matrix and any(v is not None for v in (a.entries, a.glosses, a.only, a.out, a.sql)):
        ap.error("--matrix builds fixed variants; drop --entries/--glosses/--only/--out/--sql")
    entries, glosses = a.entries or "all", a.glosses or "first"

    if not a.source.exists():
        if a.source != DEFAULT_SOURCE:
            print(f"source not found: {a.source}", file=sys.stderr)
            return 2
        fetch(a.url, a.source)
    text, info = read_source(a.source)
    if a.expect_sha256 and info["source_sha256"] != a.expect_sha256.lower():
        print(f"sha256 mismatch: {a.source} is {info['source_sha256']}, expected {a.expect_sha256}",
              file=sys.stderr)
        return 3
    info = {"source_url": a.url, **info}
    print(f"source {info['source_file']} created {info['jmdict_created']} sha256 {info['source_sha256'][:16]}…",
          file=sys.stderr)
    entities, body = split_dtd(text)
    del text  # keep one copy of the ~60 MB XML in memory, not two

    if a.matrix:
        print("| 판본 | 설명 | 항목 | 표기 | 읽기 | 뜻(sense) | SQLite | gzip -9 |")
        print("|---|---|---:|---:|---:|---:|---:|---:|")
        for name, var_entries, var_glosses, label in MATRIX:
            s = build(entities, body, info, entries=var_entries, glosses=var_glosses,
                      out=OUT / f"jmdict-{name}.sqlite")
            print(f"| `{name}` | {label} | {s['entries']:,} | {s['kanji']:,} | {s['reading']:,} | {s['sense']:,} "
                  f"| {s['bytes'] / 1e6:.1f} MB | {s['gzip'] / 1e6:.1f} MB |", flush=True)
        return 0

    only = load_only(a.only) if a.only else None
    label = a.only.name if a.only else ""
    if a.sql:
        s = build(entities, body, info, entries=entries, glosses=glosses, sql_out=a.sql, only=only,
                  only_label=label)
        print(f"wrote {a.sql}: {s}", file=sys.stderr)
        return 0
    out = a.out or OUT / f"jmdict-{'full' if entries == 'all' else 'common'}-{glosses}.sqlite"
    s = build(entities, body, info, entries=entries, glosses=glosses, out=out, only=only, only_label=label)
    print(f"wrote {out}: {s}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
