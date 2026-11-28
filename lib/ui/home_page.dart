import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../core/format_utils.dart';
import '../l10n/gen/app_localizations.dart';
import '../state/app_state.dart';
import '../state/storage_service.dart';
import 'actions.dart';
import 'create_sheet.dart';
import 'file_browser.dart';
import 'settings_page.dart';
import 'widgets/ad_banner.dart';
import 'widgets/format_badge.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _searching = false;
  final _query = ValueNotifier<String>('');

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: l10n.searchHint,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => _query.value = v.trim().toLowerCase(),
                )
              : Text(l10n.appName, style: const TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              tooltip: l10n.search,
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                _searching = !_searching;
                _query.value = '';
              }),
            ),
            IconButton(
              tooltip: l10n.settings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              ),
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: l10n.tabRecent),
            Tab(text: l10n.tabBrowse),
          ]),
        ),
        body: TabBarView(children: [
          _RecentTab(query: _query),
          FileBrowser(root: context.read<StorageService>().appFilesDir),
        ]),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => pickAndOpenArchive(context),
          icon: const Icon(Icons.folder_open),
          label: Text(l10n.openArchive),
        ),
        // The banner sits below the FAB with a safe margin; it never covers
        // content because it is part of the scaffold, not an overlay.
        bottomNavigationBar: const AdBannerSlot(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent archives
// ---------------------------------------------------------------------------

class _RecentTab extends StatefulWidget {
  const _RecentTab({required this.query});
  final ValueNotifier<String> query;

  @override
  State<_RecentTab> createState() => _RecentTabState();
}

class _RecentTabState extends State<_RecentTab> {
  List<FileItem> _items = const [];
  bool _loading = true;
  List<String>? _lastHistory;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final history = context.watch<AppState>().history;
    if (_lastHistory == null || !_sameList(_lastHistory!, history)) {
      _lastHistory = history;
      _load();
    }
  }

  static bool _sameList(List<String> a, List<String> b) =>
      a.length == b.length && Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

  Future<void> _load() async {
    final storage = context.read<StorageService>();
    final history = _lastHistory ?? const [];
    final roots = storage.scanRoots;
    final scanned = await StorageService.scanArchivesInBackground(roots);
    final byPath = <String, FileItem>{};
    for (final path in history) {
      final item = StorageService.statPath(path);
      if (item != null) byPath[path] = item;
    }
    for (final item in scanned) {
      byPath[item.path] = item;
    }
    final list = byPath.values.toList()..sort((a, b) => b.modified.compareTo(a.modified));
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<String>(
      valueListenable: widget.query,
      builder: (context, query, _) {
        final items = query.isEmpty
            ? _items
            : _items.where((i) => i.name.toLowerCase().contains(query)).toList();
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              const _ActionCards(),
              const SizedBox(height: 16),
              Text(
                l10n.recentArchivesTitle(items.length),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty)
                _EmptyState(title: l10n.noRecentTitle, body: l10n.noRecentBody)
              else
                for (final item in items) ...[
                  _ArchiveTile(item: item),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.translate,
                title: l10n.encodingFixTitle,
                subtitle: l10n.encodingFixSub,
              ),
              const SizedBox(height: 8),
              _InfoCard(
                icon: Icons.lock_outline,
                title: l10n.aesSupported,
                subtitle: l10n.privacy,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionCards extends StatelessWidget {
  const _ActionCards();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    Widget card(IconData icon, String title, String sub, VoidCallback onTap) {
      return Expanded(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        ),
      );
    }

    return Row(children: [
      card(Icons.add_box_outlined, l10n.createArchive, l10n.createArchiveSub, () async {
        final files = await FilePicker.pickFiles();
        final paths = files.map((f) => f.path).whereType<String>().toList();
        if (paths.isNotEmpty && context.mounted) showCreateSheet(context, paths);
      }),
      const SizedBox(width: 12),
      card(Icons.unarchive_outlined, l10n.extractArchive, l10n.extractArchiveSub,
          () => pickAndOpenArchive(context)),
    ]);
  }
}

final _splitPattern = RegExp(r'(\.part\d+\.rar|\.z\d\d|\.7z\.\d{3}|\.r\d\d)$', caseSensitive: false);

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({required this.item});
  final FileItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openArchive(context, item.path),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            FormatBadge(item.format),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${formatBytes(item.size)} · ${formatDate(item.modified, locale)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]),
            ),
            if (_splitPattern.hasMatch(item.name))
              Chip(
                label: Text(l10n.splitBadge),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
          ]),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(subtitle),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(children: [
          Icon(Icons.inventory_2_outlined,
              size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center),
        ]),
      );
}
