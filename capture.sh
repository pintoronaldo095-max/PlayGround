#!/usr/bin/env bash
# Capture desktop + mobile screenshots of the running preview.
# Exit codes: 75 = temporary navigation/browser infrastructure failure,
#             1  = script or rendering defect.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

: "${RUNTIME_DIR:?RUNTIME_DIR must point at the worker runtime}"
: "${CAPTURE_URL:?CAPTURE_URL must be set}"
: "${CAPTURE_DIR:?CAPTURE_DIR must be set}"

# Time every external command: t <cmd> [args...]
t() {
  /usr/bin/time -p "$@"
}

# Capture evidence must never land inside the source tree.
PROJECT_REAL="$(cd "$PROJECT_DIR" && pwd -P)"
CAPTURE_PARENT="$CAPTURE_DIR"
t /usr/bin/mkdir -p "$CAPTURE_PARENT"
CAPTURE_REAL="$(cd "$CAPTURE_PARENT" && pwd -P)"
case "$CAPTURE_REAL/" in
  "$PROJECT_REAL"/*)
    echo "CAPTURE_DIR must be outside the project source tree: $CAPTURE_REAL" >&2
    exit 1
    ;;
esac

export CAPTURE_URL
export CAPTURE_DIR="$CAPTURE_REAL"

echo "[capture] url=$CAPTURE_URL dir=$CAPTURE_DIR"

t /usr/bin/rm -f "$CAPTURE_DIR/final-desktop.png" "$CAPTURE_DIR/final-mobile.png"

t node "$RUNTIME_DIR/scripts/default-capture.mjs"

# A capture run must produce both views; missing files are a script/rendering defect.
for name in final-desktop.png final-mobile.png; do
  if [[ ! -s "$CAPTURE_DIR/$name" ]]; then
    echo "missing or empty capture: $CAPTURE_DIR/$name" >&2
    exit 1
  fi
done

echo "[capture] wrote $(/usr/bin/stat -c '%n %s bytes' "$CAPTURE_DIR/final-desktop.png" "$CAPTURE_DIR/final-mobile.png" | /usr/bin/tr '\n' ' ')"
