#!/usr/bin/env python3
"""Turn the result JSON files into the tables and numbers used in README.md, and
write a local listening page next to the WAV files.

usage (from research/tts):
  .cache/venv/bin/python tools/make_report.py --results .cache/results \
      --audio-dir ../../.private/tts/wav --out .cache/results/report.md
"""
from __future__ import annotations

import argparse
import html
import json
import sys
import unicodedata
from collections import Counter
from pathlib import Path

import accent
import compare
import engine_vv
import pitch

GROUP_ORDER = ("はし", "あめ", "かき", "かみ", "さけ")


def load(results: Path, name: str) -> dict:
    return json.loads((results / f"{name}.json").read_text(encoding="utf-8"))


def expected_patterns(row: dict) -> list[str]:
    n = accent.count_morae(row["reading"])
    return [accent.pattern_for(a, n) for a in row["expected"]]


def long_marks_to_vowels(kana: str) -> str:
    """キョーガ -> キョオガ, the way VOICEVOX writes long vowels."""
    vowels = {"A": "ア", "I": "イ", "U": "ウ", "E": "エ", "O": "オ"}
    out = ""
    for ch in kana:
        if ch == "ー" and out:
            ch = vowels.get(unicodedata.name(out[-1], "")[-1:], ch)
        out += ch
    return out


def reading_ok(row: dict, phrases: list[dict]) -> bool:
    want = "".join(engine_vv.pron_kana(row["reading"])) + "ガ"
    return len(phrases) == 1 and long_marks_to_vowels(phrases[0]["kana"]) == want


def field_verdict(row: dict, phrases: list[dict]) -> str:
    if not phrases:
        return compare.MISSING
    if not reading_ok(row, phrases):
        return compare.MISMATCH
    return compare.judge(row["expected"], [phrases[0]["nucleus"]])


def pitch_ok(row: dict, phrases: list[dict]) -> bool:
    if len(phrases) != 1:
        return False
    obs = phrases[0]["pitch_pattern"]
    return any(accent.patterns_match(e, obs, phrases[0]["heavy_start"])
               for e in expected_patterns(row))


def fmt_rate(pair: tuple[int, int]) -> str:
    a, b = pair
    return f"{a}/{b} ({100 * a / b:.0f}%)" if b else "0/0"


def fmt_field(phrases: list[dict], row: dict) -> str:
    if not phrases:
        return "-"
    txt = " ".join(f"{p['kana']}:{p['nucleus']}" for p in phrases)
    return txt if reading_ok(row, phrases) else f"{txt} (읽기 다름)"


def lag_class(phrases: list[dict]) -> str:
    p = phrases[0]
    got = pitch.decode_nucleus(p["pitches"])
    want = p["nucleus"]
    if got == want:
        return "same"
    if want and got == want + 1:
        return "+1"
    return "other"


def first_gap(pitches: list[float]) -> float:
    filled = pitch.interpolate_unvoiced(pitches)
    return max(filled) - filled[0]


def last_step(pitches: list[float]) -> float:
    filled = pitch.interpolate_unvoiced(pitches)
    return filled[-1] - filled[-2]


def contrast_checks(rows: list[dict], key: str) -> list[tuple[str, bool]]:
    """Order checks inside each minimal set, robust to where the peak lands:
    (a) a type-1 word starts closer to its peak than a non-type-1 word,
    (b) a flat word ends higher (particle relative to mora 2) than a type-2 word."""
    out = []
    groups: dict[str, list[dict]] = {}
    for r in rows:
        if r["reading"] in GROUP_ORDER:
            groups.setdefault(r["reading"], []).append(r)
    for reading in GROUP_ORDER:
        members = groups.get(reading, [])
        for a in members:
            for b in members:
                pa, pb = a[key][0]["pitches"], b[key][0]["pitches"]
                if a["expected"] == [1] and b["expected"] != [1]:
                    out.append((f"{a['surface']}(1) < {b['surface']}: 첫 박~최고점 차이",
                                first_gap(pa) < first_gap(pb)))
                if a["expected"] == [0] and b["expected"] == [2]:
                    out.append((f"{a['surface']}(0) > {b['surface']}(2): 조사 박 상승",
                                last_step(pa) > last_step(pb)))
    return out


def word_section(data: dict, vv: dict, kyoko: dict, oj: dict) -> tuple[list[str], dict]:
    lines = ["| 표기 | 읽기 | 정답 | UniDic 3.1 | UniDic-lite | Kanjium | VV 기본 | VV 지정(가나) | VV 지정(사전) "
             "| VV pitch 기본 | VV pitch 지정 | Kyoko 대략 | pyopenjtalk |",
             "|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    tallies = {k: [] for k in ("unidic", "unidic_lite", "kanjium", "vv_base", "vv_kana",
                                "vv_udict", "openjtalk")}
    pitch_counts = Counter()
    kyoko_strict = []
    kyoko_loose = []
    for d, v, k, o in zip(data["rows"], vv["words"], kyoko["words"], oj["words"], strict=True):
        if len({(x["surface"], x["reading"]) for x in (d, v, k, o)}) != 1:
            raise ValueError(f"result files are not in the same word order at {d['surface']}")
        exp = d["expected"]
        u = d["unidic"]["values"]
        ul = d["unidic_lite"]["values"]
        kj = d["kanjium"]
        tallies["unidic"].append(compare.judge(exp, u))
        tallies["unidic_lite"].append(compare.judge(exp, ul))
        tallies["kanjium"].append(compare.judge(exp, kj))
        tallies["vv_base"].append(field_verdict(v, v["base"]))
        tallies["vv_kana"].append(field_verdict(v, v["kana"]))
        tallies["vv_udict"].append(field_verdict(v, v["udict"]))
        tallies["openjtalk"].append(field_verdict(v, o["phrases"]) if o["phrases"] else compare.MISSING)
        for case in ("base", "kana", "udict"):
            pitch_counts[(case, "main")] += pitch_ok(v, v[case])
            for ph in v.get(f"{case}_styles", {}).values():
                pitch_counts[(case, "styles")] += pitch_ok(v, ph)
                pitch_counts[(case, "styles_n")] += 1
        exp_p = expected_patterns(k)
        kyoko_strict.append(any(accent.patterns_match(e, k["pattern"]) for e in exp_p))
        kyoko_loose.append(any(accent.patterns_match(e[:-1], k["pattern"][:-1]) for e in exp_p))
        oj_txt = " ".join(f"{p['kana']}:{p['nucleus']}" for p in o["phrases"])
        lines.append("| " + " | ".join([
            d["surface"], d["reading"], "/".join(map(str, exp)),
            ",".join(map(str, u)) or "-", ",".join(map(str, ul)) or "-",
            ",".join(map(str, kj)) or "-",
            fmt_field(v["base"], v), fmt_field(v["kana"], v), fmt_field(v["udict"], v),
            " ".join(p["pitch_pattern"] for p in v["base"]),
            " ".join(p["pitch_pattern"] for p in v["kana"]),
            k["pattern"], oj_txt,
        ]) + " |")
    lines.append("")
    lines.append("정답 패턴(조사 포함): " + ", ".join(
        f"{d['surface']}={'/'.join(expected_patterns(d))}" for d in data["rows"]))
    summary = {
        "tallies": {k: compare.tally(v) for k, v in tallies.items()},
        "pitch": pitch_counts,
        "n": len(data["rows"]),
        "kyoko_strict": sum(kyoko_strict),
        "kyoko_loose": sum(kyoko_loose),
    }
    return lines, summary


def lag_section(vv: dict) -> list[str]:
    out = ["| 경우 | 지정한 핵과 같음 | 한 박 늦음(+1) | 그 밖 |", "|---|---|---|---|"]
    for case in ("kana", "udict", "base"):
        c = Counter()
        for r in vv["words"]:
            for ph in r.get(f"{case}_styles", {"main": r[case]}).values():
                if len(ph) == 1:
                    c[lag_class(ph)] += 1
        total = sum(c.values())
        label = "주 음성" if case == "udict" else "3 음성"
        out.append(f"| {case} ({label}) | {fmt_rate((c['same'], total))} | {fmt_rate((c['+1'], total))} "
                   f"| {fmt_rate((c['other'], total))} |")
    by_type = Counter()
    for r in vv["words"]:
        for ph in r["kana_styles"].values():
            p = ph[0]
            word_morae = accent.count_morae(r["reading"])
            if p["nucleus"] == 0:
                kind = "평판"
            elif p["nucleus"] == 1:
                kind = "두고"
            else:
                kind = "미고" if p["nucleus"] == word_morae else "중고"
            by_type[(kind, lag_class(ph))] += 1
    out.append("")
    out.append("| 형(지정, 가나 3 음성) | 같음 | +1 | 그 밖 |")
    out.append("|---|---|---|---|")
    for kind in ("평판", "두고", "중고", "미고"):
        out.append(f"| {kind} | {by_type[(kind, 'same')]} | {by_type[(kind, '+1')]} | {by_type[(kind, 'other')]} |")
    return out


def audio_section(vv: dict) -> list[str]:
    same_patterns = 0
    total = 0
    agree = 0
    steps = 0
    for r in vv["words"] + vv["sentences"]:
        for case in ("base", "kana", "edit"):
            a = r.get(f"{case}_audio")
            if not a:
                continue
            q = [p["pitch_pattern"] for p in r[case]]
            for qp, ap in zip(q, a["f0_patterns"], strict=True):
                total += 1
                same_patterns += qp == ap
            for dq, da in a["steps"]:
                if abs(dq) >= pitch.DEFAULT_FALL_THRESHOLD:
                    steps += 1
                    agree += (dq > 0) == (da > 0)
    return [f"- 쿼리 pitch 패턴 = 소리 F0 패턴(같은 판독 규칙): {fmt_rate((same_patterns, total))}",
            f"- 모라 사이 오르내림 방향 일치(쿼리 변화 0.05 이상인 곳만): {fmt_rate((agree, steps))}"]


def sentence_section(vv: dict, oj: dict) -> tuple[list[str], dict]:
    lines = ["| 문장 | 기대 | VV 기본 | VV 지정(사전) | VV 지정(구 편집) | pitch(기본) | pitch(구 편집) |",
             "|---|---|---|---|---|---|---|"]
    c = Counter()
    for r in vv["sentences"]:
        exp = r["expected"]
        exp_txt = " ".join(f"{k}:{n}" for k, n in exp)
        cells = []
        for case in ("base", "udict", "edit"):
            ph = r.get(case)
            if not ph:
                cells.append("구 나눔 다름 → 편집 안 함")
                continue
            aligned = [p["morae"] for p in ph] == [accent.count_morae(k) for k, _ in exp]
            txt = " ".join(f"{p['kana']}:{p['nucleus']}" for p in ph)
            if aligned:
                ok = [p["nucleus"] == n for p, (_, n) in zip(ph, exp, strict=True)]
                c[(case, "phr_ok")] += sum(ok)
                c[(case, "phr_n")] += len(ok)
                c[(case, "sent_ok")] += all(ok)
                bad = [p["kana"] for p, good in zip(ph, ok, strict=True) if not good]
                if bad:
                    txt += " (틀림: " + ", ".join(bad) + ")"
            else:
                txt += " (구 나눔 다름)"
                c[(case, "phr_n")] += len(exp)
            c[(case, "sent_n")] += 1
            cells.append(txt)
        pitch_cells = []
        for case in ("base", "edit"):
            ph = r.get(case)
            if not ph:
                pitch_cells.append("-")
                continue
            pats = [p["pitch_pattern"] for p in ph]
            if [p["morae"] for p in ph] == [accent.count_morae(k) for k, _ in exp]:
                ok = [accent.patterns_match(accent.phrase_pattern(n, accent.count_morae(k)), pp, p["heavy_start"])
                      for (k, n), pp, p in zip(exp, pats, ph, strict=True)]
                c[(f"pitch_{case}", "ok")] += sum(ok)
                c[(f"pitch_{case}", "n")] += len(ok)
            pitch_cells.append(" ".join(pats))
        lines.append("| " + " | ".join([r["text"], exp_txt, *cells, *pitch_cells]) + " |")
    same_oj = sum([p["nucleus"] for p in o["phrases"]] == [p["nucleus"] for p in v["base"]]
                  for o, v in zip(oj["sentences"], vv["sentences"], strict=True))
    c[("oj_same", "n")] = same_oj
    return lines, c


def timing_section(vv: dict, vv1: dict | None) -> list[str]:
    def stats(rows, key):
        vals = [r[key]["synth_sec"] for r in rows if r.get(key)]
        aud = [r[key]["audio_seconds"] for r in rows if r.get(key)]
        return sum(vals) / len(vals), sum(vals) / sum(aud)

    out = []
    for label, data in (("자동 스레드", vv), ("1 스레드", vv1)):
        if not data:
            continue
        w_avg, w_rtf = stats(data["words"], "kana_audio")
        s_avg, s_rtf = stats(data["sentences"], "base_audio")
        q = [r["query_sec"] for r in data["words"]]
        out.append(f"| {label} | {data['load_sec']:.2f}s | {1000 * sum(q) / len(q):.1f}ms "
                   f"| {1000 * w_avg:.0f}ms (RTF {w_rtf:.2f}) | {1000 * s_avg:.0f}ms (RTF {s_rtf:.2f}) |")
    return ["| 조건 | 모델 읽기 | 쿼리 1개(단어) | 합성(단어+が) | 합성(예문) |", "|---|---|---|---|---|", *out]


def listening_page(vv: dict, kyoko: dict, audio_dir: Path) -> None:
    rows = []
    for v, k in zip(vv["words"], kyoko["words"], strict=True):
        exp = "/".join(map(str, v["expected"]))
        cells = [html.escape(v["surface"]), html.escape(v["reading"]), exp]
        for name in (v["base_audio"]["wav"], v["kana_audio"]["wav"], k["wav"]):
            cells.append(f'<audio controls preload="none" src="{html.escape(name)}"></audio>')
        rows.append("<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>")
    for s in vv["sentences"]:
        exp = " ".join(f"{a}:{n}" for a, n in s["expected"])
        cells = [html.escape(s["text"]), html.escape(exp), ""]
        for key in ("base_audio", "edit_audio"):
            a = s.get(key)
            cells.append(f'<audio controls preload="none" src="{html.escape(a["wav"])}"></audio>' if a else "-")
        cells.append("-")
        rows.append("<tr>" + "".join(f"<td>{c}</td>" for c in cells) + "</tr>")
    page = f"""<!doctype html><html lang="ko"><meta charset="utf-8"><title>악센트 듣기</title>
<style>body{{font-family:sans-serif;margin:16px}}td,th{{border-bottom:1px solid #ccc;padding:4px 8px}}</style>
<h1>악센트 실험 소리 (로컬 전용)</h1>
<p>숫자는 도쿄 악센트 핵 위치(0=평판). 단어는 「단어+が」로 읽었습니다.
VOICEVOX 음성: VOICEVOX:四国めたん (ノーマル). 비교용 macOS {html.escape(kyoko['voice'])}.</p>
<table><tr><th>표기/문장</th><th>읽기/기대</th><th>정답</th>
<th>VOICEVOX 기본</th><th>VOICEVOX 지정</th><th>{html.escape(kyoko['voice'])}</th></tr>
{''.join(rows)}</table></html>"""
    (audio_dir / "index.html").write_text(page, encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", type=Path, required=True)
    ap.add_argument("--audio-dir", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    data = load(args.results, "data")
    vv = load(args.results, "voicevox")
    kyoko = load(args.results, "kyoko")
    oj = load(args.results, "openjtalk")
    vv1_path = args.results / "voicevox_1thread.json"
    vv1 = json.loads(vv1_path.read_text()) if vv1_path.exists() else None

    out = ["# 결과 (자동 생성)", "", "## 단어", ""]
    word_lines, s = word_section(data, vv, kyoko, oj)
    out += word_lines + ["", "### 일치율", ""]
    for key, label in (("unidic", "UniDic 3.1.0"), ("unidic_lite", "UniDic-lite 2.1.2"),
                       ("kanjium", "Kanjium"), ("vv_base", "VOICEVOX 기본(악센트 값)"),
                       ("vv_kana", "VOICEVOX 지정·가나(악센트 값)"),
                       ("vv_udict", "VOICEVOX 지정·사용자 사전(악센트 값)"),
                       ("openjtalk", "pyopenjtalk(악센트 값)")):
        t = s["tallies"][key]
        out.append(f"- {label}: 일치 {fmt_rate(compare.match_rate(t))} · 값 있음 {fmt_rate(compare.coverage(t))} "
                   f"· {dict(t)}")
    n = s["n"]
    p = s["pitch"]
    out += [
        f"- VOICEVOX pitch 엄격 판독, 기본: {fmt_rate((p[('base', 'main')], n))} "
        f"· 3 음성 {fmt_rate((p[('base', 'styles')], p[('base', 'styles_n')]))}",
        f"- VOICEVOX pitch 엄격 판독, 지정(가나): {fmt_rate((p[('kana', 'main')], n))} "
        f"· 3 음성 {fmt_rate((p[('kana', 'styles')], p[('kana', 'styles_n')]))}",
        f"- VOICEVOX pitch 엄격 판독, 지정(사전): {fmt_rate((p[('udict', 'main')], n))}",
        f"- Kyoko 대략(엄격): {fmt_rate((s['kyoko_strict'], n))} · 마지막 박 제외: {fmt_rate((s['kyoko_loose'], n))}",
        "", "## pitch 판독의 한 박 늦음", "", *lag_section(vv), "",
        "## 최소쌍 대비(지정·가나, 3 음성)", "",
    ]
    checks = []
    for st in vv["styles"]:
        rows = [dict(r, kana_st=r["kana_styles"][str(st)]) for r in vv["words"]]
        checks += [(f"{st}: {name}", ok) for name, ok in contrast_checks(rows, "kana_st")]
    out.append(f"- 통과 {fmt_rate((sum(ok for _, ok in checks), len(checks)))}")
    out += [f"  - 실패: {name}" for name, ok in checks if not ok]
    kyoko_rows = [dict(r, ky=[{"pitches": r["f0"]}]) for r in kyoko["words"]]
    kchecks = contrast_checks(kyoko_rows, "ky")
    out.append(f"- Kyoko 같은 검사: {fmt_rate((sum(ok for _, ok in kchecks), len(kchecks)))}")
    same_f0 = [(a["surface"], b["surface"]) for i, a in enumerate(kyoko["words"])
               for b in kyoko["words"][i + 1:] if a["f0"] == b["f0"] and a["reading"] == b["reading"]]
    out.append(f"- Kyoko에서 F0가 완전히 같은 쌍: {same_f0}")
    out += ["", "## 소리 F0 재측정", "", *audio_section(vv), "", "## 예문", ""]
    sent_lines, c = sentence_section(vv, oj)
    out += sent_lines + [""]
    for case, label in (("base", "기본"), ("udict", "지정(사전)"), ("edit", "지정(구 편집)")):
        out.append(f"- {label}: 악센트구 {fmt_rate((c[(case, 'phr_ok')], c[(case, 'phr_n')]))}, "
                   f"문장 전체 {fmt_rate((c[(case, 'sent_ok')], c[(case, 'sent_n')]))}")
    out.append("- pitch 엄격 판독(구 나눔이 맞는 문장): "
               f"기본 {fmt_rate((c[('pitch_base', 'ok')], c[('pitch_base', 'n')]))}, "
               f"구 편집 {fmt_rate((c[('pitch_edit', 'ok')], c[('pitch_edit', 'n')]))}")
    out.append(f"- pyopenjtalk와 VOICEVOX 기본의 문장별 핵 일치: {c[('oj_same', 'n')]}/{len(vv['sentences'])}")
    out += ["", "## 속도", "", *timing_section(vv, vv1)]
    args.out.write_text("\n".join(out) + "\n", encoding="utf-8")
    listening_page(vv, kyoko, args.audio_dir)
    print(f"wrote {args.out} and {args.audio_dir / 'index.html'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
