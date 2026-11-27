import 'dart:convert';

import 'legacy_tables.g.dart';

/// Decode-only [Encoding] for legacy double-byte code pages (CP949, CP932 /
/// Shift-JIS, GBK). Used to repair mojibake in archive entry names created on
/// Windows machines with a non-UTF-8 system locale.
///
/// Decoding throws a [FormatException] on invalid byte sequences so callers
/// can fall back to another encoding.
class LegacyEncoding extends Encoding {
  const LegacyEncoding._(this.name, this._kind);

  static const cp949 = LegacyEncoding._('cp949', _Kind.cp949);
  static const shiftJis = LegacyEncoding._('shift_jis', _Kind.cp932);
  static const gbk = LegacyEncoding._('gbk', _Kind.gbk);

  @override
  final String name;
  final _Kind _kind;

  @override
  Converter<List<int>, String> get decoder => _LegacyDecoder(_kind);

  @override
  Converter<String, List<int>> get encoder =>
      throw UnsupportedError('$name is decode-only');
}

enum _Kind { cp949, cp932, gbk }

class _LegacyDecoder extends Converter<List<int>, String> {
  const _LegacyDecoder(this.kind);
  final _Kind kind;

  @override
  String convert(List<int> input) {
    final out = StringBuffer();
    var i = 0;
    while (i < input.length) {
      final b = input[i];
      if (b < 0x80) {
        out.writeCharCode(b);
        i++;
        continue;
      }
      if (kind == _Kind.cp932 && b >= 0xA1 && b <= 0xDF) {
        out.writeCharCode(0xFF61 + (b - 0xA1)); // half-width katakana
        i++;
        continue;
      }
      if (i + 1 >= input.length) {
        throw FormatException('Truncated ${kind.name} sequence', input, i);
      }
      final t = input[i + 1];
      final ch = _lookup(b, t);
      if (ch == null) {
        throw FormatException('Invalid ${kind.name} sequence', input, i);
      }
      out.writeCharCode(ch);
      i += 2;
    }
    return out.toString();
  }

  int? _lookup(int lead, int trail) {
    final int leadMin, leadMax, trailMin, trailMax;
    final String table;
    switch (kind) {
      case _Kind.cp949:
        leadMin = cp949LeadMin;
        leadMax = cp949LeadMax;
        trailMin = cp949TrailMin;
        trailMax = cp949TrailMax;
        table = cp949Table;
      case _Kind.cp932:
        leadMin = cp932LeadMin;
        leadMax = cp932LeadMax;
        trailMin = cp932TrailMin;
        trailMax = cp932TrailMax;
        table = cp932Table;
      case _Kind.gbk:
        leadMin = gbkLeadMin;
        leadMax = gbkLeadMax;
        trailMin = gbkTrailMin;
        trailMax = gbkTrailMax;
        table = gbkTable;
    }
    if (lead < leadMin || lead > leadMax) return null;
    if (trail < trailMin || trail > trailMax) return null;
    final span = trailMax - trailMin + 1;
    final code = table.codeUnitAt((lead - leadMin) * span + (trail - trailMin));
    return code == 0xFFFD ? null : code;
  }
}
