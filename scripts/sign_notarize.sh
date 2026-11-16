#!/bin/sh
# Signs Haul with a Developer ID Application certificate and the Hardened
# Runtime, packs it in a DMG with an Applications shortcut, has Apple notarize
# the DMG, and staples the ticket.
#
#   HAUL_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   HAUL_NOTARY_PROFILE="haul-notary" \
#   scripts/sign_notarize.sh [path/to/Haul.app]
#
# HAUL_SIGN_IDENTITY  the certificate's name, as `security find-identity -v
#                     -p codesigning` shows it
# HAUL_NOTARY_PROFILE a keychain profile made once with
#                     `xcrun notarytool store-credentials haul-notary`
#
# With no path it uses the app built by scripts/build_release.sh. The output is
# dist/Haul-<version>.dmg.
#
# Instead of a keychain profile, notarization can use an Apple ID directly (this
# is what the GitHub release workflow does): set HAUL_NOTARY_APPLE_ID,
# HAUL_NOTARY_TEAM_ID and HAUL_NOTARY_PASSWORD (an app-specific password).
#
# HAUL_UNSIGNED=1 only packs the app, exactly as built, into
# dist/Haul-<version>-unsigned.dmg. No certificate is used and nothing is
# sent to Apple. People who open it must approve it by hand in macOS (see the
# README). Used by the release workflow until signing secrets are set up.
#
# HAUL_DRY_RUN=1 signs ad hoc and builds the DMG but skips Apple (no
# certificate needed), to check the packaging steps. Its result is NOT fit to
# give to anyone.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
dry="${HAUL_DRY_RUN:-}"

fail() { echo "$*" >&2; exit "${2:-1}"; }
step() { printf '\n==> %s\n' "$*"; }

unsigned="${HAUL_UNSIGNED:-}"

# The notarytool credentials: a keychain profile, or an Apple ID and password.
notary_auth() {
  if [ -n "${HAUL_NOTARY_PROFILE:-}" ]; then
    echo "--keychain-profile $HAUL_NOTARY_PROFILE"
  else
    echo "--apple-id $HAUL_NOTARY_APPLE_ID --team-id $HAUL_NOTARY_TEAM_ID --password $HAUL_NOTARY_PASSWORD"
  fi
}

if [ "$unsigned" = "1" ]; then
  identity=""
elif [ "$dry" = "1" ]; then
  identity="-"
  echo "DRY RUN: ad hoc signature, no notarization. Do not distribute the result." >&2
else
  [ -n "${HAUL_SIGN_IDENTITY:-}" ] || fail \
    "HAUL_SIGN_IDENTITY is not set. It is the name of your Developer ID Application certificate; see this script's header." 2
  if [ -z "${HAUL_NOTARY_PROFILE:-}" ] && { [ -z "${HAUL_NOTARY_APPLE_ID:-}" ] || [ -z "${HAUL_NOTARY_TEAM_ID:-}" ] || [ -z "${HAUL_NOTARY_PASSWORD:-}" ]; }; then
    fail "Set HAUL_NOTARY_PROFILE (xcrun notarytool store-credentials <name>), or HAUL_NOTARY_APPLE_ID, HAUL_NOTARY_TEAM_ID and HAUL_NOTARY_PASSWORD." 2
  fi
  security find-identity -v -p codesigning | grep -F -- "$HAUL_SIGN_IDENTITY" >/dev/null || fail \
    "No certificate named '$HAUL_SIGN_IDENTITY' is in your keychain. Check: security find-identity -v -p codesigning" 2
  identity="$HAUL_SIGN_IDENTITY"
fi

source_app="${1:-$root/app/build/macos/Build/Products/Release/Haul.app}"
[ -d "$source_app" ] || fail "No app at $source_app. Run scripts/build_release.sh first, or pass the path." 2

version=$(sed -n 's/^version:[[:space:]]*\([0-9][0-9.]*\).*/\1/p' "$root/app/pubspec.yaml" | head -1)
[ -n "$version" ] || fail "Could not read the version from app/pubspec.yaml"

out="$root/dist"
work="$out/work"
rm -rf "$work"
mkdir -p "$work"
app="$work/Haul.app"
# Work on a copy, so the build output stays as Flutter made it.
cp -R "$source_app" "$app"

if [ "$unsigned" = "1" ]; then
  step "Packing the app as built, unsigned"
  dmg="$out/Haul-$version-unsigned.dmg"
  stage="$work/dmg"
  mkdir -p "$stage"
  cp -R "$app" "$stage/Haul.app"
  ln -s /Applications "$stage/Applications"
  hdiutil create -volname "Haul" -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$dmg" >/dev/null
  rm -rf "$work"
  echo "$dmg"
  exit 0
fi

entitlements="$root/scripts/distribution.entitlements"
timestamp="--timestamp"
[ "$dry" = "1" ] && timestamp="--timestamp=none"

sign() { # path [extra codesign args...]
  target=$1; shift
  codesign --force --options runtime $timestamp --sign "$identity" "$@" "$target"
}

step "Signing the parts of the app, innermost first"
# Everything that holds code, deepest paths first, so each part is signed
# before the bundle that contains it.
find "$app/Contents" \( -name '*.framework' -o -name '*.xpc' -o -name '*.app' -o -name '*.dylib' -o -name '*.bundle' \) \
  -not -path "$app" | awk '{ print length($0) " " $0 }' | sort -rn | cut -d' ' -f2- |
while IFS= read -r part; do
  # A resource bundle with no code is sealed by the app's own signature.
  case "$part" in
    *.bundle) [ -d "$part/Contents/MacOS" ] || continue ;;
  esac
  echo "  $part"
  sign "$part"
done

step "Signing the app with the Hardened Runtime"
sign "$app" --entitlements "$entitlements"

step "Checking the signature"
codesign --verify --deep --strict --verbose=2 "$app"
codesign -dvv "$app" 2>&1 | grep -E 'Authority|TeamIdentifier|flags|Identifier=' || true
if codesign -d --entitlements - "$app" 2>&1 | grep -q 'disable-library-validation'; then
  fail "The signed app still carries disable-library-validation."
fi

step "Building the DMG"
dmg="$out/Haul-$version.dmg"
stage="$work/dmg"
rm -rf "$stage" "$dmg"
mkdir -p "$stage"
cp -R "$app" "$stage/Haul.app"
ln -s /Applications "$stage/Applications"
hdiutil create -volname "Haul" -srcfolder "$stage" -fs HFS+ -format UDZO -ov "$dmg" >/dev/null
sign "$dmg"
echo "  $dmg"

if [ "$dry" = "1" ]; then
  step "Dry run finished: $dmg (not notarized)"
  rm -rf "$work"
  exit 0
fi

step "Submitting to Apple for notarization (this can take several minutes)"
# shellcheck disable=SC2046
result=$(xcrun notarytool submit "$dmg" $(notary_auth) --wait --output-format plist)
echo "$result"
status=$(printf '%s' "$result" | plutil -extract status raw -o - - 2>/dev/null || echo unknown)
if [ "$status" != "Accepted" ]; then
  id=$(printf '%s' "$result" | plutil -extract id raw -o - - 2>/dev/null || true)
  # shellcheck disable=SC2046
  [ -n "$id" ] && xcrun notarytool log "$id" $(notary_auth) >&2 || true
  fail "Notarization finished as '$status', not Accepted."
fi

step "Stapling the ticket"
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"

step "Final checks"
spctl --assess --type open --context context:primary-signature -vv "$dmg"
mount=$(mktemp -d)
hdiutil attach "$dmg" -mountpoint "$mount" -nobrowse -quiet
spctl --assess --type execute -vv "$mount/Haul.app"
hdiutil detach "$mount" -quiet
rm -rf "$work"

step "Done"
echo "$dmg"
