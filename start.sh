#!/usr/bin/env bash
# Build (when needed) and serve the project in the foreground.
# Source and built output stay inside PROJECT_DIR; the worker directory only
# receives deployment metadata.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

PORT="${PORT:-3000}"
export PORT
export PROJECT_DIR

WEB_DIR="${OPENCODE_WEB_DIR:-/home/runner/work/_temp/omgithub-web}"
BUILD_DIR="$PROJECT_DIR/dist"

# Time every external command: t <cmd> [args...]
t() {
  /usr/bin/time -p "$@"
}

echo "[start] project=$PROJECT_DIR port=$PORT"

# ---- dependencies / build -------------------------------------------------
if [[ -f package.json ]]; then
  if [[ -f package-lock.json ]]; then
    t npm ci --no-audit --no-fund
  else
    t npm install --no-audit --no-fund
  fi
  # Build only when the project declares a build script.
  t npm run build --if-present
fi

# ---- resolve static output ------------------------------------------------
if [[ -f package.json && -f "$BUILD_DIR/index.html" ]]; then
  STATIC_DIR="$BUILD_DIR"
elif [[ -f "$PROJECT_DIR/index.html" ]]; then
  # Plain static project: assemble a real build directory inside the project.
  t /usr/bin/rm -rf "$BUILD_DIR"
  t /usr/bin/mkdir -p "$BUILD_DIR"
  for item in index.html favicon.ico favicon.svg robots.txt assets public static media; do
    if [[ -e "$PROJECT_DIR/$item" ]]; then
      t /usr/bin/cp -a "$PROJECT_DIR/$item" "$BUILD_DIR/"
    fi
  done
  STATIC_DIR="$BUILD_DIR"
else
  echo "[start] no index.html or supported package build output in $PROJECT_DIR" >&2
  exit 1
fi

if [[ ! -f "$STATIC_DIR/index.html" ]]; then
  echo "[start] static output missing index.html: $STATIC_DIR" >&2
  exit 1
fi
export STATIC_DIR

# ---- deployment metadata --------------------------------------------------
t /usr/bin/mkdir -p "$WEB_DIR"
t node -e '
  const fs = require("node:fs");
  const [web, project, directory] = process.argv.slice(1);
  fs.writeFileSync(
    web + "/deployment-output.json",
    JSON.stringify({ project, directory }) + "\n"
  );
' "$WEB_DIR" "$PROJECT_DIR" "$STATIC_DIR"

echo "[start] serving $STATIC_DIR"

# ---- foreground server ----------------------------------------------------
t node "$PROJECT_DIR/serve.mjs"
