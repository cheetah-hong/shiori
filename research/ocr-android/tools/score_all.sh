#!/usr/bin/env bash
# Raw ML Kit dumps -> fixtures (line / element / segment) -> every score file, all in the data folder.
#
# usage: tools/score_all.sh
#   data folder: $SHIORI_PRIVATE_DIR/textbook/ocr-android (raw/ in, fixtures*/ variants/ scores*.txt out)
#   Apple Vision fixtures and ground truth: $SHIORI_PRIVATE_DIR/textbook/vocab_n5n3
#   SHIORI_PRIVATE_DIR defaults to <repo>/.private: OCR of textbook pages never enters the repository.
set -euo pipefail

HERE=$(cd "$(dirname "$0")/.." && pwd)
PRIVATE=${SHIORI_PRIVATE_DIR:-$HERE/../../.private}
DATA="$PRIVATE/textbook/ocr-android"
VISION="$PRIVATE/textbook/vocab_n5n3"
PE="$HERE/../ocr/prototype/parse_eval.py"
GT="$VISION/ground_truth.json"
[[ -f "$PE" ]] || { echo "reference parser not found at $PE" >&2; exit 1; }
[[ -f "$GT" && -d "$DATA/raw" ]] || { echo "textbook data not found under $PRIVATE/textbook (set SHIORI_PRIVATE_DIR)" >&2; exit 1; }

# 0) unit tests of the helpers (geometry, segments, rules)
(cd "$HERE" && python3 -m unittest discover -s tools -p 'test_*.py' -q)

cd "$DATA"
python3 "$HERE/tools/raw_to_fixture.py" upright-bitmap line fixtures
python3 "$HERE/tools/raw_to_fixture.py" upright-bitmap element fixtures_element >/dev/null
python3 "$HERE/tools/raw_to_fixture.py" upright-bitmap segment fixtures_segment >/dev/null
# input-path variants (rotation handling): same pages, different decode/rotation path on the device
VARIANTS=(upright-filepath orig-filepath orig-bitmap-exif)
for run in "${VARIANTS[@]}"; do
  python3 "$HERE/tools/raw_to_fixture.py" "$run" line "variants/$run" >/dev/null
  python3 "$HERE/tools/raw_to_fixture.py" "$run" segment "variants/$run-autorot" --auto-rotate >/dev/null
done

# 1) reference parser, unchanged (the "원래 점수")
python3 "$PE" --fixtures fixtures --gt "$GT" --verbose > scores.txt
python3 "$PE" --fixtures fixtures_element --gt "$GT" --verbose > scores_element.txt
python3 "$PE" --fixtures fixtures_segment --gt "$GT" --verbose > scores_segment.txt

# 2) ML Kit corrections (the "보정 후 점수"), plus the same rules on the Vision fixtures (must not get worse)
M=(python3 "$HERE/parse_eval_mlkit.py" --gt "$GT" --strict)
"${M[@]}" --fixtures fixtures --verbose > scores_mlkit.txt
"${M[@]}" --fixtures fixtures_segment --verbose > scores_mlkit_segment.txt
"${M[@]}" --fixtures fixtures_element --verbose > scores_mlkit_element.txt
"${M[@]}" --fixtures "$VISION" --verbose > scores_mlkit_on_vision.txt
# the reference result again, with the strict silent-error count the reference does not print
"${M[@]}" --fixtures fixtures --off all > scores_rules_off_strict.txt
{
  echo "# leave-one-out and cumulative ablation of parse_eval_mlkit.py rules"
  echo "## ML Kit line fixtures";          "${M[@]}" --fixtures fixtures --ablation
  echo; echo "## ML Kit segment fixtures"; "${M[@]}" --fixtures fixtures_segment --ablation
  echo; echo "## Apple Vision fixtures";   "${M[@]}" --fixtures "$VISION" --ablation
} > ablation.txt

# 3) with every rule off the variant parser must reproduce the reference output exactly
for fx in fixtures fixtures_segment fixtures_element "$VISION"; do
  diff <(python3 "$PE" --fixtures "$fx" --gt "$GT" --verbose) <(python3 "$HERE/parse_eval_mlkit.py" --gt "$GT" --fixtures "$fx" --verbose --off all) >/dev/null \
    || { echo "rules-off output differs from the reference on $fx" >&2; exit 1; }
done

total() { grep '^TOTAL' "$1" | sed 's/TOTAL  //'; }
strict() { grep '^strict' "$1" | sed 's/.*: /strict_silent=/' || echo "strict_silent=-"; }
{
  echo "# rotation/input-path variants. ref = reference parser on Line fixtures, mlkit = ML Kit rules"
  echo "# autorot = segment fixtures turned upright from the median Line.angle (tools/raw_to_fixture.py --auto-rotate)"
  row() { printf '%-34s %s  %s\n' "$1" "$(total "$2")" "$(strict "$2")"; }
  for run in "${VARIANTS[@]}"; do
    python3 "$PE" --fixtures "variants/$run" --gt "$GT" > "variants/$run/scores.txt"
    "${M[@]}" --fixtures "variants/$run" > "variants/$run/scores_mlkit.txt"
    "${M[@]}" --fixtures "variants/$run-autorot" --verbose > "variants/$run-autorot/scores_mlkit.txt"
    row "$run ref" "variants/$run/scores.txt"
    row "$run mlkit" "variants/$run/scores_mlkit.txt"
    row "$run-autorot mlkit" "variants/$run-autorot/scores_mlkit.txt"
  done
  row "upright-bitmap segment mlkit" scores_mlkit_segment.txt
} > variants/summary.txt

python3 "$HERE/tools/compare_engines.py" --vision "$VISION" --mlkit fixtures --gt "$GT" --raw raw > compare.txt
for f in scores.txt scores_mlkit.txt scores_mlkit_segment.txt scores_mlkit_element.txt scores_mlkit_on_vision.txt; do
  printf '%-28s %s\n' "$f" "$(total "$f")"
done
