# ZipFast

Offline archive extractor and creator for Android, built with Flutter.
No fullscreen ads, no account, nothing leaves the device.

The UI and code are English-first; Korean (한국어) is fully localized and can be
chosen in **Settings → Language** (default: follows the system language).

## What works today

| Area | Status |
| --- | --- |
| Open / list / preview / extract | ZIP (+APK/JAR), TAR, TAR.GZ/BZ2/XZ, GZ, BZ2, XZ |
| Password-protected ZIP | Read and create (AES-256); wrong/missing password handled |
| Filename repair | UTF-8, CP949 (Korean), Shift-JIS (Japanese), GBK (Chinese), one tap, auto banner |
| Partial extraction | Check files/folders in the viewer, extract only those |
| Previews | Images and text, read straight from the archive |
| Create | ZIP and TAR.GZ, 4 compression levels, AES-256 password (Pro) |
| Safety | Zip Slip / path-traversal blocked, symlinks never created, unique output folders |
| Big files | Streamed from disk in a background isolate, cancellable |
| "Open with ZipFast" | Android intent filters + `MainActivity` hand-off (see below) |
| i18n | English + Korean (`lib/l10n/app_*.arb`) |

## Not done yet (honest list)

* **RAR / RAR5 / 7Z / ISO / CAB, split archives.** These need the native engine
  from the design doc (`libarchive` + RARLAB `UnRAR` through `dart:ffi` and the
  NDK). The app recognizes these formats and shows a clear "not supported in
  this build" screen. The seam is `ArchiveEngine` in
  `lib/engine/archive_engine.dart`: implement it with FFI bindings and register
  it for the extra formats; nothing else in the app needs to change.
* **Foreground service / notification progress** for long jobs (planned:
  `flutter_foreground_task`). Jobs currently run in an isolate while the app is
  open.
* **Billing and ads.** Pro is a flag (`AppState.isPro`) that can only be toggled
  in debug builds. `AdBannerSlot` is where an AdMob banner goes; it shows a
  placeholder in debug builds and nothing in release.
* PDF preview, split-archive *creation*, batch extraction, password favorites.
* The Android side (manifest, `MainActivity.kt`) was written without an Android
  SDK available, so it has **not been compiled or run on a device**. Dart code is
  analyzed and tested (see below).

## Storage model

Google Play restricts all-files access, so ZipFast requests no broad storage
permission. Files come in through the system picker or "Open with". Extraction
goes next to the archive when that folder is writable and durable, otherwise to
the app's own storage (`Android/data/<app>/files/Extracted`), and the app says
so. The "Browse device" tab and the recent-files scan degrade to an explanatory
empty state when Android denies directory listing.

## Project layout

```
lib/
  core/       format detection (magic bytes + names), theme, formatting
  encoding/   CP949 / Shift-JIS / GBK decoders (+ generated tables)
  engine/     ArchiveEngine interface, pure-Dart engine, isolate job runner,
              path-safety (Zip Slip) helpers
  services/   incoming-file channel (Android "Open with")
  state/      AppState (settings, history), StorageService
  ui/         home, viewer, extract/create sheets, settings, widgets
  l10n/       app_en.arb (template), app_ko.arb; generated code in l10n/gen
test/         engine tests (round trips, Zip Slip, encoding, passwords) + widget tests
tool/         fixture and table generators (Python 3)
```

## Develop

Requires a recent Flutter SDK (this repo uses the split `material_ui` package).

```sh
flutter pub get
flutter gen-l10n          # after editing lib/l10n/*.arb
flutter analyze
flutter test
flutter run               # Android device or emulator
```

Regenerating data files:

```sh
python3 tool/gen_legacy_tables.py   # lib/encoding/legacy_tables.g.dart
python3 tool/make_fixtures.py       # test/fixtures/*.zip
```

## Open-source notes

Uses the Dart `archive` package (MIT). When the native engine lands, ship the
`libarchive` (BSD) and RARLAB `UnRAR` license texts on the licenses screen
(`Settings → Open-source licenses`); UnRAR's license forbids implementing RAR
*creation*, which this app never does.
