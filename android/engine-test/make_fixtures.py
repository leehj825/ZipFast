#!/usr/bin/env python3
"""Builds archive fixtures for the host-side ArchiveBridge tests.

Needs: pip install py7zr pycdlib. RAR and CAB are hand-written ("stored", no
compression) because no free tool can create RAR; 7-Zip reads them like any other.
"""
import os, struct, zlib, random, shutil, io

here = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fixtures')
shutil.rmtree(here, ignore_errors=True)
os.makedirs(here)

HELLO = b'hello from ZipFast\n'
rnd = random.Random(7)
BIG = bytes(rnd.getrandbits(8) for _ in range(30000))  # incompressible -> splits are real

def w(name, data):
    with open(os.path.join(here, name), 'wb') as f:
        f.write(data)

# ---- 7z (plain, encrypted, split) -------------------------------------------
import py7zr
def make7z(name, password=None):
    path = os.path.join(here, name)
    with py7zr.SevenZipFile(path, 'w', password=password, header_encryption=bool(password)) as z:
        z.writestr(HELLO, 'docs/hello.txt')
        z.writestr(BIG, 'data/big.bin')
        z.writestr(b'x', 'a.txt')
    return path
plain = make7z('plain.7z')
make7z('secret.7z', password='pw123')
data = open(plain, 'rb').read()
part = 12000
for i in range(0, len(data), part):
    w('split.7z.%03d' % (i // part + 1), data[i:i + part])
assert len(data) > part * 2, len(data)

# ---- ISO --------------------------------------------------------------------
import pycdlib
iso = pycdlib.PyCdlib()
iso.new(interchange_level=3, joliet=3)
iso.add_directory('/DOCS', joliet_path='/docs')
iso.add_fp(io.BytesIO(HELLO), len(HELLO), '/DOCS/HELLO.TXT;1', joliet_path='/docs/hello.txt')
buf = io.BytesIO(); iso.write_fp(buf); iso.close()
w('test.iso', buf.getvalue())

# ---- CAB (stored) -----------------------------------------------------------
def make_cab(files):
    blob = b''.join(d for _, d in files)
    names = [(n.encode(), d) for n, d in files]
    cffiles = b''; off = 0
    for n, d in names:
        cffiles += struct.pack('<IIHHHH', len(d), off, 0, 0x5A21, 0x6000, 0x20) + n + b'\0'
        off += len(d)
    coff_files = 36 + 8
    coff_data = coff_files + len(cffiles)
    folder = struct.pack('<IHH', coff_data, 1, 0)
    cfdata = struct.pack('<IHH', 0, len(blob), len(blob)) + blob
    total = coff_data + len(cfdata)
    header = b'MSCF' + struct.pack('<IIIIIBBHHHHH', 0, total, 0, coff_files, 0, 3, 1, 1, len(files), 0, 1, 0)
    return header + folder + cffiles + cfdata
w('test.cab', make_cab([('hello.txt', HELLO), ('b.txt', b'second file')]))

# ---- RAR4 stored ------------------------------------------------------------
def rar4(files):
    out = b'Rar!\x1a\x07\x00'
    body = struct.pack('<BHH', 0x73, 0, 13) + struct.pack('<HI', 0, 0)
    out += struct.pack('<H', zlib.crc32(body) & 0xffff) + body
    for name, data in files:
        n = name.encode()
        hdr = struct.pack('<BHH', 0x74, 0x8000, 32 + len(n)) + struct.pack(
            '<IIBIIBBHI', len(data), len(data), 2, zlib.crc32(data) & 0xffffffff, 0x5A216000, 20, 0x30, len(n), 0x20) + n
        out += struct.pack('<H', zlib.crc32(hdr) & 0xffff) + hdr + data
    out += bytes.fromhex('c43d7b00400700')
    return out
w('test4.rar', rar4([('docs/hello.txt', HELLO), ('a.txt', b'x')]))

# ---- RAR5 stored ------------------------------------------------------------
def vint(n):
    b = bytearray()
    while True:
        c = n & 0x7f; n >>= 7
        b.append(c | (0x80 if n else 0))
        if not n: return bytes(b)
def block(payload):
    hs = vint(len(payload))
    return struct.pack('<I', zlib.crc32(hs + payload) & 0xffffffff) + hs + payload
def rar5(files):
    out = b'Rar!\x1a\x07\x01\x00'
    out += block(vint(1) + vint(0) + vint(0))  # main header
    for name, data in files:
        n = name.encode()
        p = (vint(2) + vint(2) + vint(len(data)) +      # type=file, flags=has data, data size
             vint(4) + vint(len(data)) + vint(0x20) +     # file flags=crc32, unpacked size, attrs
             struct.pack('<I', zlib.crc32(data) & 0xffffffff) +
             vint(0) + vint(1) + vint(len(n)) + n)        # comp info (store), host os, name
        out += block(p) + data
    out += block(vint(5) + vint(0) + vint(0))  # end of archive
    return out
w('test5.rar', rar5([('docs/hello.txt', HELLO), ('a.txt', b'x')]))

# Archives that try to escape the destination (7z can't be made by py7zr with ../, use rar4).
w('slip.rar', rar4([('../evil.txt', b'evil'), ('ok/fine.txt', b'fine')]))
print('fixtures:', sorted(os.listdir(here)))
