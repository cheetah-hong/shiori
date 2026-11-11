#!/usr/bin/env python3
"""Write the local listening page for the voice survey.

  python3 make_page.py --candidates candidates.tsv --stats .cache/results/screen.json --out DIR

DIR holds samples/<candidate id>/<item id>.wav (make_vv_samples.py and the other engines'
sample makers); index.html is written there with relative links, so the folder can be
opened anywhere. Shortlisted candidates come first with every item; then every other
candidate; then every VOICEVOX talk style with its one screening sentence.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import voices

HERE = Path(__file__).resolve().parent
NO_SOUND = "—"
STYLE = """
:root{--bg:#fbfaf7;--fg:#1d1d1f;--muted:#6b6b70;--line:#e3e1db;--pick:#f1efe8}
@media (prefers-color-scheme:dark){:root{--bg:#18181a;--fg:#ececee;--muted:#a0a0a6;--line:#333336;--pick:#232326}}
body{background:var(--bg);color:var(--fg);font:15px/1.5 -apple-system,"Hiragino Sans","Apple SD Gothic Neo",sans-serif;margin:0 auto;max-width:1400px;padding:16px}
h1{font-size:22px}h2{font-size:18px;margin-top:32px}p,li{color:var(--muted)}
.wrap{overflow-x:auto}table{border-collapse:collapse;font-size:13px}
th,td{border-bottom:1px solid var(--line);padding:6px 8px;text-align:left;vertical-align:top}
th{position:sticky;top:0;background:var(--bg)}tr.pick td{background:var(--pick)}
audio{height:28px;width:150px}details{margin-top:24px}summary{cursor:pointer;font-weight:600}
"""


def audio_cell(out: Path, candidate_id: str, item_id: str) -> str:
    rel = voices.sample_path(candidate_id, item_id)
    return voices.audio_tag(rel) if (out / rel).is_file() else NO_SOUND


def candidate_rows(out: Path, candidates, items, by_id: dict) -> str:
    esc = voices.escape
    head = ["후보", "앱", "라이선스", "기기 크기 증가(MB)", "악센트", "음높이·빠르기", "메모"] + [
        f"{i.id} {i.text}" for i in items]
    rows = []
    for c in candidates:
        stats = by_id.get(c.id)
        numbers = (f"평균 {stats['mean_hz']}Hz · 퍼짐 {stats['sd_semitones']}반음 · {stats['morae_per_second']}모라/초"
                   if stats and stats.get("mean_hz") else "")
        cells = [f"<b>{esc(c.voice)}</b><br><small>{esc(c.engine)} · {esc(c.model)}</small>",
                 esc(c.app), esc(c.license), esc(c.added_mb if c.added_mb is not None else "?"),
                 esc(c.accent), esc(numbers), esc(c.note)]
        rows.append(cells + [audio_cell(out, c.id, i.id) for i in items])
    return voices.html_table(head, rows, ["pick" if c.shortlist else "" for c in candidates])


def screen_rows(out: Path, styles: list[dict]) -> str:
    esc = voices.escape
    head = ["vvm", "캐릭터", "스타일", "id", "평균 Hz", "퍼짐(반음)", "모라/초", "최소쌍 대비", "견본"]
    rows = []
    for s in styles:
        accent = s.get("accent")
        contrast = f"{accent['contrast_ok']}/{accent['contrasts']}" if accent else ""
        rows.append([esc(s["vvm"]), esc(s["speaker"]), esc(s["style"]), esc(s["style_id"]),
                     esc(s["mean_hz"]), esc(s["sd_semitones"]), esc(s["morae_per_second"]), esc(contrast),
                     audio_cell(out, s["id"], "screen")])
    return voices.html_table(head, rows)


def page(out: Path, candidates, items, stats: dict) -> str:
    by_id = {s["id"]: s for s in stats["styles"]}
    picked = [c for c in candidates if c.shortlist]
    others = [c for c in candidates if not c.shortlist]
    return f"""<!doctype html><html lang="ko"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>목소리 후보 견본</title>
<style>{STYLE}</style></head><body>
<h1>목소리 후보 견본</h1>
<p>같은 글을 후보마다 만들었습니다. 빠르기는 조사 당시 앱과 같은 0.85배(엔진이 지원하는 경우). 단어는 읽기와 악센트를 지정해 단독으로,
문장은 글 그대로 넣었습니다. 「최소쌍 대비」는 箸·橋·端 같은 단어에서 악센트형에 따라 높낮이가 정해진 방향으로 갈리는지 본 기계 검사(8개)입니다.
단어 단독에서는 橋(2)와 端(0)이 원래 같은 높낮이라 구별되지 않습니다(조사가 붙어야 갈립니다).</p>
<h2>1. 추린 후보 ({len(picked)}개, 첫 줄이 조사 당시 앱 목소리)</h2>
{candidate_rows(out, picked, items, by_id)}
<details><summary>2. 그 밖의 후보 ({len(others)}개, 전체 견본이 있는 것은 재생 가능)</summary>
{candidate_rows(out, others, items, by_id)}</details>
<details><summary>3. VOICEVOX 토크 스타일 전체 ({len(stats['styles'])}개) — 「{voices.escape(stats['screen_text'])}」 한 문장</summary>
{screen_rows(out, stats['styles'])}</details>
</body></html>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--candidates", type=Path, default=HERE / "candidates.tsv")
    parser.add_argument("--samples", type=Path, default=HERE / "samples.tsv")
    parser.add_argument("--stats", type=Path, required=True, help="make_vv_samples.py output")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    candidates = voices.read_candidates(args.candidates)
    items = voices.read_samples(args.samples)
    stats = json.loads(args.stats.read_text(encoding="utf-8"))
    target = args.out / "index.html"
    target.write_text(page(args.out, candidates, items, stats), encoding="utf-8")
    print(f"{target}: {sum(c.shortlist for c in candidates)} shortlisted of {len(candidates)}")


if __name__ == "__main__":
    main()
