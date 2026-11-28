import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../core/format_utils.dart';
import '../core/theme.dart';
import '../l10n/gen/app_localizations.dart';
import '../services/external_file_service.dart';
import '../state/file_ops.dart';
import '../state/storage_service.dart';
import 'actions.dart';
import 'create_sheet.dart';
import 'export_flow.dart';
import 'folder_picker_page.dart';
import 'widgets/file_op_messages.dart';
import 'widgets/format_badge.dart';

/// File manager for ZipFast's own storage: browse, open (in ZipFast for
/// archives, in other apps for everything else), share, rename, move, delete,
/// create folders and compress.
class FileBrowser extends StatefulWidget {
  const FileBrowser({super.key, required this.root, String? initialDir})
      : initialDir = initialDir ?? root;

  /// Top of what can be browsed and modified. Navigation and every file
  /// operation stay inside it.
  final String root;
  final String initialDir;

  @override
  State<FileBrowser> createState() => _FileBrowserState();
}

class _FileBrowserState extends State<FileBrowser> {
  late String _dir = isInside(widget.root, widget.initialDir) ? widget.initialDir : widget.root;
  List<FileItem> _items = const [];
  bool _failed = false;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _list();
  }

  void _list() {
    try {
      final items = StorageService.listDirectory(_dir);
      setState(() {
        _items = items;
        _failed = false;
        _selected.removeWhere((s) => !items.any((i) => i.path == s));
      });
    } catch (_) {
      setState(() {
        _items = const [];
        _failed = true;
        _selected.clear();
      });
    }
  }

  bool get _atRoot => p.equals(_dir, widget.root);
  bool get _selecting => _selected.isNotEmpty;

  void _goUp() {
    _dir = p.dirname(_dir);
    _selected.clear();
    _list();
  }

  void _enter(String dir) {
    _dir = dir;
    _selected.clear();
    _list();
  }

  void _toggle(String path) {
    setState(() => _selected.contains(path) ? _selected.remove(path) : _selected.add(path));
  }

  Future<void> _onTap(FileItem item) async {
    if (_selecting) return _toggle(item.path);
    if (item.isDirectory) return _enter(item.path);
    if (item.format.label != '?') return openArchive(context, item.path);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!await ExternalFileService.open(item.path)) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.noAppToOpen)));
    }
  }

  Future<void> _guard(Future<void> Function() op) async {
    try {
      await op();
    } on FileOpException catch (e) {
      if (mounted) showOpError(context, e);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).opFailed)));
      }
    }
    if (mounted) _list();
  }

  Future<void> _newFolder() async {
    final l10n = AppLocalizations.of(context);
    final name = await askForText(context, title: l10n.newFolder, label: l10n.folderName);
    if (name == null) return;
    await _guard(() async => createFolder(widget.root, _dir, name));
  }

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context);
    final path = _selected.single;
    final name = await askForText(
      context,
      title: l10n.rename,
      label: l10n.newName,
      initial: p.basename(path),
    );
    if (name == null) return;
    await _guard(() async {
      await renamePath(widget.root, path, name);
      _selected.clear();
    });
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    final paths = _selected.toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle(paths.length)),
        content: Text(l10n.deleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await _guard(() async {
      await deletePaths(widget.root, paths);
      _selected.clear();
    });
  }

  Future<void> _move() async {
    final l10n = AppLocalizations.of(context);
    final paths = _selected.toList();
    final dest = await Navigator.push<String>(
      context,
      MaterialPageRoute<String>(
        builder: (_) => FolderPickerPage(root: widget.root, start: _dir, confirmLabel: l10n.moveHere),
      ),
    );
    if (dest == null) return;
    await _guard(() async {
      await movePaths(widget.root, paths, dest);
      _selected.clear();
    });
  }

  Future<void> _share() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final hasFolder = _selected.any((s) => _items.any((i) => i.path == s && i.isDirectory));
    if (hasFolder) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.shareFoldersNote)));
      return;
    }
    await ExternalFileService.share(_selected.toList());
  }

  String _label(AppLocalizations l10n) =>
      _atRoot ? l10n.storageRoot : p.relative(_dir, from: widget.root);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();

    return PopScope(
      canPop: _atRoot && !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_selecting) {
          setState(_selected.clear);
        } else {
          _goUp();
        }
      },
      child: Column(children: [
        // Header: location + actions, or the selection summary.
        if (_selecting)
          ListTile(
            dense: true,
            leading: IconButton(
              tooltip: l10n.clearSelection,
              icon: const Icon(Icons.close),
              onPressed: () => setState(_selected.clear),
            ),
            title: Text(l10n.selectedCount(_selected.length)),
            trailing: IconButton(
              tooltip: l10n.selectAll,
              icon: const Icon(Icons.select_all),
              onPressed: () => setState(() => _selected.addAll(_items.map((i) => i.path))),
            ),
          )
        else
          ListTile(
            dense: true,
            leading: Icon(_atRoot ? Icons.folder_special_outlined : Icons.arrow_upward),
            title: Text(_label(l10n), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: _atRoot ? Text(l10n.storageHint) : Text(l10n.upOneLevel),
            onTap: _atRoot ? null : _goUp,
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                tooltip: l10n.newFolder,
                icon: const Icon(Icons.create_new_folder_outlined),
                onPressed: _newFolder,
              ),
              IconButton(
                tooltip: l10n.refresh,
                icon: const Icon(Icons.refresh),
                onPressed: _list,
              ),
            ]),
          ),
        Expanded(
          child: _failed
              ? Center(child: Text(l10n.browseNoAccessTitle))
              : _items.isEmpty
                  ? Center(child: Text(l10n.browseEmpty))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: _items.length,
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        final isArchive = !item.isDirectory && item.format.label != '?';
                        final selected = _selected.contains(item.path);
                        return ListTile(
                          selected: selected,
                          leading: item.isDirectory
                              ? const Icon(Icons.folder, color: ZipFastColors.lockAmber)
                              : isArchive
                                  ? FormatBadge(item.format, size: 36)
                                  : const Icon(Icons.insert_drive_file_outlined),
                          title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: item.isDirectory
                              ? null
                              : Text('${formatBytes(item.size)} · ${formatDate(item.modified, locale)}'),
                          trailing: Checkbox(value: selected, onChanged: (_) => _toggle(item.path)),
                          onTap: () => _onTap(item),
                          onLongPress: () => _toggle(item.path),
                        );
                      },
                    ),
        ),
        if (_selecting)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => showCreateSheet(context, _selected.toList()),
                    icon: const Icon(Icons.archive_outlined),
                    label: Text(l10n.compressSelected(_selected.length)),
                  ),
                ),
                IconButton(tooltip: l10n.shareAction, icon: const Icon(Icons.share_outlined), onPressed: _share),
                IconButton(
                  tooltip: l10n.saveCopyTo,
                  icon: const Icon(Icons.save_alt),
                  onPressed: () => saveCopyTo(context, _selected.toList()),
                ),
                IconButton(tooltip: l10n.moveTo, icon: const Icon(Icons.drive_file_move_outlined), onPressed: _move),
                if (_selected.length == 1)
                  IconButton(tooltip: l10n.rename, icon: const Icon(Icons.drive_file_rename_outline), onPressed: _rename),
                IconButton(tooltip: l10n.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Full-screen file browser, opened from "Show files".
class FilesPage extends StatelessWidget {
  const FilesPage({super.key, required this.appRoot, required this.initialDir});

  /// ZipFast's storage folder.
  final String appRoot;

  /// Folder to show first (a file path shows its folder).
  final String initialDir;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isFile = FileSystemEntity.isFileSync(initialDir);
    final dir = isFile ? p.dirname(initialDir) : initialDir;
    // Outside ZipFast's storage (e.g. next to an archive in Downloads) the
    // browser is limited to that folder.
    final root = isInside(appRoot, dir) ? appRoot : dir;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.showFiles)),
      body: FileBrowser(root: root, initialDir: dir),
    );
  }
}
