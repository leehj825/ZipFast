// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => 'ZipFast';

  @override
  String get appTagline => '모든 압축 파일을 오프라인으로. 전면 광고 없이.';

  @override
  String get settings => '설정';

  @override
  String get search => '검색';

  @override
  String get searchHint => '압축 파일 검색';

  @override
  String get cancel => '취소';

  @override
  String get ok => '확인';

  @override
  String get close => '닫기';

  @override
  String get done => '완료';

  @override
  String get retry => '다시 시도';

  @override
  String get delete => '삭제';

  @override
  String get tabRecent => '최근 압축 파일';

  @override
  String get tabBrowse => '파일';

  @override
  String recentArchivesTitle(int count) {
    return '최근 압축 파일 ($count)';
  }

  @override
  String get noRecentTitle => '압축 파일이 없습니다';

  @override
  String get noRecentBody =>
      '“압축 파일 열기”로 파일을 선택하거나, 다른 앱에서 “ZipFast로 열기”를 선택하세요.';

  @override
  String get openArchive => '압축 파일 열기';

  @override
  String get createArchive => '압축하기';

  @override
  String get createArchiveSub => 'ZIP, 7Z, TAR.GZ';

  @override
  String get extractArchive => '압축 풀기';

  @override
  String get extractArchiveSub => 'ZIP, RAR, 7Z, TAR, ISO…';

  @override
  String get encodingFixTitle => '파일명 깨짐 복구';

  @override
  String get encodingFixSub => '한국어·일본어·중국어 파일명을 복구합니다';

  @override
  String get aesSupported => 'AES-256 암호화 지원';

  @override
  String get splitBadge => '분할 압축';

  @override
  String get adBannerPlaceholder => '광고 배너 영역';

  @override
  String modifiedOn(String date) {
    return '수정 $date';
  }

  @override
  String get browseNoAccessTitle => '이 폴더를 열 수 없습니다';

  @override
  String get browseNoAccessBody =>
      '안드로이드는 앱의 파일 접근을 제한합니다. “압축 파일 열기”로 시스템 파일 선택기를 이용하세요.';

  @override
  String get browseEmpty => '폴더가 비어 있습니다';

  @override
  String compressSelected(int count) {
    return '선택한 $count개 압축';
  }

  @override
  String get upOneLevel => '상위 폴더';

  @override
  String viewerSubtitle(int files, String size) {
    return '파일 $files개 · 풀면 $size';
  }

  @override
  String get encodingLabel => '인코딩';

  @override
  String get encodingAuto => '자동 (UTF-8)';

  @override
  String get encodingCp949 => 'CP949 (한국어)';

  @override
  String get encodingShiftJis => 'Shift-JIS (일본어)';

  @override
  String get encodingGbk => 'GBK (중국어)';

  @override
  String get encodingBannerTitle => '파일명이 깨져 보입니다';

  @override
  String get encodingBannerAction => '해결';

  @override
  String get extractAll => '전체 압축 풀기';

  @override
  String extractSelected(int count) {
    return '선택한 $count개만 추출';
  }

  @override
  String get folderEmpty => '폴더가 비어 있습니다';

  @override
  String get selectAll => '전체 선택';

  @override
  String get clearSelection => '선택 해제';

  @override
  String get previewUnavailable => '이 파일 형식은 미리보기를 지원하지 않습니다. 선택 후 추출하세요.';

  @override
  String get previewTooLarge => '파일이 커서 미리볼 수 없습니다.';

  @override
  String get previewFailed => '미리보기에 실패했습니다.';

  @override
  String get passwordTitle => '비밀번호가 필요합니다';

  @override
  String get passwordWrong => '비밀번호가 맞지 않습니다. 다시 입력하세요.';

  @override
  String get passwordHint => '비밀번호';

  @override
  String get showPassword => '비밀번호 보기';

  @override
  String get hidePassword => '비밀번호 숨기기';

  @override
  String get unlock => '잠금 해제';

  @override
  String unsupportedTitle(String format) {
    return '이 빌드에서는 $format 형식을 지원하지 않습니다';
  }

  @override
  String get unsupportedBody => '이 형식은 7-Zip 엔진이 필요하며, 안드로이드 앱에서만 사용할 수 있습니다.';

  @override
  String get corruptTitle => '압축 파일을 열 수 없습니다';

  @override
  String get encryptedBadge => '암호화됨';

  @override
  String get extractTitle => '압축 풀기';

  @override
  String get destination => '저장 위치';

  @override
  String get destNewFolder => '새 폴더에 풀기 (권장)';

  @override
  String get destSameFolder => '현재 폴더에 풀기';

  @override
  String get destCustom => '폴더 직접 지정…';

  @override
  String get destFallbackNote => '압축 파일이 있는 폴더에 쓸 수 없어 ZipFast 저장소에 풉니다.';

  @override
  String get ifFileExists => '같은 이름의 파일이 있을 때';

  @override
  String get conflictSkip => '건너뛰기';

  @override
  String get conflictOverwrite => '덮어쓰기';

  @override
  String get conflictRename => '이름 자동 변경';

  @override
  String get extractButton => '압축 풀기';

  @override
  String get extracting => '압축 푸는 중…';

  @override
  String get extractDoneTitle => '압축 풀기 완료';

  @override
  String extractedSummary(int count, String path) {
    return '파일 $count개를 아래 위치에 풀었습니다\n$path';
  }

  @override
  String blockedWarning(int count) {
    return '안전하지 않은 항목 $count개를 차단했습니다 (경로 조작).';
  }

  @override
  String skippedNote(int count) {
    return '$count개 항목을 건너뛰었습니다.';
  }

  @override
  String get cancelled => '취소되었습니다';

  @override
  String get copyPath => '경로 복사';

  @override
  String get pathCopied => '경로를 복사했습니다';

  @override
  String get createTitle => '압축 만들기';

  @override
  String get archiveName => '압축 파일 이름';

  @override
  String get format => '형식';

  @override
  String get compression => '압축률';

  @override
  String get levelStore => '저장만';

  @override
  String get levelFast => '빠름';

  @override
  String get levelNormal => '보통';

  @override
  String get levelMaximum => '최대';

  @override
  String get passwordProtect => '비밀번호 잠금 (AES-256)';

  @override
  String get passwordProtectSub => 'ZIP, 7Z 전용';

  @override
  String get splitArchive => '분할 압축';

  @override
  String get splitArchiveSub => '볼륨으로 나누기 (.001, .002, …)';

  @override
  String get createButton => '만들기';

  @override
  String get creating => '압축 만드는 중…';

  @override
  String get createdTitle => '압축 파일을 만들었습니다';

  @override
  String createdSummary(String path) {
    return '저장 위치\n$path';
  }

  @override
  String get noFilesSelected => '선택한 파일이 없습니다';

  @override
  String filesSelected(int count) {
    return '$count개 항목 선택됨';
  }

  @override
  String get pickFiles => '파일 선택';

  @override
  String get splitSize => '볼륨 크기';

  @override
  String splitSizeMb(int mb) {
    return '$mb MB';
  }

  @override
  String get splitCustomMb => '직접 입력 (MB)';

  @override
  String get splitTooSmall => '1MB 이상의 크기를 입력하세요.';

  @override
  String get splitVolumesNote => '볼륨 이름은 .001, .002, … 입니다. 풀 때는 .001 파일을 여세요.';

  @override
  String get extractLocation => '기본 압축 해제 폴더';

  @override
  String get extractLocationNextTo => '압축 파일 옆의 새 폴더';

  @override
  String get saveLocation => '새 압축 파일 기본 저장 폴더';

  @override
  String get saveLocationApp => 'ZipFast 저장소';

  @override
  String get chooseFolder => '폴더 선택…';

  @override
  String get resetToDefault => '기본값으로 되돌리기';

  @override
  String get change => '변경';

  @override
  String get saveTo => '저장 위치';

  @override
  String get createSubfolder => '새 폴더에 넣기';

  @override
  String get askEveryTime => '매번 폴더 묻기';

  @override
  String get askEveryTimeSub => '압축을 풀거나 만들 때마다 위치를 선택합니다';

  @override
  String get storageRoot => 'ZipFast 저장소';

  @override
  String get newFolder => '새 폴더';

  @override
  String get folderName => '폴더 이름';

  @override
  String get rename => '이름 변경';

  @override
  String get newName => '새 이름';

  @override
  String get moveTo => '이동…';

  @override
  String get moveHere => '여기로 이동';

  @override
  String get useThisFolder => '이 폴더 사용';

  @override
  String get chooseDestination => '폴더 선택';

  @override
  String get shareAction => '공유';

  @override
  String get shareFoldersNote => '폴더는 공유할 수 없습니다. 먼저 압축하세요.';

  @override
  String get openWith => '다른 앱으로 열기';

  @override
  String get noAppToOpen => '이 파일을 열 수 있는 앱이 없습니다.';

  @override
  String deleteConfirmTitle(int count) {
    return '$count개 항목을 삭제할까요?';
  }

  @override
  String get deleteConfirmBody => '되돌릴 수 없습니다.';

  @override
  String get opNameInvalid => '사용할 수 없는 이름입니다.';

  @override
  String get opNameTaken => '같은 이름이 이미 있습니다.';

  @override
  String get opIntoItself => '폴더를 자기 자신 안으로 옮길 수 없습니다.';

  @override
  String get opFailed => '작업에 실패했습니다.';

  @override
  String get showFiles => '파일 보기';

  @override
  String selectedCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get refresh => '새로고침';

  @override
  String get storageHint =>
      '결과는 ZipFast 자체 폴더에 저장됩니다. 다른 앱에서 쓰려면 파일을 열거나 공유하세요.';

  @override
  String get saveCopyTo => '다른 위치에 저장…';

  @override
  String saveCopyHere(String folder) {
    return '$folder에 저장';
  }

  @override
  String get chooseAnotherFolder => '다른 폴더 선택…';

  @override
  String get copying => '복사하는 중…';

  @override
  String get copyDoneTitle => '복사 완료';

  @override
  String copiedSummary(int count, String folder) {
    return '파일 $count개를 아래 폴더에 복사했습니다\n$folder';
  }

  @override
  String get exportUnavailable => '이 환경에서는 다른 폴더에 저장할 수 없습니다.';

  @override
  String get exportAccessLost => '해당 폴더에 대한 접근이 해제되었습니다. 다시 선택하세요.';

  @override
  String get exportNothing => '복사할 항목이 없습니다.';

  @override
  String get settingsTitle => '설정';

  @override
  String get theme => '테마';

  @override
  String get themeSystem => '시스템';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get language => '언어';

  @override
  String get languageSystem => '시스템 기본값';

  @override
  String get defaultConflict => '기존 파일 처리 기본값';

  @override
  String get clearCache => '미리보기 캐시 삭제';

  @override
  String get cacheCleared => '캐시를 삭제했습니다';

  @override
  String get licenses => '오픈소스 라이선스';

  @override
  String get about => '정보';

  @override
  String get privacy => '100% 오프라인입니다. 파일은 기기 밖으로 전송되지 않습니다.';

  @override
  String version(String version) {
    return '버전 $version';
  }

  @override
  String genericError(String message) {
    return '문제가 발생했습니다: $message';
  }
}
