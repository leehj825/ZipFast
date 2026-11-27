import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../core/archive_format.dart';
import '../core/format_utils.dart';
import '../core/theme.dart';
import '../encoding/name_encoding.dart';
import '../engine/archive_engine.dart';
import '../engine/models.dart';
import '../engine/safe_path.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/storage_service.dart';
import 'actions.dart';
import 'extract_sheet.dart';
import 'preview_page.dart';
import 'widgets/format_badge.dart';

/// One row in the folder view: a real entry or an implied parent folder.
class _Node {
  _Node(this.path, this.isDirectory, this.size, this.modified, this.encrypted);
  final String path;
  final bool isDirectory;
  final int size;
  final DateTime? modified;
  final bool encrypted;
  String get name => path.split('/').last;
}

/// Browse the inside of an archive, preview files, and extract all or a
/// selection.
class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.path});
  final String path;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  static const _engine = DartArchiveEngine();

  ArchiveListing? _listing;
  Object? _error;
  bool _loading = true;
  NameEncoding _encoding = NameEncoding.auto;
  String? _password;
  String _dir = '';
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final storage = context.read<StorageService>();
    try {
      final listing = await _engine.list(
        widget.path,
        encoding: _encoding,
        password: _password,
        tempDir: storage.tempDir,
      );
      if (!mounted) return;
      setState(() {
        _listing = listing;
        _loading = false;
        _selected.clear();
        _dir = '';
      });
      // ZIP headers list fine without a password, but contents need one.
      if (listing.hasEncrypted && _password == null) {
        await _promptPassword(wrong: false);
      }
    } on PasswordRequiredException {
      await _askPassword(wrong: false);
    } on WrongPasswordException {
      await _askPassword(wrong: true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// Asks for a password. Returns it (and remembers it), or `null` if the user
  /// cancelled.
  Future<String?> _promptPassword({required bool wrong}) async {
    final pw = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PasswordDialog(showError: wrong),
    );
    if (pw != null && mounted) setState(() => _password = pw);
    return pw;
  }

  /// Password needed before the listing itself can be read: cancelling leaves
  /// the viewer.
  Future<void> _askPassword({required bool wrong}) async {
    final pw = await _promptPassword(wrong: wrong);
    if (!mounted) return;
    if (pw == null) {
      Navigator.pop(context);
    } else {
      await _load();
    }
  }

  List<_Node> _children() {
    final listing = _listing;
    if (listing == null) return const [];
    final prefix = _dir.isEmpty ? '' : '$_dir/';
    final nodes = <String, _Node>{};
    for (final e in listing.entries) {
      if (!e.path.startsWith(prefix) || e.path == _dir) continue;
      final rest = e.path.substring(prefix.length);
      final slash = rest.indexOf('/');
      if (slash < 0) {
        nodes[rest] = _Node(e.path, e.isDirectory, e.size, e.modified, e.encrypted);
      } else {
        final name = rest.substring(0, slash);
        nodes.putIfAbsent(name, () => _Node('$prefix$name', true, 0, null, false));
      }
    }
    final list = nodes.values.toList()
      ..sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  int get _selectedFileCount => _listing == null
      ? 0
      : _listing!.entries
          .where((e) => !e.isDirectory && isPathSelected(e.path, _selected))
          .length;

  Future<void> _preview(_Node node) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ext = PreviewPage.extensionOf(node.name);
    final isImage = PreviewPage.imageExtensions.contains(ext);
    final isText = PreviewPage.textExtensions.contains(ext);
    if (!isImage && !isText) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.previewUnavailable)));
      return;
    }
    try {
      final bytes = await _engine.readEntry(
        widget.path,
        node.path,
        encoding: _encoding,
        password: _password,
        tempDir: context.read<StorageService>().tempDir,
      );
      if (!mounted) return;
      await navigator.push(MaterialPageRoute<void>(
        builder: (_) => isImage
            ? PreviewPage.image(title: node.name, bytes: bytes)
            : PreviewPage.text(title: node.name, bytes: bytes),
      ));
    } on PasswordRequiredException {
      if (await _promptPassword(wrong: false) != null) await _preview(node);
    } on WrongPasswordException {
      if (await _promptPassword(wrong: true) != null) await _preview(node);
    } catch (e) {
      final tooLarge = e is CorruptArchiveException && e.message.contains('too large');
      messenger.showSnackBar(SnackBar(
        content: Text(tooLarge ? l10n.previewTooLarge : l10n.previewFailed),
      ));
    }
  }

  void _extract() {
    final listing = _listing!;
    showExtractSheet(
      context,
      archivePath: widget.path,
      listing: listing,
      selected: _selected.isEmpty ? null : Set.of(_selected),
      encoding: _encoding,
      password: _password,
    );
  }

  Future<void> _pickEncoding() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showModalBottomSheet<NameEncoding>(
      context: context,
      builder: (ctx) => SafeArea(
        child: RadioGroup<NameEncoding>(
          groupValue: _encoding,
          onChanged: (v) => Navigator.pop(ctx, v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in NameEncoding.values)
                RadioListTile<NameEncoding>(value: e, title: Text(_encodingLabel(l10n, e))),
            ],
          ),
        ),
      ),
    );
    if (choice != null && choice != _encoding) {
      _encoding = choice;
      await _load();
    }
  }

  static String _encodingLabel(AppLocalizations l10n, NameEncoding e) => switch (e) {
        NameEncoding.auto => l10n.encodingAuto,
        NameEncoding.utf8 => 'UTF-8',
        NameEncoding.cp949 => l10n.encodingCp949,
        NameEncoding.shiftJis => l10n.encodingShiftJis,
        NameEncoding.gbk => l10n.encodingGbk,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final listing = _listing;
    final title = p.basename(widget.path);

    return PopScope(
      canPop: _dir.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _dir.isNotEmpty) {
          setState(() => _dir = _dir.contains('/') ? _dir.substring(0, _dir.lastIndexOf('/')) : '');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
              if (listing != null)
                Text(
                  l10n.viewerSubtitle(listing.fileCount, formatBytes(listing.totalSize)),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          actions: [
            if (listing != null)
              IconButton(
                tooltip: _selected.isEmpty ? l10n.selectAll : l10n.clearSelection,
                icon: Icon(_selected.isEmpty ? Icons.select_all : Icons.deselect),
                onPressed: () => setState(() {
                  if (_selected.isEmpty) {
                    _selected.addAll(_children().map((n) => n.path));
                  } else {
                    _selected.clear();
                  }
                }),
              ),
          ],
        ),
        body: _buildBody(l10n, theme),
        bottomNavigationBar: listing == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _extract,
                    icon: const Icon(Icons.unarchive),
                    label: Text(_selected.isEmpty
                        ? l10n.extractAll
                        : l10n.extractSelected(_selectedFileCount)),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, ThemeData theme) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _ErrorView(error: _error!, onRetry: _load);
    final listing = _listing!;
    final nodes = _children();

    return Column(
      children: [
        if (listing.format == ArchiveFormat.zip || _encoding != NameEncoding.auto)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(children: [
              ActionChip(
                avatar: const Icon(Icons.translate, size: 18),
                label: Text('${l10n.encodingLabel}: ${_encodingLabel(l10n, _encoding)}'),
                onPressed: _pickEncoding,
              ),
            ]),
          ),
        if (listing.namesLookGarbled)
          MaterialBanner(
            backgroundColor: theme.colorScheme.tertiaryContainer,
            leading: const Icon(Icons.warning_amber_rounded),
            content: Text(l10n.encodingBannerTitle),
            actions: [TextButton(onPressed: _pickEncoding, child: Text(l10n.encodingBannerAction))],
          ),
        if (_dir.isNotEmpty)
          ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_upward),
            title: Text('/$_dir'),
            subtitle: Text(l10n.upOneLevel),
            onTap: () => setState(
                () => _dir = _dir.contains('/') ? _dir.substring(0, _dir.lastIndexOf('/')) : ''),
          ),
        Expanded(
          child: nodes.isEmpty
              ? Center(child: Text(l10n.folderEmpty))
              : ListView.builder(
                  itemCount: nodes.length,
                  itemBuilder: (context, i) {
                    final n = nodes[i];
                    final checked = isPathSelected(n.path, _selected);
                    return ListTile(
                      leading: Icon(
                        n.isDirectory ? Icons.folder : _iconFor(n.name),
                        color: n.isDirectory ? ZipFastColors.lockAmber : null,
                      ),
                      title: Text(n.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text([
                        if (!n.isDirectory) formatBytes(n.size),
                        if (n.modified != null)
                          formatDate(n.modified!, Localizations.localeOf(context).toString()),
                      ].join(' · ')),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (n.encrypted)
                          const Icon(Icons.lock, size: 18, color: ZipFastColors.lockAmber),
                        Checkbox(
                          value: checked,
                          onChanged: (v) => setState(() {
                            if (v == true) {
                              _selected.add(n.path);
                            } else {
                              _selected.remove(n.path);
                            }
                          }),
                        ),
                      ]),
                      onTap: () {
                        if (n.isDirectory) {
                          setState(() => _dir = n.path);
                        } else {
                          _preview(n);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  static IconData _iconFor(String name) {
    final ext = PreviewPage.extensionOf(name);
    if (PreviewPage.imageExtensions.contains(ext)) return Icons.image_outlined;
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (PreviewPage.textExtensions.contains(ext)) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final unsupported = error is UnsupportedFormatException;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unsupported)
              FormatBadge((error as UnsupportedFormatException).format, size: 64)
            else
              const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(
              unsupported
                  ? l10n.unsupportedTitle((error as UnsupportedFormatException).format.label)
                  : l10n.corruptTitle,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              unsupported ? l10n.unsupportedBody : describeError(l10n, error),
              textAlign: TextAlign.center,
            ),
            if (!unsupported) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.showError});
  final bool showError;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.passwordTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: _obscure,
        onSubmitted: (v) => Navigator.pop(context, v),
        decoration: InputDecoration(
          labelText: l10n.passwordHint,
          errorText: widget.showError ? l10n.passwordWrong : null,
          suffixIcon: IconButton(
            tooltip: _obscure ? l10n.showPassword : l10n.hidePassword,
            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.unlock),
        ),
      ],
    );
  }
}
