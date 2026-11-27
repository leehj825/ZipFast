#!/usr/bin/env python3
"""Generates lib/encoding/legacy_tables.g.dart (double-byte decode tables).

Run: python3 tool/gen_legacy_tables.py
Each table is a string indexed by (lead - leadMin) * span + (trail - trailMin);
U+FFFD marks an unmapped code point.
"""
import os

SPECS = {
    # name: (python codec, lead range, trail range)
    'cp949': ('cp949', (0x81, 0xFE), (0x41, 0xFE)),
    'cp932': ('cp932', (0x81, 0xFC), (0x40, 0xFC)),
    'gbk': ('gbk', (0x81, 0xFE), (0x40, 0xFE)),
}


def esc(ch):
    if ch in "\\'$":
        return '\\' + ch
    o = ord(ch)
    if o < 0x20 or 0xD800 <= o <= 0xDFFF or o == 0x7F:
        return '\\u{%x}' % o
    return ch


out = ['// GENERATED FILE - DO NOT EDIT. See tool/gen_legacy_tables.py.', '']
for name, (codec, (l0, l1), (t0, t1)) in SPECS.items():
    span = t1 - t0 + 1
    chars = []
    for lead in range(l0, l1 + 1):
        for trail in range(t0, t1 + 1):
            try:
                s = bytes([lead, trail]).decode(codec)
                chars.append(s if len(s) == 1 else '�')
            except UnicodeDecodeError:
                chars.append('�')
    out.append('const int %sLeadMin = %d;' % (name, l0))
    out.append('const int %sLeadMax = %d;' % (name, l1))
    out.append('const int %sTrailMin = %d;' % (name, t0))
    out.append('const int %sTrailMax = %d;' % (name, t1))
    out.append('const String %sTable =' % name)
    row = 64
    lines = []
    for i in range(0, len(chars), row):
        lines.append("    '" + ''.join(esc(c) for c in chars[i:i + row]) + "'")
    out.append('\n'.join(lines) + ';')
    out.append('')

path = os.path.join(os.path.dirname(__file__), '..', 'lib', 'encoding', 'legacy_tables.g.dart')
with open(path, 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
print('wrote', os.path.normpath(path), os.path.getsize(path), 'bytes')
