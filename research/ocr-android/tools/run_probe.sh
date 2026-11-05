#!/usr/bin/env bash
# Build the ML Kit probe, run it on a booted emulator, pull the raw dumps into <data>/raw/<dir>-<mode>/.
# <data> = $SHIORI_PRIVATE_DIR/textbook/ocr-android (default <repo>/.private/...): textbook pages stay out of git.
#
# usage: tools/run_probe.sh <dir> <mode> [parallel]
#   dir:  upright | orig | crop     (folders under <data>/work/images/, made by tools/prepare_images.py)
#   mode: bitmap | bitmap-exif | filepath
#         bitmap: fromBitmap(rotation 0)   bitmap-exif: fromBitmap(EXIF degrees)   filepath: InputImage.fromFilePath
#   parallel: pass "parallel" to also time both recognizers submitted at once
# Needs one running emulator. Uses $ANDROID_HOME (default ~/Library/Android/sdk)/platform-tools/adb; does not touch PATH.
# Fails when the probe reports a failure (am instrument itself always exits 0).
set -euo pipefail

DIR=${1:?dir (upright|orig)}
MODE=${2:?mode (bitmap|bitmap-exif|filepath)}
PARALLEL=$([[ "${3:-}" == "parallel" ]] && echo true || echo false)

HERE=$(cd "$(dirname "$0")/.." && pwd)
DATA="${SHIORI_PRIVATE_DIR:-$HERE/../../.private}/textbook/ocr-android"
SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}
ADB="$SDK/platform-tools/adb"
PKG=dev.nihongo.mlkitprobe
RUNNER=$PKG/.ProbeInstrumentation
DEV=/sdcard/Android/data/$PKG/files
APK="$HERE/mlkit_probe/app/build/outputs/apk/debug/app-debug.apk"
OUT="$DATA/raw/$DIR-$MODE"

[[ -x "$ADB" ]] || { echo "adb not found at $ADB (set ANDROID_HOME)" >&2; exit 1; }
[[ -d "$DATA/work/images/$DIR" ]] || { echo "missing $DATA/work/images/$DIR (run tools/prepare_images.py)" >&2; exit 1; }

# `am instrument -w` exits 0 even when the probe fails: with -r it prints INSTRUMENTATION_CODE (RESULT_OK = -1).
instrument() {
  local out
  out=$("$ADB" shell am instrument -w -r "$@" "$RUNNER")
  printf '%s\n' "$out"
  if ! grep -q 'INSTRUMENTATION_CODE: -1' <<<"$out" || grep -q 'PROBE FAILED' <<<"$out"; then
    echo "probe failed: am instrument $*" >&2
    exit 1
  fi
}

(cd "$HERE/mlkit_probe" && ./gradlew -q :app:assembleDebug)
"$ADB" install -r "$APK" >/dev/null

# Start from an empty input folder so images of an earlier run cannot slip in. The app then creates the folder
# itself: a folder made by `adb shell mkdir` is owned by shell and the app cannot read it.
"$ADB" shell rm -r "$DEV/in/$DIR" 2>/dev/null || true
instrument -e action prepare -e dir "$DIR"
"$ADB" push "$DATA/work/images/$DIR/." "$DEV/in/$DIR/" >/dev/null

# The probe clears its own output folder before writing.
instrument -e dir "$DIR" -e mode "$MODE" -e parallel "$PARALLEL"

mkdir -p "$OUT"
rm -f "$OUT"/*.raw.json "$OUT"/timing.json
"$ADB" pull "$DEV/out/$DIR-$MODE/." "$OUT/" >/dev/null
echo "pulled -> $OUT"
ls "$OUT"
