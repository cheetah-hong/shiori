#!/usr/bin/env python3
"""Geometry-free OCR check: is each ground-truth field present in the OCR text at all?

parse_eval scores the whole pipeline (OCR + layout rules). Its layout rules react to single stray tokens
(one meaning read as "8200" becomes a fake neighbour page), so this script measures OCR quality alone.

usage: python3 text_recall.py <fixtures_dir> [<fixtures_dir> ...]
  headword: some Japanese-pass line equals the headword after one of the clean-ups below
            (as read / id removed / id and checkbox glyphs removed; stars and spaces always removed),
            a trailing reading on the same line is allowed. Trying each clean-up keeps real katakana such as
            "コレラ" from being eaten by the checkbox pattern.
  reading : some Japanese-pass line, reduced to kana and "/", equals the readings
  meaning : some Korean-pass line, spaces removed, contains the meaning
  star    : Japanese-pass lines holding ★ or ☆ (treated alike, the book prints only ★), legend line excluded
  example : best share of the sentence's characters matched inside WINDOW consecutive lines (reading order) >= 0.9
            (a window, not the whole page, so scattered common kana cannot add up to a match)
"""
import difflib
import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Dict, List, Set, Tuple

from run_eval import GT
ID = re.compile(r"^[\s★☆*]*[0-9Il|]{2,4}\s*")
BOX = re.compile(r"^[□口ロコ■LDレ目問gG8]{2,}\s*|^[□口ロコ■LDレ目問gG8]\s+")
MARKS = re.compile(r"[★☆*\s]")
STAR = re.compile(r"[★☆]")
# the ★ legend line at the top of a page (★ 표시 = …) comes back from the Japanese pass as garbage, hence the token list
LEGEND = re.compile(r"표시|2010|三人|=")
WINDOW = 12  # a sentence spans up to three text lines plus furigana, and skewed pages interleave other lines

Counts = Dict[str, List[int]]


def nfkc(s: str) -> str:
    return unicodedata.normalize("NFKC", s)


def kana(s: str) -> str:
    return "".join(c for c in nfkc(s) if "぀" <= c <= "ヿ" or c == "/")


def squash(s: str) -> str:
    return re.sub(r"\s+", "", nfkc(s))


def head_candidates(text: str) -> Set[str]:
    t = nfkc(text)
    no_id = ID.sub("", t, count=1)
    return {MARKS.sub("", c) for c in (t, no_id, BOX.sub("", no_id, count=1), BOX.sub("", t.lstrip(" ★☆*"), count=1))}


def coverage(sentence: str, text: str) -> float:
    m = difflib.SequenceMatcher(None, sentence, text, autojunk=False)
    return sum(b.size for b in m.get_matching_blocks()) / max(len(sentence), 1)


def best_coverage(sentence: str, lines: List[str]) -> float:
    best = 0.0
    for i in range(len(lines)):
        best = max(best, coverage(sentence, "".join(lines[i:i + WINDOW])))
        if best >= 1.0:
            break
    return best


def is_star_line(text: str) -> bool:
    return bool(STAR.search(text)) and not LEGEND.search(text)


def reading_order(lines: List[dict]) -> List[str]:
    return [squash(l["t"]) for l in sorted(lines, key=lambda l: (l["y"], l["x"]))]


def recall(fixtures: Path, gt_pages: List[dict] = None) -> Tuple[Counts, List[int]]:
    pages = gt_pages if gt_pages is not None else json.loads(GT.read_text())["pages"]
    tot = {k: [0, 0] for k in ("headword", "reading", "meaning", "example_ja", "example_ko")}
    stars = [0, 0]
    for pg in pages:
        ja = json.loads((fixtures / f"{pg['fixture']}.ja.json").read_text())["lines"]
        ko = json.loads((fixtures / f"{pg['fixture']}.ko.json").read_text())["lines"]
        heads = set().union(*(head_candidates(l["t"]) for l in ja)) if ja else set()
        reads = {kana(l["t"]) for l in ja}
        metas = [squash(l["t"]) for l in ko]
        order = {"ja": reading_order(ja), "ko": reading_order(ko)}
        for e in pg["entries"]:
            h, rd = e["headword"], "/".join(e["readings"])
            tot["headword"][1] += 1
            tot["headword"][0] += h in heads or bool(rd and h + rd.replace("/", "") in heads)
            if rd:
                tot["reading"][1] += 1
                tot["reading"][0] += rd in reads
            tot["meaning"][1] += 1
            tot["meaning"][0] += any(squash(e["meaning"]) in m for m in metas)
            if "example" in e:
                for side in ("ja", "ko"):
                    tot[f"example_{side}"][1] += 1
                    tot[f"example_{side}"][0] += best_coverage(squash(e["example"][side]), order[side]) >= 0.9
        stars[0] += sum(1 for l in ja if is_star_line(l["t"]))
        stars[1] += sum(e["important"] for e in pg["entries"])
    return tot, stars


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    print("| 판독 결과 | 표제어 | 읽기 | 뜻 | ★ 줄 수(정답) | 예문(일) | 예문(한) |")
    print("|---|---|---|---|---|---|---|")
    for d in sys.argv[1:]:
        tot, stars = recall(Path(d))
        g = lambda k: f"{tot[k][0]}/{tot[k][1]}"
        print(f"| {Path(d).parent.name}/{Path(d).name} | {g('headword')} | {g('reading')} | {g('meaning')} | "
              f"{stars[0]} ({stars[1]}) | {g('example_ja')} | {g('example_ko')} |")


if __name__ == "__main__":
    main()
