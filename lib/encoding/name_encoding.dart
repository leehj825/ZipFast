import 'dart:convert';

import 'legacy_codecs.dart';

/// Character encodings the user can pick to repair broken entry names.
enum NameEncoding {
  /// UTF-8 first, then the classic CP437 fallback (archive package default).
  auto('Auto (UTF-8)'),
  utf8('UTF-8'),
  cp949('CP949 (Korean)'),
  shiftJis('Shift-JIS (Japanese)'),
  gbk('GBK (Chinese)');

  const NameEncoding(this.label);

  /// Label shown in the encoding chip.
  final String label;

  /// Codec to hand to the zip decoder, or `null` to use its default.
  Encoding? get codec => switch (this) {
        NameEncoding.auto => null,
        NameEncoding.utf8 => const Utf8Codec(allowMalformed: false),
        NameEncoding.cp949 => LegacyEncoding.cp949,
        NameEncoding.shiftJis => LegacyEncoding.shiftJis,
        NameEncoding.gbk => LegacyEncoding.gbk,
      };

  /// Heuristic: names that went through the CP437 fallback show box-drawing,
  /// Greek or replacement characters. Used to offer the repair banner.
  static bool looksGarbled(Iterable<String> names) {
    for (final name in names) {
      for (final r in name.runes) {
        if (r == 0xFFFD ||
            (r >= 0x2500 && r <= 0x25FF) ||
            (r >= 0x0370 && r <= 0x03FF) ||
            (r >= 0x2190 && r <= 0x22FF)) {
          return true;
        }
      }
    }
    return false;
  }
}
