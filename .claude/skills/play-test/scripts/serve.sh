#!/usr/bin/env bash
# Build a Flutter project for the web and serve it locally.
# Usage: serve.sh <project-dir> [port]
# Prints the URL. Builds into a copy so the project's build/ is untouched.
set -euo pipefail
PROJ=$(cd "${1:?project dir}" && pwd)
PORT=${2:-8790}
FLUTTER=${FLUTTER:-$(command -v flutter || echo /opt/flutter/bin/flutter)}
OUT=${PLAYTEST_DIR:-${TMPDIR:-/tmp}/playtest}
mkdir -p "$OUT"
rm -rf "$OUT/src" && mkdir -p "$OUT/src"
tar -C "$PROJ" --exclude=./build --exclude=./.dart_tool --exclude=./.git -cf - . | tar -C "$OUT/src" -xf -
cd "$OUT/src"
# Mobile-only projects have no web/ folder; add one to the copy only.
if [ ! -f web/index.html ]; then
  "$FLUTTER" create . --platforms web --project-name "$(sed -n 's/^name: *//p' pubspec.yaml)" >/dev/null
fi
"$FLUTTER" pub get >/dev/null
# Local CanvasKit: CDNs are often blocked in sandboxes.
"$FLUTTER" build web --no-web-resources-cdn --pwa-strategy=none >"$OUT/build.log" 2>&1 \
  || { tail -30 "$OUT/build.log"; exit 1; }
# Serve in the background. A server already on this port from an earlier
# run serves the same directory, which was just rebuilt, so reuse it.
if ! python3 -c "import socket,sys; s=socket.socket(); sys.exit(s.connect_ex(('127.0.0.1',$PORT))==0)"; then
  echo "(reusing server on port $PORT)" >&2
else
  (cd build/web && setsid nohup python3 -m http.server "$PORT" </dev/null >/dev/null 2>&1 &)
fi
sleep 1
echo "http://localhost:$PORT/"
