import 'package:material_ui/material_ui.dart';

import 'archive_format.dart';

/// Brand colors from the design spec.
class ZipFastColors {
  static const primary = Color(0xFF4F46E5); // deep indigo
  static const lightBackground = Color(0xFFF8FAFC);
  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);

  static const zipBlue = Color(0xFF2563EB);
  static const rarPurple = Color(0xFF7C3AED);
  static const sevenZipTeal = Color(0xFF0D9488);
  static const lockAmber = Color(0xFFF59E0B);

  /// Badge color per format.
  static Color forFormat(ArchiveFormat f) => switch (f) {
        ArchiveFormat.zip => zipBlue,
        ArchiveFormat.rar => rarPurple,
        ArchiveFormat.sevenZip => sevenZipTeal,
        ArchiveFormat.iso || ArchiveFormat.cab => const Color(0xFFEA580C),
        ArchiveFormat.unknown => const Color(0xFF64748B),
        _ => const Color(0xFF475569), // tar / gz / bz2 / xz family
      };
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: ZipFastColors.primary,
    brightness: brightness,
  ).copyWith(primary: dark ? const Color(0xFF818CF8) : ZipFastColors.primary);
  final background =
      dark ? ZipFastColors.darkBackground : ZipFastColors.lightBackground;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: dark ? ZipFastColors.darkSurface : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: dark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? ZipFastColors.darkSurface : Colors.white,
      showDragHandle: true,
    ),
  );
}
