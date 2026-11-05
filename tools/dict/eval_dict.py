#!/usr/bin/env python3
"""Measure what the JMdict block adds to the reference OCR parser.

The reference parser (parse_eval.py) reads the 59 recorded textbook rows; every
dictionary call goes through the real Dart package (packages/dict_jmdict,
tool/query_batch.dart), so the numbers are the package's, not a Python copy.

  (a) rows whose headword was not read: is the answer the 1st / top-3 suggestion?
  (b) do pair checks catch wrong rows the parser did not flag, and do they agree
      with (or undo) the rule-based glyph corrections?
  (c) false alarms: correct rows the dictionary calls "not found".

The same checks run on a wider, simulated set when the JLPT N5–N3 lists are in
tools/dict/.cache/jlpt (Waller's lists with JMdict ids, from
github.com/stephenmk/yomitan-jlpt-vocab, CC BY-SA 4.0; --fetch-jlpt downloads them):
missing-headword ranking, look-alike glyph injection, and pair coverage per DB.

Usage:
  python3 tools/dict/eval_dict.py [--db PATH ...] [--prototype DIR] [--truth FILE] [--fetch-jlpt] [--verbose]

The recorded textbook rows are local only: the reference parser reads them from
$SHIORI_PRIVATE_DIR/textbook/vocab_n5n3 (SHIORI_PRIVATE_DIR defaults to <repo>/.private),
and --truth defaults to the ground truth there. Textbook text read here stays in memory;
nothing is written anywhere that is committed.
"""
from __future__ import annotations

import argparse
import contextlib
import csv
import importlib
import json
import sqlite3
import subprocess
import sys
import urllib.request
from pathlib import Path

sys.dont_write_bytecode = True  # imports below may come from another checkout (--prototype): write nothing there
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_jmdict_db import COMMON_MASK  # noqa: E402 (needs the path above)

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
PKG = REPO / "packages" / "dict_jmdict"
CACHE = HERE / ".cache"
JLPT_URL = "https://raw.githubusercontent.com/stephenmk/yomitan-jlpt-vocab/main/original_data/{}.csv"
LEVELS = ["n5", "n4", "n3"]
DEFAULT_DBS = [HERE / "out" / "jmdict-full-lean.sqlite", HERE / "out" / "jmdict-common-lean.sqlite"]
BATCH_TIMEOUT_S = 900  # the first `dart run` also builds hooks (downloads SQLite)
# textbook POS badge -> dict_jmdict WordClass names (what the core adapter would pass)
BADGE_CLASSES = {"명": ["noun"], "동": ["verb"], "형": ["iAdjective", "naAdjective"], "い형": ["iAdjective"],
                 "な형": ["naAdjective"], "부": ["adverb"], "접": ["conjunction"], "감": ["interjection"],
                 "연": ["adnominal"], "조": ["particle"]}
# kanji -> the look-alike OCR reads instead (the corrector table, read backwards)
LOOK_ALIKE = {"一": "ー", "十": "+", "二": "ニ", "八": "ハ", "口": "ロ", "夕": "タ", "工": "エ", "力": "カ"}


# ---------------------------------------------------------------- inputs

def find_prototype(arg: Path | None) -> Path:
    candidates = [arg] if arg else [REPO / "tools" / "reference", REPO / "research" / "ocr" / "prototype"]
    for c in candidates:
        if c and (c / "parse_eval.py").exists():
            return c
    sys.exit("parse_eval.py not found; pass --prototype DIR")


def load_parser(prototype: Path):
    """Import parse_eval and record each row's headword before the correctors ran."""
    sys.path.insert(0, str(prototype))
    pe = importlib.import_module("parse_eval")
    original = pe.correct

    def spy(entry):
        raw = entry["headword"]
        out = original(entry)
        out["raw_headword"] = raw
        return out

    pe.correct = spy  # parse_list / parse_entry look the name up at call time
    return pe, original


def textbook_rows(pe, truth_path: Path) -> list[dict]:
    truth = json.loads(truth_path.read_text(encoding="utf-8"))
    rows = []
    for page in truth["pages"]:
        ja, ko = pe.load(page["fixture"])
        parse = pe.parse_list if pe.detect(ja) == "list" else pe.parse_entry
        got = {e["no"]: e for e in parse(ja, ko)}
        for g in page["entries"]:
            e = got.get(g["no"])
            if e is None:
                rows.append({"page": page["page"], "no": g["no"], "missing_row": True,
                             "gt_h": g["headword"], "gt_r": g["readings"]})
                continue
            rows.append({"page": page["page"], "no": g["no"], "missing_row": False,
                         "gt_h": g["headword"], "gt_r": g["readings"],
                         "raw": e["raw_headword"], "h": e["headword"], "r": e["readings"], "pos": e["pos"],
                         "issues": [i for i in e["issues"] if not i.startswith("example")]})
    return rows


def jlpt_words(fetch: bool) -> list[dict]:
    words, seen = [], set()
    for level in LEVELS:
        path = CACHE / "jlpt" / f"{level}.csv"
        if not path.exists():
            if not fetch:
                return []
            path.parent.mkdir(parents=True, exist_ok=True)
            with urllib.request.urlopen(JLPT_URL.format(level), timeout=60) as r:  # noqa: S310 (fixed URL)
                path.write_bytes(r.read())
        with path.open(encoding="utf-8") as f:
            for row in csv.DictReader(f):
                key = (row["kanji"], row["kana"])
                if key in seen:
                    continue
                seen.add(key)
                words.append({"level": level.upper(), "kanji": row["kanji"], "kana": row["kana"],
                              "seq": int(row["jmdict_seq"])})
    return words


def entry_pos(db_path: Path, seqs: list[int]) -> dict[int, list[str]]:
    """JMdict POS codes of the given entries (to simulate the textbook's POS badge)."""
    with contextlib.closing(sqlite3.connect(db_path)) as db:
        rows = db.execute("SELECT id, pos FROM entry WHERE id IN (SELECT value FROM json_each(?))",
                          (json.dumps(seqs),)).fetchall()
    found = {seq: pos.split() for seq, pos in rows}
    return {seq: found.get(seq, []) for seq in seqs}


def db_entries(db_path: Path) -> str:
    """`all` or `common`, from the DB's meta table."""
    with contextlib.closing(sqlite3.connect(db_path)) as db:
        row = db.execute("SELECT value FROM meta WHERE key = 'entries'").fetchone()
    return row[0] if row else ""


def katakana_kanji_forms(db_path: Path) -> list[tuple[str, str, bool]]:
    """Real words that mix the corrector's katakana with kanji (タ行, カ所, ハ長調...)."""
    keys = "タロエカニハ"
    with contextlib.closing(sqlite3.connect(db_path)) as db:
        rows = db.execute(
            "SELECT k.text, r.text, r.restr, r.nokanji, (k.pri & r.pri & ?) != 0 FROM kanji k "
            "JOIN reading r ON r.entry_id = k.entry_id "
            "WHERE k.inf NOT LIKE '%sK%' AND r.inf NOT LIKE '%sk%' "
            "ORDER BY k.entry_id, k.ord, r.ord", (COMMON_MASK,)).fetchall()
    out, seen = [], set()
    for form, reading, restr, nokanji, common in rows:
        if nokanji or (restr and form not in restr.split("\t")):
            continue
        if any(c in keys for c in form) and any("一" <= c <= "鿿" for c in form) and form not in seen:
            seen.add(form)
            out.append((form, reading, bool(common)))
    return out


# ---------------------------------------------------------------- dart bridge

class Batch:
    def __init__(self):
        self.queries: list[dict] = []

    def check(self, h: str, r: str | None) -> int:
        self.queries.append({"op": "check", "headword": h, "reading": r})
        return len(self.queries) - 1

    def suggest(self, text: str, r: str | None, limit: int = 5, prefer: list[str] | None = None,
                prefer_pos: list[str] | None = None) -> int:
        self.queries.append({"op": "suggest", "text": text, "reading": r, "limit": limit,
                             "prefer": prefer or [], "prefer_pos": prefer_pos or []})
        return len(self.queries) - 1

    def run(self, db: Path) -> dict:
        try:
            proc = subprocess.run(["dart", "run", "tool/query_batch.dart", "--db", str(db)], cwd=PKG,
                                  input=json.dumps(self.queries, ensure_ascii=False), capture_output=True,
                                  text=True, check=False, timeout=BATCH_TIMEOUT_S)
        except subprocess.TimeoutExpired:
            sys.exit(f"query_batch did not finish within {BATCH_TIMEOUT_S} s")
        if proc.returncode != 0:
            sys.exit(f"query_batch failed ({proc.returncode}):\n{proc.stderr}")
        start = proc.stdout.find('{"info"')  # `dart run` may print "Running build hooks..." first
        if start < 0:
            sys.exit(f"query_batch printed no result:\n{proc.stdout[:500]}")
        return json.loads(proc.stdout[start:])


def rank_of(answer: str, suggestions: list[dict]) -> int | None:
    names = [s["headword"] for s in suggestions]
    return names.index(answer) + 1 if answer in names else None


# ---------------------------------------------------------------- textbook (a)(b)(c)

def plan_textbook(rows: list[dict], b: Batch) -> None:
    for row in rows:
        if row["missing_row"]:
            continue
        r0 = row["r"][0] if row["r"] else None
        row["q_checks"] = [b.check(row["h"], r) for r in (row["r"] or [None])] if row["h"] else []
        row["q_suggest"] = b.suggest(row["h"], r0) if (row["h"] or r0) else None
        row["q_suggest_pos"] = (b.suggest(row["h"], r0, prefer=BADGE_CLASSES.get(row["pos"], []))
                                if not row["h"] and r0 else None)
        row["q_raw_suggest"] = b.suggest(row["raw"], r0) if row["raw"] != row["h"] else None
        row["q_raw_check"] = b.check(row["raw"], r0) if row["raw"] != row["h"] and row["raw"] else None


def score_textbook(rows: list[dict], res: list, verbose: bool) -> dict:
    s = {"rows": len(rows), "missing_rows": 0, "a_cases": [], "core_wrong": 0, "core_wrong_flagged_parser": 0,
         "core_wrong_flagged_dict": 0, "new_catches": 0, "correct": 0, "fp": 0, "fp_rows": [],
         "match_kinds": {}, "corrections": [], "details": []}
    for row in rows:
        if row["missing_row"]:
            s["missing_rows"] += 1
            continue
        core_ok = row["h"] == row["gt_h"] and row["r"] == row["gt_r"]
        checks = [res[i] for i in row["q_checks"]]
        dict_flag = bool(row["h"]) and any(c["match"] == "none" for c in checks)
        for c in checks:
            s["match_kinds"][c["match"]] = s["match_kinds"].get(c["match"], 0) + 1
        sugg = res[row["q_suggest"]]["suggestions"] if row["q_suggest"] is not None else []
        if not row["h"]:  # (a) headword not read
            with_pos = res[row["q_suggest_pos"]]["suggestions"] if row["q_suggest_pos"] is not None else []
            s["a_cases"].append({"where": f'{row["page"]}·{row["no"]}', "answer": row["gt_h"],
                                 "reading": row["r"][0] if row["r"] else "", "rank": rank_of(row["gt_h"], sugg),
                                 "top3": [x["headword"] for x in sugg[:3]], "pos": row["pos"],
                                 "rank_pos": rank_of(row["gt_h"], with_pos),
                                 "top3_pos": [x["headword"] for x in with_pos[:3]]})
        if core_ok:
            s["correct"] += 1
            if dict_flag:
                s["fp"] += 1
                s["fp_rows"].append(f'{row["page"]}·{row["no"]} {row["h"]}【{"/".join(row["r"])}】')
        else:
            s["core_wrong"] += 1
            s["core_wrong_flagged_parser"] += bool(row["issues"])
            s["core_wrong_flagged_dict"] += dict_flag or not row["h"]
            s["new_catches"] += dict_flag and not row["issues"]
        if row["q_raw_suggest"] is not None:  # a rule-based correction happened
            raw_sugg = res[row["q_raw_suggest"]]["suggestions"]
            s["corrections"].append({
                "where": f'{row["page"]}·{row["no"]}', "raw": row["raw"], "rule": row["h"], "answer": row["gt_h"],
                "raw_check": res[row["q_raw_check"]]["match"] if row["q_raw_check"] is not None else "-",
                "rule_check": checks[0]["match"] if checks else "-",
                "dict_top": raw_sugg[0]["headword"] if raw_sugg else "",
            })
        if verbose and (not core_ok or dict_flag or row["raw"] != row["h"] or row["issues"]):
            s["details"].append(f'{row["page"]}·{row["no"]} raw={row["raw"]!r} h={row["h"]!r} r={row["r"]} '
                                f'gt={row["gt_h"]} issues={row["issues"]} checks={[c["match"] for c in checks]} '
                                f'top={[x["headword"] for x in sugg[:3]]}')
    return s


# ---------------------------------------------------------------- JLPT (simulated)

def inject(word: str) -> str | None:
    out = "".join(LOOK_ALIKE.get(c, c) for c in word)
    return out if out != word else None


def rule_fix(original_correct, headword: str, reading: str) -> str:
    e = {"headword": headword, "readings": [reading], "pos": "명", "meaning": "-", "issues": []}
    return original_correct(e)["headword"]


def plan_jlpt(words: list[dict], kata_forms: list, original_correct, b: Batch, pos: dict) -> dict:
    plan = {"words": words, "kata": []}
    for w in words:
        head = w["kanji"] or w["kana"]
        w["q_check"] = b.check(head, w["kana"] if w["kanji"] else None)
        if w["kanji"]:
            w["q_missing"] = b.suggest("", w["kana"], limit=5)
            w["q_missing_pos"] = b.suggest("", w["kana"], limit=5, prefer_pos=pos.get(w["seq"], []))
            bad = inject(w["kanji"])
            if bad:
                w["injected"] = bad
                w["rule"] = rule_fix(original_correct, bad, w["kana"])
                w["q_bad_check"] = b.check(bad, w["kana"])
                w["q_bad_suggest"] = b.suggest(bad, w["kana"], limit=3)
    for form, reading, common in kata_forms:
        fixed = rule_fix(original_correct, form, reading)
        if fixed == form:
            continue
        plan["kata"].append({"form": form, "reading": reading, "common": common, "rule": fixed,
                             "q_rule_check": b.check(fixed, reading),
                             "q_rule_suggest": b.suggest(fixed, reading, limit=3)})
    return plan


def score_jlpt(plan: dict, res: list) -> dict:
    s = {"levels": {}, "a": {"n": 0, "r1": 0, "r3": 0, "r5": 0}, "a_pos": {"n": 0, "r1": 0, "r3": 0, "r5": 0},
         "inj": {"n": 0, "detected": 0, "dict_fixed": 0, "rule_fixed": 0, "either": 0},
         "kata": {"n": 0, "common": 0, "caught": 0, "restored": 0, "examples": []}}
    for w in plan["words"]:
        lv = s["levels"].setdefault(w["level"], {"n": 0, "none": 0, "kinds": {}, "missing": []})
        lv["n"] += 1
        m = res[w["q_check"]]["match"]
        lv["kinds"][m] = lv["kinds"].get(m, 0) + 1
        if m == "none":
            lv["none"] += 1
            lv["missing"].append(w["kanji"] or w["kana"])
        if not w["kanji"]:
            continue
        for key, q in (("a", "q_missing"), ("a_pos", "q_missing_pos")):
            rank = rank_of(w["kanji"], res[w[q]]["suggestions"])
            s[key]["n"] += 1
            s[key]["r1"] += rank == 1
            s[key]["r3"] += rank is not None and rank <= 3
            s[key]["r5"] += rank is not None
        if "injected" in w:
            inj = s["inj"]
            inj["n"] += 1
            inj["detected"] += res[w["q_bad_check"]]["match"] == "none"
            top = res[w["q_bad_suggest"]]["suggestions"]
            dict_ok = bool(top) and top[0]["headword"] == w["kanji"]
            inj["dict_fixed"] += dict_ok
            inj["rule_fixed"] += w["rule"] == w["kanji"]
            inj["either"] += dict_ok or w["rule"] == w["kanji"]
    for k in plan["kata"]:
        s["kata"]["n"] += 1
        s["kata"]["common"] += k["common"]
        caught = res[k["q_rule_check"]]["match"] == "none"
        top = res[k["q_rule_suggest"]]["suggestions"]
        restored = bool(top) and top[0]["headword"] == k["form"]
        s["kata"]["caught"] += caught
        s["kata"]["restored"] += restored
        if len(s["kata"]["examples"]) < 8 and k["common"]:
            s["kata"]["examples"].append(f'{k["form"]}【{k["reading"]}】→{k["rule"]}')
    return s


# ---------------------------------------------------------------- report

def pct(a: int, b: int) -> str:
    return f"{a}/{b} ({100 * a / b:.1f}%)" if b else "-"


def report(db: Path, out: dict, tb: dict, jl: dict | None, verbose: bool) -> None:
    info = out["info"]
    print(f"\n## {db.name}  (entries={info.get('entries')}, JMdict {info.get('jmdict_created')}, "
          f"{info.get('entry_count')} entries)\n")
    print("### 교재 59줄 (기준 해석기 + 사전 검사)\n")
    print("| 항목 | 결과 |\n|---|---|")
    for a in tb["a_cases"]:
        print(f"| (a) 표제어 없음 {a['where']} 읽기 {a['reading']} → 정답 {a['answer']} | "
              f"{a['rank'] or '없음'}순위 (상위 3: {' '.join(a['top3'])}); 품사 힌트({a['pos']}) "
              f"{a['rank_pos'] or '없음'}순위 ({' '.join(a['top3_pos'])}) |")
    print(f"| (b) 핵심 칸(표제어·읽기)이 틀린 줄 | {tb['core_wrong']} |")
    print(f"| (b) 그중 해석기가 이미 표시 | {tb['core_wrong_flagged_parser']} |")
    print(f"| (b) 그중 사전이 표시(빈 표제어 포함) | {tb['core_wrong_flagged_dict']} |")
    print(f"| (b) 사전이 새로 잡은 줄 | {tb['new_catches']} |")
    for c in tb["corrections"]:
        print(f"| (b) 규칙 보정 {c['where']} `{c['raw']}`→`{c['rule']}` | 보정 전 짝 {c['raw_check']}, "
              f"보정 후 짝 {c['rule_check']}, 사전만으로 1순위 `{c['dict_top']}` (정답 `{c['answer']}`) |")
    print(f"| (c) 맞는 줄 중 사전이 '없음'으로 표시(오탐) | {pct(tb['fp'], tb['correct'])} "
          f"{' '.join(tb['fp_rows'])} |")
    kinds = ", ".join(f"{k} {v}" for k, v in sorted(tb["match_kinds"].items()))
    print(f"| 짝 검사 결과 분포(읽기별) | {kinds} |")
    if verbose:
        print("\n```\n" + "\n".join(tb["details"]) + "\n```")
    if jl:
        print("\n### JLPT N5–N3 목록 (모의)\n")
        print("| 급 | 단어 | 사전에 없음 | 일치 방식 |\n|---|---:|---:|---|")
        for lv, d in jl["levels"].items():
            kinds = ", ".join(f"{k} {v}" for k, v in sorted(d["kinds"].items()))
            print(f"| {lv} | {d['n']} | {pct(d['none'], d['n'])} | {kinds} |")
        a, ap, inj, kata = jl["a"], jl["a_pos"], jl["inj"], jl["kata"]
        print(f"\n| 모의 측정 | 결과 |\n|---|---|")
        print(f"| (a′) 한자 단어의 표제어를 지우고 읽기로 제안: 1순위 | {pct(a['r1'], a['n'])} |")
        print(f"| (a′) 3순위 안 / 5순위 안 | {pct(a['r3'], a['n'])} / {pct(a['r5'], a['n'])} |")
        print(f"| (a′) 품사 힌트를 주면: 1순위 | {pct(ap['r1'], ap['n'])} |")
        print(f"| (a′) 품사 힌트를 주면: 3순위 안 / 5순위 안 | {pct(ap['r3'], ap['n'])} / {pct(ap['r5'], ap['n'])} |")
        print(f"| (b′) 헷갈리는 한자를 가타카나로 바꿔 넣은 단어 | {inj['n']} |")
        print(f"| (b′) 짝 검사가 오류로 잡음 | {pct(inj['detected'], inj['n'])} |")
        print(f"| (b′) 사전 제안 1순위가 원래 단어 | {pct(inj['dict_fixed'], inj['n'])} |")
        print(f"| (b′) 규칙 보정기가 원래 단어로 고침 | {pct(inj['rule_fixed'], inj['n'])} |")
        print(f"| (b′) 둘 중 하나라도 고침 | {pct(inj['either'], inj['n'])} |")
        print(f"| (b″) 가타카나+한자 실제 단어를 규칙이 바꿔 버림 | {kata['n']} (상용 {kata['common']}) |")
        print(f"| (b″) 그 결과를 짝 검사가 잡음 / 제안이 원래 단어로 되돌림 | "
              f"{pct(kata['caught'], kata['n'])} / {pct(kata['restored'], kata['n'])} |")
        if kata["examples"]:
            print(f"| (b″) 예(상용) | {', '.join(kata['examples'])} |")
        if verbose:
            for lv, d in jl["levels"].items():
                if d["missing"]:
                    print(f"\n{lv} 사전에 없음: {' '.join(d['missing'][:60])}")
    micros, counts = out["micros"], out["counts"]
    timing = ", ".join(f"{op} {micros[op] / counts[op]:.0f}µs×{counts[op]}" for op in sorted(counts))
    print(f"\n호출당 평균 시간(JIT, 같은 프로세스): {timing}")


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--db", type=Path, action="append", help="dictionary DB (repeatable)")
    ap.add_argument("--prototype", type=Path, help="folder with parse_eval.py")
    ap.add_argument("--truth", type=Path, help="ground_truth.json (default: the one the reference parser reads)")
    ap.add_argument("--fetch-jlpt", action="store_true", help="download the JLPT lists into .cache/jlpt")
    ap.add_argument("--no-jlpt", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    a, _ = ap.parse_known_args(argv)  # parse_eval reads --fixtures / --verbose from sys.argv itself

    dbs = a.db or DEFAULT_DBS
    for db in dbs:
        if not db.exists():
            sys.exit(f"{db} not found; build it with tools/dict/build_jmdict_db.py --matrix")
    prototype = find_prototype(a.prototype)
    pe, original_correct = load_parser(prototype)
    truth = a.truth or getattr(pe, "GT", None) or pe.DATA / "ground_truth.json"
    if not truth.exists():
        sys.exit(f"{truth} not found: the recorded textbook pages are local only (set SHIORI_PRIVATE_DIR)")
    pages_dir = Path(getattr(pe, "FIXTURES", None) or pe.DATA)
    if truth.resolve().parent != pages_dir.resolve():
        print(f"note: answers from {truth}, pages from {pages_dir} (pass --data/--fixtures for the same set)",
              file=sys.stderr)
    rows = textbook_rows(pe, truth)
    words = [] if a.no_jlpt else jlpt_words(a.fetch_jlpt)
    # The simulated cases (real katakana+kanji words, POS of the JLPT entries) come from one
    # full DB so that every --db is measured on the same cases, whatever the argument order.
    case_db = next((db for db in dbs if db_entries(db) == "all"), dbs[0])
    kata_forms = katakana_kanji_forms(case_db) if words else []
    pos = entry_pos(case_db, [w["seq"] for w in words]) if words else {}

    print(f"기준 해석기: {prototype / 'parse_eval.py'}  정답: {truth}  모의 사례 DB: {case_db.name}")
    for db in dbs:
        batch = Batch()
        plan_textbook(rows, batch)
        plan = plan_jlpt(words, kata_forms, original_correct, batch, pos) if words else None
        out = batch.run(db)
        tb = score_textbook(rows, out["results"], a.verbose)
        jl = score_jlpt(plan, out["results"]) if plan else None
        report(db, out, tb, jl, a.verbose)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
