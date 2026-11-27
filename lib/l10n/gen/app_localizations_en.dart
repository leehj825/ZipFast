// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'ZipFast';

  @override
  String get appTagline => 'Extract anything. Offline. No fullscreen ads.';

  @override
  String get proBadge => 'PRO';

  @override
  String get settings => 'Settings';

  @override
  String get search => 'Search';

  @override
  String get searchHint => 'Search archives';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get close => 'Close';

  @override
  String get done => 'Done';

  @override
  String get retry => 'Retry';

  @override
  String get delete => 'Delete';

  @override
  String get tabRecent => 'Recent archives';

  @override
  String get tabBrowse => 'Browse device';

  @override
  String recentArchivesTitle(int count) {
    return 'Recent archives ($count)';
  }

  @override
  String get noRecentTitle => 'No archives yet';

  @override
  String get noRecentBody =>
      'Tap “Open archive” to pick a file, or open an archive from any app with “Open with ZipFast”.';

  @override
  String get openArchive => 'Open archive';

  @override
  String get createArchive => 'Create archive';

  @override
  String get createArchiveSub => 'ZIP, TAR.GZ';

  @override
  String get extractArchive => 'Extract archive';

  @override
  String get extractArchiveSub => 'ZIP, TAR, GZ, BZ2, XZ';

  @override
  String get encodingFixTitle => 'Encoding fix (broken text)';

  @override
  String get encodingFixSub => 'Repairs Korean, Japanese & Chinese file names';

  @override
  String get aesSupported => 'AES-256 encryption supported';

  @override
  String get splitBadge => 'split archive';

  @override
  String get adBannerPlaceholder => 'Ad banner space';

  @override
  String modifiedOn(String date) {
    return 'Modified $date';
  }

  @override
  String get browseNoAccessTitle => 'Can’t list this folder';

  @override
  String get browseNoAccessBody =>
      'Android restricts file access for apps. Use “Open archive” to pick files with the system picker.';

  @override
  String get browseEmpty => 'This folder is empty';

  @override
  String compressSelected(int count) {
    return 'Compress $count selected';
  }

  @override
  String get upOneLevel => 'Up one level';

  @override
  String viewerSubtitle(int files, String size) {
    return '$files files · $size unpacked';
  }

  @override
  String get encodingLabel => 'Encoding';

  @override
  String get encodingAuto => 'Auto (UTF-8)';

  @override
  String get encodingCp949 => 'CP949 (Korean)';

  @override
  String get encodingShiftJis => 'Shift-JIS (Japanese)';

  @override
  String get encodingGbk => 'GBK (Chinese)';

  @override
  String get encodingBannerTitle => 'File names look garbled';

  @override
  String get encodingBannerAction => 'Fix';

  @override
  String get extractAll => 'Extract all';

  @override
  String extractSelected(int count) {
    return 'Extract $count selected';
  }

  @override
  String get folderEmpty => 'This folder is empty';

  @override
  String get selectAll => 'Select all';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get previewUnavailable =>
      'No preview for this file type. Select it and extract instead.';

  @override
  String get previewTooLarge => 'This file is too large to preview.';

  @override
  String get previewFailed => 'Couldn’t preview this file.';

  @override
  String get passwordTitle => 'Password required';

  @override
  String get passwordWrong => 'Wrong password. Try again.';

  @override
  String get passwordHint => 'Password';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get unlock => 'Unlock';

  @override
  String unsupportedTitle(String format) {
    return '$format isn’t supported in this build';
  }

  @override
  String get unsupportedBody =>
      'This build handles ZIP, TAR, GZ, BZ2 and XZ. RAR, 7Z, ISO and CAB need the native engine (libarchive + UnRAR), which is not bundled yet.';

  @override
  String get corruptTitle => 'Couldn’t open this archive';

  @override
  String get encryptedBadge => 'Encrypted';

  @override
  String get extractTitle => 'Extract';

  @override
  String get destination => 'Destination';

  @override
  String get destNewFolder => 'New folder (recommended)';

  @override
  String get destSameFolder => 'Same folder as the archive';

  @override
  String get destCustom => 'Choose folder…';

  @override
  String get destFallbackNote =>
      'The archive’s folder isn’t writable, so files go to ZipFast’s storage instead.';

  @override
  String get ifFileExists => 'If a file already exists';

  @override
  String get conflictSkip => 'Skip';

  @override
  String get conflictOverwrite => 'Overwrite';

  @override
  String get conflictRename => 'Rename automatically';

  @override
  String get extractButton => 'Extract';

  @override
  String get extracting => 'Extracting…';

  @override
  String get extractDoneTitle => 'Extraction complete';

  @override
  String extractedSummary(int count, String path) {
    return '$count files extracted to\n$path';
  }

  @override
  String blockedWarning(int count) {
    return '$count unsafe entries were blocked (path traversal).';
  }

  @override
  String skippedNote(int count) {
    return '$count entries skipped.';
  }

  @override
  String get cancelled => 'Cancelled';

  @override
  String get copyPath => 'Copy path';

  @override
  String get pathCopied => 'Path copied';

  @override
  String get createTitle => 'Create archive';

  @override
  String get archiveName => 'Archive name';

  @override
  String get format => 'Format';

  @override
  String get compression => 'Compression';

  @override
  String get levelStore => 'Store';

  @override
  String get levelFast => 'Fast';

  @override
  String get levelNormal => 'Normal';

  @override
  String get levelMaximum => 'Maximum';

  @override
  String get passwordProtect => 'Password lock (AES-256)';

  @override
  String get passwordProtectSub => 'ZIP only';

  @override
  String get splitArchive => 'Split archive';

  @override
  String get splitArchiveSub => 'Coming soon';

  @override
  String get proFeature => 'Pro';

  @override
  String get createButton => 'Create';

  @override
  String get creating => 'Creating archive…';

  @override
  String get createdTitle => 'Archive created';

  @override
  String createdSummary(String path) {
    return 'Saved to\n$path';
  }

  @override
  String get noFilesSelected => 'No files selected';

  @override
  String filesSelected(int count) {
    return '$count items selected';
  }

  @override
  String get pickFiles => 'Pick files';

  @override
  String get proTitle => 'ZipFast Pro';

  @override
  String get proIntro =>
      'One-time purchase. Extraction of every format stays free.';

  @override
  String get proFeatureAds => 'Remove all ads';

  @override
  String get proFeatureAes => 'AES-256 encrypted archives';

  @override
  String get proFeatureSplit => 'Split archives';

  @override
  String get proFeatureBatch => 'Batch extraction & password favorites';

  @override
  String get proUnavailable => 'Purchases aren’t available in this build yet.';

  @override
  String get proDebugUnlock => 'Unlock (debug build)';

  @override
  String get proDebugLock => 'Lock again (debug build)';

  @override
  String get proActive => 'Pro is active';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get defaultConflict => 'Default for existing files';

  @override
  String get clearCache => 'Clear preview cache';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get licenses => 'Open-source licenses';

  @override
  String get about => 'About';

  @override
  String get privacy => '100% offline. Your files never leave this device.';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String genericError(String message) {
    return 'Something went wrong: $message';
  }
}
