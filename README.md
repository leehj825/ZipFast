# ZipFast

Offline archive extractor and creator for Android, built with Flutter.
No fullscreen ads, no account, nothing leaves the device.

The UI and code are English-first; Korean (한국어) is fully localized and can be
chosen in **Settings → Language** (default: follows the system language).

## What works today

Everything is free: there is no Pro tier, no purchase, and no feature gating.

| Area | Status |
| --- | --- |
| Open / list / preview / extract | ZIP (+APK/JAR), TAR, TAR.GZ/BZ2/XZ, GZ, BZ2, XZ **and** RAR, RAR5, 7Z, ISO, CAB |
| Split archives | `.7z.001`, `.zip.001`, `.part1.rar`, `.r00` (any volume opens the set) |
| Passwords | ZIP (AES-256 + ZipCrypto), 7Z (incl. encrypted file names), RAR; wrong/missing password handled |
| Filename repair | ZIP: UTF-8, CP949 (Korean), Shift-JIS (Japanese), GBK (Chinese), one tap, auto banner |
| Partial extraction | Check files/folders in the viewer, extract only those |
| Previews | Images and text, read straight from the archive |
| Create | ZIP, 7Z, TAR.GZ; 4 compression levels; AES-256 password (ZIP, 7Z); split into volumes (10 / 25 / 100 MB or custom) |
| Locations | Choose the extract / save folder per job, set defaults in Settings, or have the app ask every time |
| Safety | Zip Slip / path-traversal blocked in both engines, symlinks never created |
| Big files | Streamed from disk, background work, cancellable |
| "Open with ZipFast" | Android intent filters + `MainActivity` hand-off |
| i18n | English + Korean (`lib/l10n/app_*.arb`) |

## Two engines

| Engine | Formats | Where it runs |
| --- | --- | --- |
| `DartArchiveEngine` | ZIP, TAR(+GZ/BZ2/XZ), GZ, BZ2, XZ; name-encoding repair | pure Dart, in an isolate |
| `NativeArchiveEngine` | RAR, RAR5, 7Z, ISO, CAB, all split sets, 7Z creation | 7-Zip via 7-Zip-JBinding (`ArchiveBridge.java`, `EnginePlugin.kt`), Android only |

`CompositeEngine` routes each archive to the right one; the UI only knows `appEngine`.
Splitting a created archive is done in Dart for both engines (byte-split into `.001`, `.002`, ...,
the same layout 7-Zip uses).

Why 7-Zip rather than libarchive + UnRAR (the original plan): libarchive cannot decrypt 7Z or RAR,
which the product promises; 7-Zip does both, and also reads RAR5 and creates 7Z.

## Not done yet (honest list)

* **Android build is unverified.** There is no Android SDK in the environment I developed in, so the
  Gradle setup, `EnginePlugin.kt`, `MainActivity.kt` and the manifest were never compiled, and the app
  was never run on a device. In particular the dependency
  `com.github.omicronapps:7-Zip-JBinding-4Android:Release-16.02-2.02` (JitPack, the Android port of the
  same `net.sf.sevenzipjbinding` API) is declared but could not be resolved there. Run
  `flutter build apk` first; if that artifact or its version is unavailable, adjust the coordinates in
  `android/app/build.gradle.kts`. If you turn on R8/minify, keep `net.sf.sevenzipjbinding.**` (JNI).
* `.z01`-style split ZIPs are routed to 7-Zip but untested; `.zip.001` is the supported split-ZIP form.
* RAR with encrypted data and multi-volume RAR (`.part1.rar`) are untested: no free tool can create RAR
  fixtures, so tests use hand-built stored RAR4/RAR5 files.
* Filename-encoding repair only exists for ZIP (7Z names are Unicode; RAR names are rarely mis-encoded).
* Foreground service / notification progress for long jobs; PDF preview; batch extraction.
* Ads: `AdBannerSlot` is where an AdMob banner goes; it shows a placeholder in debug builds and nothing
  in release.

## Choosing where files go

* **Extract:** in the extract sheet pick *new folder next to the archive*, *same folder*, or
  *choose folder* (optionally inside a new subfolder). **Settings → Default extract folder** preselects
  a folder; **Ask for a folder every time** opens the folder picker on every extract / create.
* **Create:** the *Save to* row in the create sheet changes the folder for that archive;
  **Settings → Default save folder** sets the default (otherwise ZipFast's own storage).
* On Android 11+ apps may only write to their own folders unless **All files access** is granted.
  ZipFast checks a picked folder and, if Android blocks it, offers to open that system screen
  (Settings also has a tile for it). The manifest declares `MANAGE_EXTERNAL_STORAGE` for this; Google Play
  only allows it for approved use cases, so remove it (and the tile) for a Play build.
  Android 10 and older would additionally need the legacy write permission, which is not requested yet.
* `StoragePlugin.kt` (the permission check) is, like the rest of the Android code, uncompiled here.

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
  engine/     ArchiveEngine interface; Dart, native (7-Zip) and composite engines;
              isolate job runner; path-safety (Zip Slip) helpers; archive splitting
  services/   incoming-file channel (Android "Open with")
  state/      AppState (settings, history), StorageService
  ui/         home, viewer, extract/create sheets, settings, widgets
  l10n/       app_en.arb (template), app_ko.arb; generated code in l10n/gen
test/         engine tests (round trips, Zip Slip, encoding, passwords), routing/split/channel
              tests, widget tests
tool/         fixture and table generators (Python 3)
android/engine-test/   host-JVM tests for the 7-Zip bridge (see below)
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

Test the 7-Zip bridge (RAR/RAR5/7Z/ISO/CAB, passwords, split volumes, 7Z creation, Zip Slip,
cancel) on a plain JVM, no Android needed. It downloads the 7-Zip-JBinding jars from Maven Central
and builds fixtures with `pip install py7zr pycdlib`:

```sh
android/engine-test/run_tests.sh
```

Regenerating data files:

```sh
python3 tool/gen_legacy_tables.py   # lib/encoding/legacy_tables.g.dart
python3 tool/make_fixtures.py       # test/fixtures/*.zip
```

## Open-source notes

* Dart `archive` package (MIT).
* 7-Zip / 7-Zip-JBinding (LGPL). The unRAR code in 7-Zip may only be used to *decompress* RAR; ZipFast
  never creates RAR. The notice is registered in `lib/main.dart` and appears under
  **Settings → Open-source licenses**.
