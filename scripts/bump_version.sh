#!/bin/sh
# Raises Haul's version everywhere it is written down:
#
#   scripts/bump_version.sh 1.0.1
#
# - app/pubspec.yaml (the version, and the build number goes up by one)
# - app/lib/app/version.dart (what Settings, About shows)
# - extension/manifest.chrome.json and manifest.firefox.json
# - .github/CHANGELOG.md: a dated section for the version is started under
#   "Unreleased", so what you wrote there becomes that release's notes
#
# Then review the diff, commit it, and run the Release workflow.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

version="${1:-}"
version="${version#v}"
case "$version" in
  *[!0-9.]* | "") echo "Usage: scripts/bump_version.sh <major.minor.patch>, such as 1.0.1" >&2; exit 2 ;;
esac
case "$version" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "Usage: scripts/bump_version.sh <major.minor.patch>, such as 1.0.1" >&2; exit 2 ;;
esac

current=$(sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\)+.*/\1/p' app/pubspec.yaml | head -1)
build=$(sed -n 's/^version:[[:space:]]*[0-9][0-9.]*+\([0-9][0-9]*\).*/\1/p' app/pubspec.yaml | head -1)
[ -n "$current" ] && [ -n "$build" ] || { echo "Could not read the version from app/pubspec.yaml" >&2; exit 1; }
[ "$version" != "$current" ] || { echo "The version is already $current." >&2; exit 1; }
next_build=$((build + 1))

perl -pi -e "s/^version:\\s*\\S+/version: $version+$next_build/" app/pubspec.yaml
perl -pi -e "s/appVersion = '[^']*'/appVersion = '$version'/" app/lib/app/version.dart
for m in extension/manifest.chrome.json extension/manifest.firefox.json; do
  perl -pi -e "s/\"version\":\\s*\"[^\"]*\"/\"version\": \"$version\"/" "$m"
done

today=$(date +%Y-%m-%d)
if grep -q '^## \[Unreleased\]' .github/CHANGELOG.md; then
  perl -0pi -e "s/## \\[Unreleased\\]\\n/## [Unreleased]\\n\\n## [$version] - $today\\n/" .github/CHANGELOG.md
else
  echo "Note: .github/CHANGELOG.md has no 'Unreleased' heading; add the notes by hand." >&2
fi

echo "Version $current -> $version (build $next_build)."
echo "Next: check 'git diff', add notes under the new heading in .github/CHANGELOG.md,"
echo "commit, then run Actions, Release, Run workflow."
