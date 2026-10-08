#!/usr/bin/env bash
# Record the demo app on a booted simulator and extract 30 fps frames.
#
#   tools/record.sh <udid> <flash|dots> <naive|fixed> <out-dir> [path/to/Demo.app]
#
# Output: <out-dir>/<scenario>-<mode>.mov and <out-dir>/<scenario>-<mode>/0001.png ...
# Frames are scaled to 402 px wide, i.e. 1 px = 1 pt on a 6.3" iPhone, so the ROI
# coordinates in the README are in points.
set -euo pipefail

UDID=${1:?udid}; SCENARIO=${2:?flash|dots}; MODE=${3:?naive|fixed}; OUT=${4:?out dir}; APP=${5:-}
BUNDLE=com.alexeyhatkevich.iossimulatorvideoframeglitchdetector
RUN_SECONDS=$([ "$SCENARIO" = flash ] && echo 16 || echo 12)   # autorun starts after 2 s

mkdir -p "$OUT/$SCENARIO-$MODE"
MOV="$OUT/$SCENARIO-$MODE.mov"
rm -f "$MOV" "$OUT/$SCENARIO-$MODE"/*.png

[ -n "$APP" ] && xcrun simctl install "$UDID" "$APP"
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true

xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$MOV" 2>/dev/null &
REC=$!
sleep 1
xcrun simctl launch "$UDID" "$BUNDLE" -mode "$MODE" -scenario "$SCENARIO" -autorun 1 >/dev/null
sleep "$RUN_SECONDS"
xcrun simctl terminate "$UDID" "$BUNDLE" || true
kill -INT "$REC"; wait "$REC" 2>/dev/null || true

# Simulator video is variable frame rate; fps=30 resamples it to a constant 30 fps so
# that "N frames" means "N * 33 ms".
ffmpeg -loglevel error -y -i "$MOV" -vf "fps=30,scale=402:-2" "$OUT/$SCENARIO-$MODE/%04d.png"
echo "frames: $(ls "$OUT/$SCENARIO-$MODE" | wc -l | tr -d ' ') in $OUT/$SCENARIO-$MODE"
