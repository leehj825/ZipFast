
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../encoding/name_encoding.dart';
import '../engine/composite_engine.dart';
import '../engine/models.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/app_state.dart';
import '../state/destinations.dart';
import '../state/storage_service.dart';
import 'actions.dart';
import 'export_flow.dart';
import 'widgets/job_dialog.dart';

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
  late ExtractTarget _dest =
      _customDir == null ? ExtractTarget.newFolder : ExtractTarget.custom;
  late String? _customDir = context.read<AppState>().extractDir;
  bool _subfolder = true;
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
    final dir = await pickAppFolder(context);
    if (dir != null && mounted) {
      setState(() {
        _customDir = dir;
        _dest = ExtractTarget.custom;
      });
    }
  }

  Future<void> _start() async {
    final l10n = AppLocalizations.of(context);
    final storage = context.read<StorageService>();
    final askEachTime = context.read<AppState>().askEachTime;
    final messenger = ScaffoldMessenger.of(widget.parentContext);
    final navigator = Navigator.of(context);
    final parentContext = widget.parentContext;

    // "Ask every time": choose the folder now.
    var target = _dest;
    var customDir = _customDir;
    if (askEachTime) {
      final dir = await pickAppFolder(context);
      if (dir == null || !mounted) return;
      target = ExtractTarget.custom;
      customDir = dir;
    }
    if (target == ExtractTarget.custom && customDir == null) {
      await _pickCustom();
      if (_customDir == null || !mounted) return;
      customDir = _customDir;
    }

    final resolved = resolveExtractDestination(
      storage,
      target: target,
      archivePath: widget.archivePath,
      customDir: customDir,
      customSubfolder: _subfolder,
    );
    final destination = resolved.path;
    final fellBack = resolved.usedFallback;

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
    if (!parentContext.mounted) return;
    final handle = appEngine.extract(request);
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
    Widget radio(ExtractTarget value, String label, {Widget? trailing}) {
      return RadioListTile<ExtractTarget>(
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
              RadioGroup<ExtractTarget>(
                groupValue: _dest,
                onChanged: (v) {
                  setState(() => _dest = v!);
                  if (v == ExtractTarget.custom && _customDir == null) _pickCustom();
                },
                child: Column(children: [
                  radio(ExtractTarget.newFolder, l10n.destNewFolder),
                  radio(ExtractTarget.sameFolder, l10n.destSameFolder),
                  radio(
                    ExtractTarget.custom,
                    l10n.destCustom,
                    trailing: _customDir == null ? null : Text(_customDir!),
                  ),
                ]),
              ),
              if (_dest == ExtractTarget.custom) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _pickCustom,
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(l10n.change),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l10n.createSubfolder),
                  value: _subfolder,
                  onChanged: (v) => setState(() => _subfolder = v),
                ),
              ],
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
          onPressed: () => saveCopyTo(context, [result.destinationDir]),
          icon: const Icon(Icons.save_alt, size: 18),
          label: Text(l10n.saveCopyTo),
        ),
        TextButton.icon(
          onPressed: () => showFilesIn(context, result.destinationDir),
          icon: const Icon(Icons.folder_open, size: 18),
          label: Text(l10n.showFiles),
        ),
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
