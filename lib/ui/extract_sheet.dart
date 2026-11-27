// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../encoding/name_encoding.dart';
import '../engine/archive_engine.dart';
import '../engine/models.dart';
import '../engine/safe_path.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/app_state.dart';
import '../state/storage_service.dart';
import 'widgets/job_dialog.dart';

enum _Destination { newFolder, sameFolder, custom }

/// Bottom sheet with extraction options, followed by the progress dialog.
Future<void> showExtractSheet(
  BuildContext context, {
  required String archivePath,
  required ArchiveListing listing,
  required Set<String>? selected,
  required NameEncoding encoding,
  String? password,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ExtractSheet(
      archivePath: archivePath,
      listing: listing,
      selected: selected,
      encoding: encoding,
      password: password,
      parentContext: context,
    ),
  );
}

class _ExtractSheet extends StatefulWidget {
  const _ExtractSheet({
    required this.archivePath,
    required this.listing,
    required this.selected,
    required this.encoding,
    required this.password,
    required this.parentContext,
  });

  final String archivePath;
  final ArchiveListing listing;
  final Set<String>? selected;
  final NameEncoding encoding;
  final String? password;
  final BuildContext parentContext;

  @override
  State<_ExtractSheet> createState() => _ExtractSheetState();
}

class _ExtractSheetState extends State<_ExtractSheet> {
  _Destination _dest = _Destination.newFolder;
  String? _customDir;
  late ConflictPolicy _conflict = context.read<AppState>().defaultConflict;
  late final TextEditingController _password =
      TextEditingController(text: widget.password ?? '');
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickCustom() async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir != null) setState(() => _customDir = dir);
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final storage = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(widget.parentContext);
    final navigator = Navigator.of(context);
    final parentContext = widget.parentContext;

    final baseName = archiveBaseName(p.basename(widget.archivePath));
    String destination;
    var fellBack = false;
    switch (_dest) {
      case _Destination.newFolder:
        final r = storage.extractParentFor(widget.archivePath);
        fellBack = r.usedFallback;
        destination = uniquePath(p.join(r.parent, baseName),
            (s) => _exists(s));
      case _Destination.sameFolder:
        final r = storage.extractParentFor(widget.archivePath);
        fellBack = r.usedFallback;
        destination = fellBack ? p.join(r.parent, baseName) : r.parent;
      case _Destination.custom:
        final dir = _customDir;
        if (dir != null && StorageService.isWritable(dir)) {
          destination = dir;
        } else {
          destination = p.join(storage.fallbackExtractRoot, baseName);
          fellBack = true;
        }
    }

    final request = ExtractRequest(
      archivePath: widget.archivePath,
      format: widget.listing.format,
      destinationDir: destination,
      selectedPaths: widget.selected,
      password: _password.text.isEmpty ? null : _password.text,
      encoding: widget.encoding,
      conflictPolicy: _conflict,
      tempDir: storage.tempDir,
    );
    navigator.pop();
    if (fellBack) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.destFallbackNote)));
    }
    final handle = const DartArchiveEngine().extract(request);
    await showJobDialog<ExtractResult>(
      parentContext,
      handle,
      title: l10n.extracting,
      doneTitle: l10n.extractDoneTitle,
      doneBuilder: (ctx, result) => _ExtractSummary(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    Widget radio(_Destination value, String label, {Widget? trailing}) {
      return RadioListTile<_Destination>(
        value: value,
        title: Text(label),
        subtitle: trailing,
        contentPadding: EdgeInsets.zero,
        dense: true,
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.extractTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(l10n.destination, style: theme.textTheme.labelLarge),
              RadioGroup<_Destination>(
                groupValue: _dest,
                onChanged: (v) {
                  setState(() => _dest = v!);
                  if (v == _Destination.custom && _customDir == null) _pickCustom();
                },
                child: Column(children: [
                  radio(_Destination.newFolder, l10n.destNewFolder),
                  radio(_Destination.sameFolder, l10n.destSameFolder),
                  radio(
                    _Destination.custom,
                    l10n.destCustom,
                    trailing: _customDir == null ? null : Text(_customDir!),
                  ),
                ]),
              ),
              if (widget.listing.hasEncrypted) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  autofocus: _password.text.isEmpty,
                  decoration: InputDecoration(
                    labelText: l10n.passwordHint,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(l10n.ifFileExists, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<ConflictPolicy>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: ConflictPolicy.skip, label: Text(l10n.conflictSkip)),
                  ButtonSegment(value: ConflictPolicy.overwrite, label: Text(l10n.conflictOverwrite)),
                  ButtonSegment(value: ConflictPolicy.rename, label: Text(l10n.conflictRename)),
                ],
                selected: {_conflict},
                onSelectionChanged: (s) => setState(() => _conflict = s.first),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _start, child: Text(l10n.extractButton)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _exists(String path) =>
    FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.notFound;

class _ExtractSummary extends StatelessWidget {
  const _ExtractSummary({required this.result});
  final ExtractResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.extractedSummary(result.extracted, result.destinationDir)),
        if (result.blocked > 0) ...[
          const SizedBox(height: 8),
          Text(l10n.blockedWarning(result.blocked),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        if (result.skipped > 0) ...[
          const SizedBox(height: 8),
          Text(l10n.skippedNote(result.skipped)),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: result.destinationDir));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(l10n.pathCopied)));
            }
          },
          icon: const Icon(Icons.copy, size: 18),
          label: Text(l10n.copyPath),
        ),
      ],
    );
  }
}
