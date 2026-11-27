import 'package:path/path.dart' as p;

/// Normalizes an archive entry name: forward slashes, no leading `./`, no
/// trailing slash. Returns an empty string for names that normalize to nothing.
String normalizeEntryName(String raw) {
  var s = raw.replaceAll('\\', '/');
  while (s.startsWith('./')) {
    s = s.substring(2);
  }
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Resolves [entryName] below [root], or returns `null` when the result would
/// escape [root] (Zip Slip / path traversal).
///
/// Rejected: absolute paths, Windows drive prefixes, `..` segments that climb
/// out of the root, NUL bytes.
String? resolveSafePath(String root, String entryName) {
  final name = normalizeEntryName(entryName);
  if (name.isEmpty || name.contains('\u0000')) return null;
  if (name.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(name)) {
    return null;
  }
  final context = p.posix;
  final normalizedRoot = context.normalize(root);
  final target = context.normalize(context.join(normalizedRoot, name));
  if (target == normalizedRoot) return null;
  if (!context.isWithin(normalizedRoot, target)) return null;
  return target;
}

/// Returns a path that does not exist yet by appending ` (1)`, ` (2)`, ... to
/// the base name. [exists] is injected for testability.
String uniquePath(String path, bool Function(String) exists) {
  if (!exists(path)) return path;
  final dir = p.dirname(path);
  final base = p.basenameWithoutExtension(path);
  final ext = p.extension(path);
  var i = 1;
  while (true) {
    final candidate = p.join(dir, '$base ($i)$ext');
    if (!exists(candidate)) return candidate;
    i++;
  }
}

/// Whether [path] is covered by [selected]: the path itself or any of its
/// parent folders is in the set. A `null` selection covers everything.
bool isPathSelected(String path, Set<String>? selected) {
  if (selected == null) return true;
  if (selected.contains(path)) return true;
  var i = path.lastIndexOf('/');
  while (i > 0) {
    if (selected.contains(path.substring(0, i))) return true;
    i = path.lastIndexOf('/', i - 1);
  }
  return false;
}

/// Folder name to extract into: the archive file name without its archive
/// extension(s), e.g. `photos.tar.gz` -> `photos`.
String archiveBaseName(String fileName) {
  final lower = fileName.toLowerCase();
  const multi = ['.tar.gz', '.tar.bz2', '.tar.xz'];
  for (final ext in multi) {
    if (lower.endsWith(ext)) return fileName.substring(0, fileName.length - ext.length);
  }
  final stripped = fileName
      .replaceAll(RegExp(r'\.part\d+\.rar$', caseSensitive: false), '')
      .replaceAll(RegExp(r'\.7z\.\d{3}$', caseSensitive: false), '');
  if (stripped != fileName) return stripped;
  final dot = fileName.lastIndexOf('.');
  return dot > 0 ? fileName.substring(0, dot) : fileName;
}
