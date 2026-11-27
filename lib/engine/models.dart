import '../core/archive_format.dart';
import '../encoding/name_encoding.dart';

/// One file or folder inside an archive.
class EntryInfo {
  const EntryInfo({
    required this.path,
    required this.isDirectory,
    required this.size,
    this.modified,
    this.encrypted = false,
  });

  /// Normalized, forward-slash path inside the archive (no trailing slash).
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final bool encrypted;

  String get name => path.split('/').last;
}

/// Result of listing an archive.
class ArchiveListing {
  const ArchiveListing({
    required this.format,
    required this.entries,
    required this.namesLookGarbled,
  });

  final ArchiveFormat format;
  final List<EntryInfo> entries;

  /// True when the decoded names contain characters typical for a wrong
  /// encoding guess, so the UI can offer the repair banner.
  final bool namesLookGarbled;

  int get fileCount => entries.where((e) => !e.isDirectory).length;
  int get totalSize => entries.fold(0, (sum, e) => sum + e.size);
  bool get hasEncrypted => entries.any((e) => e.encrypted);
}

/// What to do when an output file already exists.
enum ConflictPolicy { skip, overwrite, rename }

class ExtractRequest {
  const ExtractRequest({
    required this.archivePath,
    required this.format,
    required this.destinationDir,
    this.selectedPaths,
    this.password,
    this.encoding = NameEncoding.auto,
    this.conflictPolicy = ConflictPolicy.rename,
    this.tempDir = '',
  });

  final String archivePath;
  final ArchiveFormat format;
  final String destinationDir;

  /// Entry paths to extract; `null` extracts everything. Selecting a folder
  /// includes everything below it.
  final Set<String>? selectedPaths;
  final String? password;
  final NameEncoding encoding;
  final ConflictPolicy conflictPolicy;

  /// Scratch directory for decompressing tar wrappers.
  final String tempDir;
}

class ExtractResult {
  const ExtractResult({
    required this.destinationDir,
    required this.extracted,
    required this.skipped,
    required this.blocked,
  });

  final String destinationDir;
  final int extracted;

  /// Entries skipped because of [ConflictPolicy.skip] or unsupported types.
  final int skipped;

  /// Entries rejected by the Zip Slip / path traversal check.
  final int blocked;
}

/// Progress update from a running job.
class JobProgress {
  const JobProgress(this.done, this.total, [this.current]);
  final int done;
  final int total;
  final String? current;

  double? get fraction => total <= 0 ? null : (done / total).clamp(0.0, 1.0);
}

enum CreateFormat { zip, tarGz }

enum CompressionLevel { store, fast, normal, maximum }

class CreateRequest {
  const CreateRequest({
    required this.sourcePaths,
    required this.outputPath,
    this.format = CreateFormat.zip,
    this.level = CompressionLevel.normal,
    this.password,
    this.tempDir = '',
  });

  final List<String> sourcePaths;
  final String outputPath;
  final CreateFormat format;
  final CompressionLevel level;

  /// AES-256 password (ZIP only).
  final String? password;
  final String tempDir;
}

// ---- Errors ---------------------------------------------------------------

abstract class ZipFastException implements Exception {
  const ZipFastException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// The archive is encrypted and no password was supplied.
class PasswordRequiredException extends ZipFastException {
  const PasswordRequiredException() : super('Password required');
}

/// A password was supplied but did not work.
class WrongPasswordException extends ZipFastException {
  const WrongPasswordException() : super('Wrong password');
}

/// The format needs an engine that is not available.
class UnsupportedFormatException extends ZipFastException {
  const UnsupportedFormatException(this.format)
      : super('Unsupported format');
  final ArchiveFormat format;
}

class CorruptArchiveException extends ZipFastException {
  const CorruptArchiveException(super.message);
}

class JobCancelledException extends ZipFastException {
  const JobCancelledException() : super('Cancelled');
}
