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
  String get tabBrowse => 'Files';

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
  String get createArchiveSub => 'ZIP, 7Z, TAR.GZ';

  @override
  String get extractArchive => 'Extract archive';

  @override
  String get extractArchiveSub => 'ZIP, RAR, 7Z, TAR, ISO…';

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
      'This format needs the 7-Zip engine, which is only available in the Android app.';

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
  String get passwordProtectSub => 'ZIP and 7Z';

  @override
  String get splitArchive => 'Split archive';

  @override
  String get splitArchiveSub => 'Cut into volumes (.001, .002, …)';

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
  String get splitSize => 'Volume size';

  @override
  String splitSizeMb(int mb) {
    return '$mb MB';
  }

  @override
  String get splitCustomMb => 'Custom size (MB)';

  @override
  String get splitTooSmall => 'Enter a size of at least 1 MB.';

  @override
  String get splitVolumesNote =>
      'Volumes are named .001, .002, … Open the .001 file to extract.';

  @override
  String get extractLocation => 'Default extract folder';

  @override
  String get extractLocationNextTo => 'New folder next to the archive';

  @override
  String get saveLocation => 'Default save folder for new archives';

  @override
  String get saveLocationApp => 'ZipFast storage';

  @override
  String get chooseFolder => 'Choose folder…';

  @override
  String get resetToDefault => 'Reset to default';

  @override
  String get change => 'Change';

  @override
  String get saveTo => 'Save to';

  @override
  String get createSubfolder => 'Put files in a new folder';

  @override
  String get askEveryTime => 'Ask for a folder every time';

  @override
  String get askEveryTimeSub =>
      'Pick the destination each time you extract or create';

  @override
  String get storageRoot => 'ZipFast storage';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get rename => 'Rename';

  @override
  String get newName => 'New name';

  @override
  String get moveTo => 'Move to…';

  @override
  String get moveHere => 'Move here';

  @override
  String get useThisFolder => 'Use this folder';

  @override
  String get chooseDestination => 'Choose a folder';

  @override
  String get shareAction => 'Share';

  @override
  String get shareFoldersNote =>
      'Folders can’t be shared. Compress them first.';

  @override
  String get openWith => 'Open with…';

  @override
  String get noAppToOpen => 'No app can open this file.';

  @override
  String deleteConfirmTitle(int count) {
    return 'Delete $count items?';
  }

  @override
  String get deleteConfirmBody => 'This can’t be undone.';

  @override
  String get opNameInvalid => 'That name isn’t allowed.';

  @override
  String get opNameTaken => 'Something with that name already exists.';

  @override
  String get opIntoItself => 'A folder can’t be moved into itself.';

  @override
  String get opFailed => 'The operation failed.';

  @override
  String get showFiles => 'Show files';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get refresh => 'Refresh';

  @override
  String get storageHint =>
      'Results are saved in ZipFast’s own folder. Open or share a file to use it in other apps.';

  @override
  String get saveCopyTo => 'Save a copy to…';

  @override
  String saveCopyHere(String folder) {
    return 'Save to $folder';
  }

  @override
  String get chooseAnotherFolder => 'Choose another folder…';

  @override
  String get copying => 'Copying…';

  @override
  String get copyDoneTitle => 'Copy complete';

  @override
  String copiedSummary(int count, String folder) {
    return '$count files copied to\n$folder';
  }

  @override
  String get exportUnavailable =>
      'Saving to another folder isn’t available here.';

  @override
  String get exportAccessLost =>
      'Access to that folder was removed. Choose it again.';

  @override
  String get exportNothing => 'Nothing to copy.';

  @override
  String get adPrivacy => 'Ad privacy settings';

  @override
  String get adPrivacySub => 'Review or change your ad consent choices';

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
  String get privacy =>
      'Archives are processed offline; your files never leave this device. Only the ad banner uses the internet.';

  @override
  String version(String version) {
    return 'Version $version';
  }

  @override
  String genericError(String message) {
    return 'Something went wrong: $message';
  }
}
