import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../engine/composite_engine.dart';
import '../engine/models.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/app_state.dart';
import '../state/destinations.dart';
import 'actions.dart';
import '../state/storage_service.dart';
import 'widgets/job_dialog.dart';

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
  bool _split = false;
  int _splitMb = 25;
  bool _customSplit = false;
  final _customController = TextEditingController();
  late String? _saveDir = context.read<AppState>().createDir;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _customController.dispose();
    super.dispose();
  }

  String get _extension => switch (_format) {
        CreateFormat.zip => '.zip',
        CreateFormat.sevenZip => '.7z',
        CreateFormat.tarGz => '.tar.gz',
      };

  bool get _canEncrypt => _format != CreateFormat.tarGz;

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final storage = context.read<StorageService>();
    final navigator = Navigator.of(context);
    final parentContext = widget.parentContext;
    final messenger = ScaffoldMessenger.of(parentContext);
    final history = parentContext.read<AppState>();
    final appState = history;

    var base = _name.text.trim();
    if (base.isEmpty) base = 'Archive';
    base = base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    var folder = _saveDir;
    if (appState.askEachTime) {
      // "Ask every time": choose the folder now.
      folder = await pickWritableFolder(context);
      if (folder == null || !mounted) return;
    }
    if (folder != null && !StorageService.isWritable(folder)) folder = null;
    final output = resolveCreatePath(storage, fileName: '$base$_extension', dir: folder);
    Directory(p.dirname(output)).createSync(recursive: true);
    final usePassword = _encrypt && _canEncrypt && _password.text.isNotEmpty;

    var splitMb = _splitMb;
    if (_split && _customSplit) splitMb = int.tryParse(_customController.text.trim()) ?? 0;
    if (_split && splitMb < 1) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.splitTooSmall)));
      return;
    }

    final handle = appEngine.create(CreateRequest(
      sourcePaths: widget.sources,
      outputPath: output,
      format: _format,
      level: _level,
      password: usePassword ? _password.text : null,
      splitSizeBytes: _split ? splitMb * 1024 * 1024 : 0,
      tempDir: storage.tempDir,
    ));
    navigator.pop();
    if (!parentContext.mounted) return;
    final result = await showJobDialog<String>(
      parentContext,
      handle,
      title: l10n.creating,
      doneTitle: l10n.createdTitle,
      doneBuilder: (ctx, path) => Text(l10n.createdSummary(path)),
    );
    if (result != null) await history.addToHistory(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.folder_outlined),
                title: Text(l10n.saveTo),
                subtitle: Text(
                  context.watch<AppState>().askEachTime
                      ? l10n.askEveryTime
                      : (_saveDir ?? l10n.saveLocationApp),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final dir = await pickWritableFolder(context);
                    if (dir != null && mounted) setState(() => _saveDir = dir);
                  },
                  child: Text(l10n.change),
                ),
              ),
              const SizedBox(height: 8),
              Text(l10n.format, style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              SegmentedButton<CreateFormat>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: CreateFormat.zip, label: Text('ZIP')),
                  ButtonSegment(value: CreateFormat.sevenZip, label: Text('7Z')),
                  ButtonSegment(value: CreateFormat.tarGz, label: Text('TAR.GZ')),
                ],
                selected: {_format},
                onSelectionChanged: (s) => setState(() {
                  _format = s.first;
                  if (!_canEncrypt) _encrypt = false;
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
                title: Text(l10n.passwordProtect),
                subtitle: Text(l10n.passwordProtectSub),
                value: _encrypt,
                onChanged: _canEncrypt ? (v) => setState(() => _encrypt = v) : null,
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
                title: Text(l10n.splitArchive),
                subtitle: Text(l10n.splitArchiveSub),
                value: _split,
                onChanged: (v) => setState(() => _split = v),
              ),
              if (_split) ...[
                Text(l10n.splitSize, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final mb in const [10, 25, 100])
                    ChoiceChip(
                      label: Text(l10n.splitSizeMb(mb)),
                      selected: !_customSplit && _splitMb == mb,
                      onSelected: (_) => setState(() {
                        _customSplit = false;
                        _splitMb = mb;
                      }),
                    ),
                  ChoiceChip(
                    label: Text(l10n.splitCustomMb),
                    selected: _customSplit,
                    onSelected: (_) => setState(() => _customSplit = true),
                  ),
                ]),
                if (_customSplit) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.splitCustomMb,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(l10n.splitVolumesNote, style: theme.textTheme.bodySmall),
              ],
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
