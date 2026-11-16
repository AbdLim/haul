# Third-party software and assets

Haul's own code is free software (see [LICENSE](../LICENSE)). It is built from the
open-source parts below. Each keeps its own licence and copyright; the full
texts ship inside the app (**Settings, About, Show licences**) and with each
package's source.

None of these licences is stronger than the GNU GPL v3 that covers Haul, so
they can be combined with it. Haul is distributed directly, not through the Mac
App Store, whose terms do not suit GPL software.

## Fonts and icons (bundled in `app/assets/fonts`)

| Name | Used for | Licence | Text |
| --- | --- | --- | --- |
| Space Grotesk (Florian Karsten) | The wordmark, view titles and the speed readout | SIL Open Font License 1.1 | `app/assets/fonts/OFL.txt` |
| Phosphor Icons (Phosphor Icons) | Every icon in the app (regular weight, the font file only) | MIT | `app/assets/fonts/PHOSPHOR-LICENSE.txt` |

## Frameworks

| Name | Licence |
| --- | --- |
| Flutter SDK and engine (Google) | BSD-3-Clause |
| Dart SDK (Google) | BSD-3-Clause |
| SQLite (compiled into the `sqlite3` package) | Public domain |

## Packages the app uses directly (`app/pubspec.yaml`)

| Package | Licence |
| --- | --- |
| `flutter_bloc`, `bloc` | MIT |
| `equatable` | MIT |
| `drift` | MIT |
| `sqlite3` | MIT |
| `macos_window_utils` | MIT |
| `window_manager` | MIT |
| `tray_manager` | MIT |
| `local_notifier` | MIT |
| `launch_at_startup` | MIT |
| `cupertino_icons` (a dependency; its font is not used) | MIT |
| `desktop_drop` | Apache-2.0 |
| `file_selector` | BSD-3-Clause |
| `flutter_secure_storage` | BSD-3-Clause |
| `path`, `path_provider` | BSD-3-Clause |

`download_engine` (in `packages/download_engine`) is Haul's own engine and uses
only `path` (BSD-3-Clause).

## Packages those depend on

About 90 further packages come in through the ones above. By count they are
BSD-3-Clause (mostly the Dart and Flutter teams' own packages), MIT, and a few
Apache-2.0 and BSD-2-Clause. The complete, current list with every licence text
is in the app under **Settings, About, Show licences**, which Flutter builds
from the packages actually compiled in.

Two notes:

- `dbus` (MPL-2.0) is pulled in by `desktop_drop` for Linux only. It is not
  part of the macOS app.
- Development tools (the test runner, `build_runner`, `drift_dev`, `mocktail`,
  linters) are used to build and test Haul but are not shipped in it.

## Browser extension (`extension/`)

The extension has no third-party code: it is plain JavaScript with no
libraries. Its icons are Haul's own.

## Haul's name and logo

The licence covers Haul's source code. The name "Haul" and the logo in
`app/assets/brand` are not licensed for use as the name or mark of a modified
or competing product; a fork should pick its own name and icon.
