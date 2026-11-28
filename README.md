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
| Files | In-app file manager for ZipFast's folder: open, share, rename, move, delete, new folder; choose extract / save folder per job, set defaults, or be asked every time |
| Safety | Zip Slip / path-traversal blocked in both engines, symlinks never created |
| Big files | Streamed from disk, background work, cancellable |
| "Open with ZipFast" | Android intent filters + `MainActivity` hand-off |
| i18n | English + Korean (`lib/l10n/app_*.arb`) |

## Startup safety

`main()` opens the app immediately (`ZipFastBoot`, `lib/boot.dart`): a splash while settings, folders and
ads consent load. If any startup step fails it shows an error screen with the exception and stack (with
*Retry* and *Copy*) instead of a dead app, and every `path_provider` lookup has a fallback. Uncaught async
errors are logged (`adb logcat | grep ZipFast`).

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
* Ads: see **Ads** below (Android code unverified, like the rest).

## Ads (AdMob banner)

* Google Mobile Ads SDK (`google_mobile_ads`), one **anchored adaptive banner** at the bottom of the home
  screen only; never over dialogs, progress or archive work, and the FAB floats above it.
  App ID `ca-app-pub-4400173019354346~7131341860` (manifest meta-data, required or the app crashes at
  start); banner unit `ca-app-pub-4400173019354346/9123080380` (`lib/services/ads_service.dart`).
* A rewarded unit (`ca-app-pub-4400173019354346/8092410605`) is stored in `AdUnits` but **not shown
  anywhere yet**: it needs a reward the user knowingly opts into (e.g. hide the banner for 24 hours).
* **Consent first:** the Google UMP consent form runs before the SDK initializes; no ad request is made
  until consent allows it. Where Google requires it, Settings shows **Ad privacy settings** to change the
  choice. A failed load or no consent means the banner takes no space.
* **Test ads outside the store:** debug builds and any build with `--dart-define=ZIPFAST_TEST_ADS=true`
  (the GitHub prerelease workflow) use Google's test unit. Clicking your own live ads can get an AdMob
  account banned. A Play build is made without that define so it uses the live unit.
* Before a Play release: declare ads and the advertising ID in **Data safety**, answer the *Ads* and
  *Target audience* (not child-directed) forms, and host `app-ads.txt` on the developer website. The
  plugin adds the `AD_ID` permission. The INTERNET permission exists only for ads; archives never use it.

## Where files live, and getting them out

ZipFast keeps results in **its own storage folder** (`Android/data/<app>/files`), so it needs no broad
storage permission and works the same on every Android version (and passes Google Play policy).
Other apps cannot read that folder directly, so the app includes a file manager and ways out:

* **Files tab** (also opened by **Show files** after an extract / create): browse the folder, open an
  archive in ZipFast, open any other file in another app, **share** files through the system share sheet,
  rename, move (in-app folder picker), delete, create folders, multi-select, and compress a selection.
  Everything is confined to the storage folder (guarded and tested in `lib/state/file_ops.dart`).
* **Choosing where to extract / save:** the extract sheet offers *new folder next to the archive*
  (falls back to app storage if that folder isn't writable), *same folder*, or *choose folder* in the
  in-app picker (with an optional new subfolder). The create sheet has a *Save to* row. In Settings you
  can set a default extract folder and a default save folder, or turn on **Ask for a folder every time**.
* **Save a copy to…** (Files tab selection bar, and the buttons after extract / create) copies files or
  folders to any folder you pick with Android's system folder picker (Storage Access Framework). No
  permission is declared: choosing the folder is the grant, and ZipFast remembers it, offering it as a
  one-tap choice next time (and asking again if Android revoked it). Android 11+ does not let apps be
  granted the storage root, `Download` itself, or `Android/data`; pick a subfolder (e.g. `Download/Unpacked`).
  The copy logic (`TreeExporter.java`: recursion, progress, cancel, MIME types, name cleaning, symlinks
  skipped) is unit-tested on the host JVM; the thin `DocumentsContract` adapter in `ExportPlugin.kt` is not
  compiled here. Split archives are copied and shared as the whole `.001`, `.002`, ... set.
* `open_filex` and `share_plus` provide the FileProvider plumbing for open/share. Like the rest of the
  Android side, it has not been built or run on a device here.

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

That script also tests `TreeExporter` (the "Save a copy to…" copy logic).

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
