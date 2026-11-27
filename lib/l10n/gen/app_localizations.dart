import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'ZipFast'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Extract anything. Offline. No fullscreen ads.'**
  String get appTagline;

  /// No description provided for @proBadge.
  ///
  /// In en, this message translates to:
  /// **'PRO'**
  String get proBadge;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search archives'**
  String get searchHint;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @tabRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent archives'**
  String get tabRecent;

  /// No description provided for @tabBrowse.
  ///
  /// In en, this message translates to:
  /// **'Browse device'**
  String get tabBrowse;

  /// No description provided for @recentArchivesTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent archives ({count})'**
  String recentArchivesTitle(int count);

  /// No description provided for @noRecentTitle.
  ///
  /// In en, this message translates to:
  /// **'No archives yet'**
  String get noRecentTitle;

  /// No description provided for @noRecentBody.
  ///
  /// In en, this message translates to:
  /// **'Tap “Open archive” to pick a file, or open an archive from any app with “Open with ZipFast”.'**
  String get noRecentBody;

  /// No description provided for @openArchive.
  ///
  /// In en, this message translates to:
  /// **'Open archive'**
  String get openArchive;

  /// No description provided for @createArchive.
  ///
  /// In en, this message translates to:
  /// **'Create archive'**
  String get createArchive;

  /// No description provided for @createArchiveSub.
  ///
  /// In en, this message translates to:
  /// **'ZIP, TAR.GZ'**
  String get createArchiveSub;

  /// No description provided for @extractArchive.
  ///
  /// In en, this message translates to:
  /// **'Extract archive'**
  String get extractArchive;

  /// No description provided for @extractArchiveSub.
  ///
  /// In en, this message translates to:
  /// **'ZIP, TAR, GZ, BZ2, XZ'**
  String get extractArchiveSub;

  /// No description provided for @encodingFixTitle.
  ///
  /// In en, this message translates to:
  /// **'Encoding fix (broken text)'**
  String get encodingFixTitle;

  /// No description provided for @encodingFixSub.
  ///
  /// In en, this message translates to:
  /// **'Repairs Korean, Japanese & Chinese file names'**
  String get encodingFixSub;

  /// No description provided for @aesSupported.
  ///
  /// In en, this message translates to:
  /// **'AES-256 encryption supported'**
  String get aesSupported;

  /// No description provided for @splitBadge.
  ///
  /// In en, this message translates to:
  /// **'split archive'**
  String get splitBadge;

  /// No description provided for @adBannerPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ad banner space'**
  String get adBannerPlaceholder;

  /// No description provided for @modifiedOn.
  ///
  /// In en, this message translates to:
  /// **'Modified {date}'**
  String modifiedOn(String date);

  /// No description provided for @browseNoAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Can’t list this folder'**
  String get browseNoAccessTitle;

  /// No description provided for @browseNoAccessBody.
  ///
  /// In en, this message translates to:
  /// **'Android restricts file access for apps. Use “Open archive” to pick files with the system picker.'**
  String get browseNoAccessBody;

  /// No description provided for @browseEmpty.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get browseEmpty;

  /// No description provided for @compressSelected.
  ///
  /// In en, this message translates to:
  /// **'Compress {count} selected'**
  String compressSelected(int count);

  /// No description provided for @upOneLevel.
  ///
  /// In en, this message translates to:
  /// **'Up one level'**
  String get upOneLevel;

  /// No description provided for @viewerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{files} files · {size} unpacked'**
  String viewerSubtitle(int files, String size);

  /// No description provided for @encodingLabel.
  ///
  /// In en, this message translates to:
  /// **'Encoding'**
  String get encodingLabel;

  /// No description provided for @encodingAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto (UTF-8)'**
  String get encodingAuto;

  /// No description provided for @encodingCp949.
  ///
  /// In en, this message translates to:
  /// **'CP949 (Korean)'**
  String get encodingCp949;

  /// No description provided for @encodingShiftJis.
  ///
  /// In en, this message translates to:
  /// **'Shift-JIS (Japanese)'**
  String get encodingShiftJis;

  /// No description provided for @encodingGbk.
  ///
  /// In en, this message translates to:
  /// **'GBK (Chinese)'**
  String get encodingGbk;

  /// No description provided for @encodingBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'File names look garbled'**
  String get encodingBannerTitle;

  /// No description provided for @encodingBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get encodingBannerAction;

  /// No description provided for @extractAll.
  ///
  /// In en, this message translates to:
  /// **'Extract all'**
  String get extractAll;

  /// No description provided for @extractSelected.
  ///
  /// In en, this message translates to:
  /// **'Extract {count} selected'**
  String extractSelected(int count);

  /// No description provided for @folderEmpty.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty'**
  String get folderEmpty;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get clearSelection;

  /// No description provided for @previewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No preview for this file type. Select it and extract instead.'**
  String get previewUnavailable;

  /// No description provided for @previewTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is too large to preview.'**
  String get previewTooLarge;

  /// No description provided for @previewFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t preview this file.'**
  String get previewFailed;

  /// No description provided for @passwordTitle.
  ///
  /// In en, this message translates to:
  /// **'Password required'**
  String get passwordTitle;

  /// No description provided for @passwordWrong.
  ///
  /// In en, this message translates to:
  /// **'Wrong password. Try again.'**
  String get passwordWrong;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @unlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get unlock;

  /// No description provided for @unsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'{format} isn’t supported in this build'**
  String unsupportedTitle(String format);

  /// No description provided for @unsupportedBody.
  ///
  /// In en, this message translates to:
  /// **'This build handles ZIP, TAR, GZ, BZ2 and XZ. RAR, 7Z, ISO and CAB need the native engine (libarchive + UnRAR), which is not bundled yet.'**
  String get unsupportedBody;

  /// No description provided for @corruptTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t open this archive'**
  String get corruptTitle;

  /// No description provided for @encryptedBadge.
  ///
  /// In en, this message translates to:
  /// **'Encrypted'**
  String get encryptedBadge;

  /// No description provided for @extractTitle.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get extractTitle;

  /// No description provided for @destination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get destination;

  /// No description provided for @destNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder (recommended)'**
  String get destNewFolder;

  /// No description provided for @destSameFolder.
  ///
  /// In en, this message translates to:
  /// **'Same folder as the archive'**
  String get destSameFolder;

  /// No description provided for @destCustom.
  ///
  /// In en, this message translates to:
  /// **'Choose folder…'**
  String get destCustom;

  /// No description provided for @destFallbackNote.
  ///
  /// In en, this message translates to:
  /// **'The archive’s folder isn’t writable, so files go to ZipFast’s storage instead.'**
  String get destFallbackNote;

  /// No description provided for @ifFileExists.
  ///
  /// In en, this message translates to:
  /// **'If a file already exists'**
  String get ifFileExists;

  /// No description provided for @conflictSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get conflictSkip;

  /// No description provided for @conflictOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get conflictOverwrite;

  /// No description provided for @conflictRename.
  ///
  /// In en, this message translates to:
  /// **'Rename automatically'**
  String get conflictRename;

  /// No description provided for @extractButton.
  ///
  /// In en, this message translates to:
  /// **'Extract'**
  String get extractButton;

  /// No description provided for @extracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting…'**
  String get extracting;

  /// No description provided for @extractDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Extraction complete'**
  String get extractDoneTitle;

  /// No description provided for @extractedSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} files extracted to\n{path}'**
  String extractedSummary(int count, String path);

  /// No description provided for @blockedWarning.
  ///
  /// In en, this message translates to:
  /// **'{count} unsafe entries were blocked (path traversal).'**
  String blockedWarning(int count);

  /// No description provided for @skippedNote.
  ///
  /// In en, this message translates to:
  /// **'{count} entries skipped.'**
  String skippedNote(int count);

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy path'**
  String get copyPath;

  /// No description provided for @pathCopied.
  ///
  /// In en, this message translates to:
  /// **'Path copied'**
  String get pathCopied;

  /// No description provided for @createTitle.
  ///
  /// In en, this message translates to:
  /// **'Create archive'**
  String get createTitle;

  /// No description provided for @archiveName.
  ///
  /// In en, this message translates to:
  /// **'Archive name'**
  String get archiveName;

  /// No description provided for @format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get format;

  /// No description provided for @compression.
  ///
  /// In en, this message translates to:
  /// **'Compression'**
  String get compression;

  /// No description provided for @levelStore.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get levelStore;

  /// No description provided for @levelFast.
  ///
  /// In en, this message translates to:
  /// **'Fast'**
  String get levelFast;

  /// No description provided for @levelNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get levelNormal;

  /// No description provided for @levelMaximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get levelMaximum;

  /// No description provided for @passwordProtect.
  ///
  /// In en, this message translates to:
  /// **'Password lock (AES-256)'**
  String get passwordProtect;

  /// No description provided for @passwordProtectSub.
  ///
  /// In en, this message translates to:
  /// **'ZIP only'**
  String get passwordProtectSub;

  /// No description provided for @splitArchive.
  ///
  /// In en, this message translates to:
  /// **'Split archive'**
  String get splitArchive;

  /// No description provided for @splitArchiveSub.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get splitArchiveSub;

  /// No description provided for @proFeature.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get proFeature;

  /// No description provided for @createButton.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createButton;

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating archive…'**
  String get creating;

  /// No description provided for @createdTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive created'**
  String get createdTitle;

  /// No description provided for @createdSummary.
  ///
  /// In en, this message translates to:
  /// **'Saved to\n{path}'**
  String createdSummary(String path);

  /// No description provided for @noFilesSelected.
  ///
  /// In en, this message translates to:
  /// **'No files selected'**
  String get noFilesSelected;

  /// No description provided for @filesSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} items selected'**
  String filesSelected(int count);

  /// No description provided for @pickFiles.
  ///
  /// In en, this message translates to:
  /// **'Pick files'**
  String get pickFiles;

  /// No description provided for @proTitle.
  ///
  /// In en, this message translates to:
  /// **'ZipFast Pro'**
  String get proTitle;

  /// No description provided for @proIntro.
  ///
  /// In en, this message translates to:
  /// **'One-time purchase. Extraction of every format stays free.'**
  String get proIntro;

  /// No description provided for @proFeatureAds.
  ///
  /// In en, this message translates to:
  /// **'Remove all ads'**
  String get proFeatureAds;

  /// No description provided for @proFeatureAes.
  ///
  /// In en, this message translates to:
  /// **'AES-256 encrypted archives'**
  String get proFeatureAes;

  /// No description provided for @proFeatureSplit.
  ///
  /// In en, this message translates to:
  /// **'Split archives'**
  String get proFeatureSplit;

  /// No description provided for @proFeatureBatch.
  ///
  /// In en, this message translates to:
  /// **'Batch extraction & password favorites'**
  String get proFeatureBatch;

  /// No description provided for @proUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Purchases aren’t available in this build yet.'**
  String get proUnavailable;

  /// No description provided for @proDebugUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock (debug build)'**
  String get proDebugUnlock;

  /// No description provided for @proDebugLock.
  ///
  /// In en, this message translates to:
  /// **'Lock again (debug build)'**
  String get proDebugLock;

  /// No description provided for @proActive.
  ///
  /// In en, this message translates to:
  /// **'Pro is active'**
  String get proActive;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @defaultConflict.
  ///
  /// In en, this message translates to:
  /// **'Default for existing files'**
  String get defaultConflict;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear preview cache'**
  String get clearCache;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @licenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get licenses;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'100% offline. Your files never leave this device.'**
  String get privacy;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(String version);

  /// No description provided for @genericError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {message}'**
  String genericError(String message);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
