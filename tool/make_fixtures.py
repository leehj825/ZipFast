#!/usr/bin/env python3
"""Builds raw ZIP fixtures (stored, no UTF-8 flag) for encoding / Zip Slip tests."""
import os, struct, zlib

def build(entries):
    """entries: list of (name_bytes, data_bytes)"""
    out = bytearray(); central = bytearray()
    for name, data in entries:
        crc = zlib.crc32(data) & 0xffffffff
        off = len(out)
        out += struct.pack('<IHHHHHIIIHH', 0x04034b50, 20, 0, 0, 0, 0x21, crc, len(data), len(data), len(name), 0)
        out += name + data
        central += struct.pack('<IHHHHHHIIIHHHHHII', 0x02014b50, 20, 20, 0, 0, 0, 0x21, crc, len(data), len(data), len(name), 0, 0, 0, 0, 0, off)
        central += name
    cd_off = len(out)
    out += central
    out += struct.pack('<IHHHHIIH', 0x06054b50, 0, 0, len(entries), len(entries), len(central), cd_off, 0)
    return bytes(out)

here = os.path.join(os.path.dirname(__file__), '..', 'test', 'fixtures')
def w(name, entries):
    with open(os.path.join(here, name), 'wb') as f:
        f.write(build(entries))

w('korean_cp949.zip', [('한글폴더/문서.txt'.encode('cp949'), b'hello korean')])
w('japanese_sjis.zip', [('日本語/テスト.txt'.encode('cp932'), b'hello japanese')])
w('chinese_gbk.zip', [('中文/测试.txt'.encode('gbk'), b'hello chinese')])
w('zip_slip.zip', [
    (b'../evil.txt', b'evil'),
    (b'..\\evil2.txt', b'evil'),
    (b'/abs_evil.txt', b'evil'),
    (b'good/../../evil3.txt', b'evil'),
    (b'good/ok.txt', b'fine'),
])
