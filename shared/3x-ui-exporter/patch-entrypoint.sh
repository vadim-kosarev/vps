#!/bin/sh
# Entrypoint wrapper for m4l3vich/3x-ui-prometheus-exporter.
# Patches xui.js so fetchCsrfToken() tolerates older 3x-ui versions
# that lack the /csrf-token endpoint (< v3.x).
# The patch is idempotent — safe to run on every container start.

XUI_JS="/app/build/xui.js"

if [ ! -f "$XUI_JS" ]; then
  echo "[patch-entrypoint] WARNING: $XUI_JS not found, skipping patch"
elif grep -q 'const csrfToken = yield fetchCsrfToken()' "$XUI_JS"; then
  sed -i \
    's/const csrfToken = yield fetchCsrfToken()/let csrfToken = ""; try { csrfToken = yield fetchCsrfToken(); } catch(_e) { console.error("CSRF not available, proceeding without it"); }/' \
    "$XUI_JS"
  echo "[patch-entrypoint] patched fetchCsrfToken() fallback in xui.js"
elif grep -q 'try { csrfToken = yield fetchCsrfToken()' "$XUI_JS"; then
  echo "[patch-entrypoint] already patched, skipping"
else
  echo "[patch-entrypoint] WARNING: fetchCsrfToken() pattern not found — exporter code may have changed, patch not applied"
fi

exec docker-entrypoint.sh "$@"
