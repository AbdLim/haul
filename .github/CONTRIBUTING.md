# Contributing to Haul

Thank you for helping. Bug reports, ideas, documentation fixes and code are all
welcome. By taking part you agree to follow the
[Code of Conduct](CODE_OF_CONDUCT.md).

## Before you start

- **Bugs:** search the open issues first, then use the *Bug report* form. The
  version, macOS version and what the row said help the most.
- **Features:** open a *Feature request* and talk it over before writing a large
  change. Haul aims to stay small, fast and Mac-native, so some ideas will not
  fit.
- **Security problems:** do not use issues. See [SECURITY.md](SECURITY.md).

## Setting up

You need a Mac, [Flutter](https://docs.flutter.dev/get-started/install/macos)
(the version in `.github/workflows/ci.yml`), Xcode, and Node 20 or newer for
the extension's checks.

```
git clone <your fork>
cd haul/app && flutter pub get && flutter run -d macos
```

The repository is a small monorepo:

```
app/                        the Flutter app (Cubits, widgets layer only)
packages/download_engine/   the download engine, pure Dart
extension/                  the Chrome and Firefox extension, plain JavaScript
scripts/                    release, signing and packaging scripts
```

## Checks to run

```
scripts/build_release.sh     # analyze + every test + a release build + launch check
```

or the parts:

```
(cd packages/download_engine && dart analyze && dart test)
(cd app && flutter analyze && flutter test)
(cd extension && npm test)               # and `npm run e2e` with Chrome installed
```

A pull request should keep analysis clean and every test passing. New behaviour
needs a test; a bug fix needs a test that fails without the fix.

## House rules

- **No stock Material or Cupertino widgets** in the app. Use the components in
  `app/lib/app/components` (`HaulButton`, `HaulDialog`, and so on) and the
  theme.
- **State lives in Cubits.** Widgets read state and call methods; they do not
  talk to the database or the engine directly.
- **Everything platform-specific goes behind an interface** in
  `app/lib/services/system`, so Windows and Linux can be added later.
- **Words for people.** Errors say what happened in plain language, never a
  code. Keep copy short and kind.
- **Explain departures.** If you deviate from the obvious design, say why in
  the pull request and in a code comment.

## Commits and pull requests

- One logical change per pull request, with a clear description of what and why.
- Commit messages: a short imperative summary (`Fix: ...`, `Add: ...`).
- Fill in the pull request template; screenshots help for anything visible.
- Expect review comments; they are about the code, not you.

## Licence of contributions

Haul's app and extension are under the GNU GPL v3 or later, and the download
engine under the GNU LGPL v3 or later (see [LICENSE](../LICENSE)). By submitting a
contribution you agree it may be distributed under the licence of the part of
the project you changed, and that you have the right to submit it.
