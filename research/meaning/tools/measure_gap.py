"""How much each Wiktionary source fills where the Korean glossary is empty.

Input: a JSON dump (local only) with
- ``w74``: printed words ``{h, r, want, pos, senses}`` (``senses`` = the
  glossary's senses in the app's order, each a list of Korean words);
- ``entries``: every entry of the scored sets ``{set, h, r, meaning, src, ...}``
  (``src`` null = no meaning on the page and none from the glossary).

Prints numbers only (``--detail FILE`` writes the words, for a local folder).

Policies, both leaving every sense the glossary gives where it is:
- ``fill``: a source's senses only when the glossary has none;
- ``chips``: also after the glossary's senses, up to five in all.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from gap_sources import SOURCES, Index, Sense, asset_size, load_all

MEANING_SENSES = 5  # packages/core meaning_senses.dart

# Sources used together: their senses follow one another in this order.
COMBOS = {"kowikt+enwikt_tr": ("kowikt", "enwikt_tr"), "all": SOURCES}

_NOTE = re.compile(r"[（(][^）)]*[）)]")
_SPLIT = re.compile("[,，、/·;~]")


def answer_words(meaning: str) -> set[str]:
    """Same split as the app's scorer for printed meanings."""
    return {w.replace(" ", "").strip() for w in _SPLIT.split(_NOTE.sub("", meaning))
            if w.replace(" ", "").strip()}


def names(words: list[str] | tuple[str, ...], answer: set[str]) -> bool:
    return any(w.replace(" ", "") in answer for w in words)


def merged(glossary: list[list[str]], extra: list[Sense], policy: str) -> list[tuple[str, ...]]:
    """The senses shown: the glossary's, then (by [policy]) the source's."""
    base = [tuple(s) for s in glossary]
    if policy == "fill" and base:
        return base[:MEANING_SENSES]
    seen = {w for s in base for w in s}
    out = list(base)
    for s in extra:
        words = tuple(w for w in s.words if w not in seen)
        if words:
            out.append(words)
            seen.update(words)
    return out[:MEANING_SENSES]


def ranks(w74: list[dict], sources: dict[str, Index], policy: str) -> tuple[int, int]:
    first = within = 0
    for w in w74:
        extra = [s for name in sources for s in sources[name].lookup(w["h"], w["r"])]
        shown = merged(w["senses"], extra, policy)
        answer = answer_words(w["want"])
        if shown and names(shown[0], answer):
            first += 1
        if any(names(s, answer) for s in shown):
            within += 1
    return first, within


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("dump", type=Path)
    ap.add_argument("--kowikt", type=Path, help="kaikki ko-extract.jsonl(.gz)")
    ap.add_argument("--jawikt", type=Path, help="kaikki ja-extract.jsonl(.gz)")
    ap.add_argument("--en-pivot", type=Path, help="rows written by en_pivot_rows.py")
    ap.add_argument("--gap", nargs="*", default=[], help="headwords of the gap sample")
    ap.add_argument("--detail", type=Path)
    args = ap.parse_args()
    d = json.loads(args.dump.read_text())
    sources = load_all(args.kowikt, args.jawikt, args.en_pivot)
    names_ = [s for s in SOURCES if s in sources]
    combos = {k: v for k, v in COMBOS.items() if all(x in sources for x in v)}

    def use(name: str) -> dict[str, Index]:
        return {x: sources[x] for x in combos.get(name, (name,))}

    detail = args.detail.open("w") if args.detail else None
    w74 = d["w74"]
    print(f"74 words: glossary only {ranks(w74, {}, 'fill')}")
    for policy in ("fill", "chips"):
        for name in names_:
            print(f"  {policy:5} + {name:10} {ranks(w74, {name: sources[name]}, policy)}")
        for name in combos:
            print(f"  {policy:5} + {name} {ranks(w74, use(name), policy)}")

    gap = [w for w in w74 if w["h"] in set(args.gap)]
    print(f"gap sample: {len(gap)} words")
    for name in names_:
        hit = strict = 0
        for w in gap:
            got = sources[name].lookup(w["h"], w["r"])
            if got:
                hit += 1
            if any(names(s.words, answer_words(w["want"])) for s in got):
                strict += 1
            if detail:
                detail.write(f"GAP {name} {w['h']} want={w['want']} got={[s.words for s in got][:5]}\n")
        print(f"  {name:10} gives {hit}, names the printed word {strict}")

    empty = [e for e in d["entries"] if e["src"] is None]
    uniq = {(e["h"], tuple(e["r"])) for e in empty}
    print(f"set entries with no meaning: {len(empty)} ({len(uniq)} distinct)")
    for name in names_ + list(combos):
        u_ = use(name)
        n = sum(1 for e in empty if any(u_[k].lookup(e["h"], e["r"]) for k in u_))
        u = sum(1 for h, r in uniq if any(u_[k].lookup(h, list(r)) for k in u_))
        print(f"  {name:10} fills {n} ({u} distinct)")
        if detail and name in sources:
            for h, r in sorted(uniq):
                got = sources[name].lookup(h, list(r))
                if got:
                    detail.write(f"EMPTY {name} {h} {list(r)} -> {[s.words for s in got][:3]}\n")
    filled = [e for e in d["entries"] if e["src"] == "dictionary"]
    print(f"set entries filled from the glossary: {len(filled)}")
    for name in names_:
        n = sum(1 for e in filled if sources[name].lookup(e["h"], e["r"]))
        print(f"  {name:10} also has {n}")
    jlpt = d.get("jlpt") or []
    for level in ("n5", "n4", "n3"):
        rows = [x for x in jlpt if x["level"] == level]
        empty_rows = [x for x in rows if not x["senses"]]
        if not rows:
            continue
        line = [f"jlpt {level}: {len(rows)}, glossary empty {len(empty_rows)};"]
        for name in names_ + list(combos):
            u_ = use(name)
            n = sum(1 for x in empty_rows
                    if any(u_[k].lookup(h, x["r"]) for k in u_ for h in x.get("alts") or [x["h"]]))
            line.append(f"{name} {n}")
        print(" ".join(line))
        if detail:
            for x in empty_rows:
                for name in names_:
                    got = [s.words for h in x.get("alts") or [x["h"]] for s in sources[name].lookup(h, x["r"])]
                    if got:
                        detail.write(f"JLPT {level} {name} {x['h']} {x['r']} -> {got[:3]}\n")
    for name in names_:
        raw, gz = asset_size(sources[name])
        print(f"asset {name:10} keys {len(sources[name])}: sqlite {raw:,} bytes, gzip {gz:,}")
    if detail:
        detail.close()


if __name__ == "__main__":
    main()
