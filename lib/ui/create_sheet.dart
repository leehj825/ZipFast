import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../engine/archive_engine.dart';
import '../engine/models.dart';
import '../engine/safe_path.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/app_state.dart';
import '../state/storage_service.dart';
import 'widgets/job_dialog.dart';
import 'widgets/pro_sheet.dart';

/// Bottom sheet for creating an archive from [sources], followed by the
/// progress dialog.
Future<void> showCreateSheet(BuildContext context, List<String> sources) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CreateSheet(sources: sources, parentContext: context),
  );
}

class _CreateSheet extends StatefulWidget {
  const _CreateSheet({required this.sources, required this.parentContext});
  final List<String> sources;
  final BuildContext parentContext;

  @override
  State<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends State<_CreateSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.sources.length == 1
        ? p.basenameWithoutExtension(widget.sources.first)
        : 'Archive',
  );
  final _password = TextEditingController();
  CreateFormat _format = CreateFormat.zip;
  CompressionLevel _level = CompressionLevel.normal;
  bool _encrypt = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  String get _extension => _format == CreateFormat.zip ? '.zip' : '.tar.gz';

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final storage = context.read<StorageService>();
    final appState = context.read<AppState>();
    final navigator = Navigator.of(context);
    final parentContext = widget.parentContext;

    var base = _name.text.trim();
    if (base.isEmpty) base = 'Archive';
    base = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    Directory(storage.createRoot).createSync(recursive: true);
    final output = uniquePath(
      p.join(storage.createRoot, '$base$_extension'),
      (s) => FileSystemEntity.typeSync(s, followLinks: false) != FileSystemEntityType.notFound,
    );
    final usePassword = _encrypt && _format == CreateFormat.zip && _password.text.isNotEmpty;

    final handle = const DartArchiveEngine().create(CreateRequest(
      sourcePaths: widget.sources,
      outputPath: output,
      format: _format,
      level: _level,
      password: usePassword ? _password.text : null,
      tempDir: storage.tempDir,
    ));
    navigator.pop();
    final result = await showJobDialog<String>(
      parentContext,
      handle,
      title: l10n.creating,
      doneTitle: l10n.createdTitle,
      doneBuilder: (ctx, path) => Text(l10n.createdSummary(path)),
    );
    if (result != null) await appState.addToHistory(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isPro = context.watch<AppState>().isPro;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.createTitle, style: theme.textTheme.titleLarge),
              Text(l10n.filesSelected(widget.sources.length), style: theme.textTheme.bodySmall),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: l10n.archiveName,
                  suffixText: _extension,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(l10n.format, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<CreateFormat>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: CreateFormat.zip, label: Text('ZIP')),
                  ButtonSegment(value: CreateFormat.tarGz, label: Text('TAR.GZ')),
                ],
                selected: {_format},
                onSelectionChanged: (s) => setState(() {
                  _format = s.first;
                  if (_format != CreateFormat.zip) _encrypt = false;
                }),
              ),
              const SizedBox(height: 16),
              Text(l10n.compression, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<CompressionLevel>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: CompressionLevel.store, label: Text(l10n.levelStore)),
                  ButtonSegment(value: CompressionLevel.fast, label: Text(l10n.levelFast)),
                  ButtonSegment(value: CompressionLevel.normal, label: Text(l10n.levelNormal)),
                  ButtonSegment(value: CompressionLevel.maximum, label: Text(l10n.levelMaximum)),
                ],
                selected: {_level},
                onSelectionChanged: (s) => setState(() => _level = s.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(children: [
                  Flexible(child: Text(l10n.passwordProtect)),
                  if (!isPro) ...[const SizedBox(width: 8), _ProChip(label: l10n.proFeature)],
                ]),
                subtitle: Text(l10n.passwordProtectSub),
                value: _encrypt,
                onChanged: _format != CreateFormat.zip
                    ? null
                    : (v) {
                        if (!isPro) {
                          showProSheet(context);
                        } else {
                          setState(() => _encrypt = v);
                        }
                      },
              ),
              if (_encrypt)
                TextField(
                  controller: _password,
                  obscureText: _obscure,
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(children: [
                  Flexible(child: Text(l10n.splitArchive)),
                  if (!isPro) ...[const SizedBox(width: 8), _ProChip(label: l10n.proFeature)],
                ]),
                subtitle: Text(l10n.splitArchiveSub),
                value: false,
                onChanged: null,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: widget.sources.isEmpty ? null : _create,
                  child: Text(l10n.createButton),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProChip extends StatelessWidget {
  const _ProChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
      );
}
