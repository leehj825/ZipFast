import 'dart:io';

/// Archive container formats ZipFast knows about.
enum ArchiveFormat {
  zip('ZIP'),
  sevenZip('7Z'),
  rar('RAR'),
  tar('TAR'),
  tarGz('TAR.GZ'),
  tarBz2('TAR.BZ2'),
  tarXz('TAR.XZ'),
  gz('GZ'),
  bz2('BZ2'),
  xz('XZ'),
  iso('ISO'),
  cab('CAB'),
  unknown('?');

  const ArchiveFormat(this.label);

  /// Short badge text, e.g. `ZIP`.
  final String label;

  /// Detects a format from the file name only.
  static ArchiveFormat fromName(String fileName) {
    final n = fileName.toLowerCase();
    bool ends(String s) => n.endsWith(s);
    if (ends('.tar.gz') || ends('.tgz')) return tarGz;
    if (ends('.tar.bz2') || ends('.tbz2') || ends('.tbz')) return tarBz2;
    if (ends('.tar.xz') || ends('.txz')) return tarXz;
    if (ends('.tar')) return tar;
    if (ends('.zip') ||
        ends('.apk') ||
        ends('.jar') ||
        ends('.aab') ||
        ends('.epub') ||
        RegExp(r'\.z\d\d$').hasMatch(n)) {
      return zip;
    }
    if (ends('.7z') || RegExp(r'\.7z\.\d{3}$').hasMatch(n)) return sevenZip;
    if (ends('.rar') || RegExp(r'\.r\d\d$').hasMatch(n)) return rar;
    if (ends('.gz')) return gz;
    if (ends('.bz2')) return bz2;
    if (ends('.xz')) return xz;
    if (ends('.iso')) return iso;
    if (ends('.cab')) return cab;
    return unknown;
  }

  /// Detects a format from the file's leading bytes (magic numbers), falling
  /// back to the file name. Tar variants are told apart by the name because the
  /// compression wrapper hides the inner container.
  static Future<ArchiveFormat> detect(String path) async {
    final byName = fromName(path.split(RegExp(r'[\\/]')).last);
    RandomAccessFile? raf;
    try {
      raf = await File(path).open();
      final head = await raf.read(8);
      bool starts(List<int> m) {
        if (head.length < m.length) return false;
        for (var i = 0; i < m.length; i++) {
          if (head[i] != m[i]) return false;
        }
        return true;
      }

      if (starts([0x50, 0x4B, 0x03, 0x04]) || starts([0x50, 0x4B, 0x05, 0x06])) {
        return zip;
      }
      if (starts([0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C])) return sevenZip;
      if (starts([0x52, 0x61, 0x72, 0x21, 0x1A, 0x07])) return rar;
      if (starts([0x4D, 0x53, 0x43, 0x46])) return cab;
      if (starts([0x1F, 0x8B])) {
        return byName == tarGz ? tarGz : gz;
      }
      if (starts([0x42, 0x5A, 0x68])) {
        return byName == tarBz2 ? tarBz2 : bz2;
      }
      if (starts([0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00])) {
        return byName == tarXz ? tarXz : xz;
      }
      final length = await raf.length();
      if (length > 262) {
        await raf.setPosition(257);
        final magic = await raf.read(5);
        if (String.fromCharCodes(magic) == 'ustar') return tar;
      }
      if (length > 0x8006) {
        await raf.setPosition(0x8001);
        final magic = await raf.read(5);
        if (String.fromCharCodes(magic) == 'CD001') return iso;
      }
    } catch (_) {
      // Fall through to the name-based guess.
    } finally {
      await raf?.close();
    }
    return byName;
  }

  /// Whether the file name looks like an archive we should list on the home
  /// screen.
  static bool looksLikeArchive(String fileName) =>
      fromName(fileName) != unknown;

  bool get isTarFamily =>
      this == tar || this == tarGz || this == tarBz2 || this == tarXz;
}
