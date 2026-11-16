#!/bin/sh
# Builds the extension for each browser.
#
#   ./build.sh                 build dist/chrome and dist/firefox
#   ./build.sh chrome          build one (or several: ./build.sh chrome firefox)
#   ./build.sh package         build both, then zip each for its store
#
# A target is the shared source plus that browser's manifest, copied as
# manifest.json. Nothing else (tests, notes, scripts) goes in. A package is
# that folder zipped with manifest.json at the top, named
# dist/haul-<browser>-<version>.zip.
set -eu

cd "$(dirname "$0")"

build() {
  target=$1
  manifest="manifest.$target.json"
  [ -f "$manifest" ] || { echo "No $manifest" >&2; exit 1; }
  out="dist/$target"
  rm -rf "$out"
  mkdir -p "$out"
  cp -R src/. "$out/"
  cp "$manifest" "$out/manifest.json"
  # Editors and Finder leave files behind; they must not ship.
  find "$out" -name '.DS_Store' -delete
  echo "Built $out"
}

package() {
  target=$1
  version=$(sed -n 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "manifest.$target.json" | head -1)
  [ -n "$version" ] || { echo "No version in manifest.$target.json" >&2; exit 1; }
  zip_path="$PWD/dist/haul-$target-$version.zip"
  rm -f "$zip_path"
  # -X leaves out extra file attributes; -r recurses; from inside the folder so
  # manifest.json is at the top of the zip.
  (cd "dist/$target" && zip -X -r -q "$zip_path" .)
  echo "Packaged dist/haul-$target-$version.zip"
}

if [ "${1:-}" = "package" ]; then
  build chrome
  build firefox
  package chrome
  package firefox
  exit 0
fi

targets="${*:-chrome firefox}"
for target in $targets; do
  build "$target"
done
