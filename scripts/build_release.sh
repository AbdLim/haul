#!/bin/sh
# Builds Haul for release: analysis, every test, then `flutter build macos
# --release`. It stops at the first failure and exits non-zero, so a broken
# build never produces an app.
#
#   scripts/build_release.sh
#
# The extension's node tests need Node 20 or newer. Set HAUL_SKIP_EXTENSION=1
# to leave them out (for a Mac without Node); the script says so when it does.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
step() { printf '\n==> %s\n' "$*"; }

step "Engine: analyze"
(cd "$root/packages/download_engine" && dart pub get >/dev/null && dart analyze --fatal-infos)

step "Engine: tests"
(cd "$root/packages/download_engine" && dart test)

step "App: analyze"
(cd "$root/app" && flutter pub get >/dev/null && flutter analyze)

step "App: tests"
(cd "$root/app" && flutter test)

if [ "${HAUL_SKIP_EXTENSION:-}" = "1" ]; then
  step "Extension: tests SKIPPED (HAUL_SKIP_EXTENSION=1)"
elif command -v node >/dev/null 2>&1; then
  step "Extension: tests"
  (cd "$root/extension" && node --test --test-concurrency=1 test)
else
  echo "Node is not installed, so the extension's tests cannot run." >&2
  echo "Install Node 20+, or set HAUL_SKIP_EXTENSION=1 to leave them out." >&2
  exit 1
fi

step "App: release build"
(cd "$root/app" && flutter build macos --release)

app="$root/app/build/macos/Build/Products/Release/Haul.app"
[ -d "$app" ] || { echo "The build finished but $app is missing." >&2; exit 1; }

# A build that cannot start is not a build. Start it, make sure it is still
# running a few seconds later, and stop it. (HAUL_SKIP_LAUNCH=1 skips this on a
# machine with no window server, such as CI.)
if [ "${HAUL_SKIP_LAUNCH:-}" = "1" ]; then
  step "Launch check SKIPPED (HAUL_SKIP_LAUNCH=1)"
else
  step "App: launch check"
  log=$(mktemp)
  "$app/Contents/MacOS/Haul" >"$log" 2>&1 &
  pid=$!
  sleep 6
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "Haul exited within 6 seconds of starting:" >&2
    head -c 2000 "$log" >&2
    rm -f "$log"
    exit 1
  fi
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  rm -f "$log"
fi

step "Done"
echo "$app"
