import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../l10n/gen/app_localizations.dart';
import '../state/file_ops.dart';
import '../state/storage_service.dart';
import 'widgets/file_op_messages.dart';

/// Pick a folder inside [root] (ZipFast's storage). Pops with the chosen path.
/// Used for the extract/save destination and for "Move to…".
class FolderPickerPage extends StatefulWidget {
  const FolderPickerPage({super.key, required this.root, this.start, this.confirmLabel});

  final String root;
  final String? start;

  /// Label of the confirm button (defaults to "Use this folder").
  final String? confirmLabel;

  @override
  State<FolderPickerPage> createState() => _FolderPickerPageState();
}

class _FolderPickerPageState extends State<FolderPickerPage> {
  late String _dir =
      widget.start != null && isInside(widget.root, widget.start!) ? widget.start! : widget.root;
  List<FileItem> _folders = const [];

  @override
  void initState() {
    super.initState();
    _list();
  }

  void _list() {
    List<FileItem> items;
    try {
      items = StorageService.listDirectory(_dir).where((e) => e.isDirectory).toList();
    } catch (_) {
      items = const [];
    }
    setState(() => _folders = items);
  }

  bool get _atRoot => p.equals(_dir, widget.root);

  String _label(AppLocalizations l10n) =>
      _atRoot ? l10n.storageRoot : p.relative(_dir, from: widget.root);

  Future<void> _newFolder() async {
    final l10n = AppLocalizations.of(context);
    final name = await askForText(context, title: l10n.newFolder, label: l10n.folderName);
    if (name == null || !mounted) return;
    try {
      final path = await createFolder(widget.root, _dir, name);
      if (mounted) {
        setState(() => _dir = path);
        _list();
      }
    } on FileOpException catch (e) {
      if (mounted) showOpError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: _atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_atRoot) {
          _dir = p.dirname(_dir);
          _list();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.chooseDestination),
          actions: [
            IconButton(
              tooltip: l10n.newFolder,
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: _newFolder,
            ),
          ],
        ),
        body: Column(children: [
          ListTile(
            dense: true,
            leading: Icon(_atRoot ? Icons.folder_special_outlined : Icons.arrow_upward),
            title: Text(_label(l10n), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: _atRoot ? null : Text(l10n.upOneLevel),
            onTap: _atRoot
                ? null
                : () {
                    _dir = p.dirname(_dir);
                    _list();
                  },
          ),
          Expanded(
            child: _folders.isEmpty
                ? Center(child: Text(l10n.browseEmpty))
                : ListView.builder(
                    itemCount: _folders.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: const Icon(Icons.folder, color: Color(0xFFF59E0B)),
                      title: Text(_folders[i].name),
                      onTap: () {
                        _dir = _folders[i].path;
                        _list();
                      },
                    ),
                  ),
          ),
        ]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.pop(context, _dir),
              icon: const Icon(Icons.check),
              label: Text(widget.confirmLabel ?? l10n.useThisFolder),
            ),
          ),
        ),
      ),
    );
  }
}
