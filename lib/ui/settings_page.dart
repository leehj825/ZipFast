import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../engine/models.dart';
import '../l10n/gen/app_localizations.dart';
import '../services/storage_access_service.dart';
import '../state/app_state.dart';
import '../state/storage_service.dart';
import 'actions.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<AppState>();

    String themeLabel(ThemeMode m) => switch (m) {
          ThemeMode.system => l10n.themeSystem,
          ThemeMode.light => l10n.themeLight,
          ThemeMode.dark => l10n.themeDark,
        };
    String conflictLabel(ConflictPolicy c) => switch (c) {
          ConflictPolicy.skip => l10n.conflictSkip,
          ConflictPolicy.overwrite => l10n.conflictOverwrite,
          ConflictPolicy.rename => l10n.conflictRename,
        };
    String languageLabel(String? code) => switch (code) {
          'en' => 'English',
          'ko' => '한국어',
          _ => l10n.languageSystem,
        };

    Future<T?> pick<T>(String title, List<T> values, T current, String Function(T) label) {
      return showModalBottomSheet<T>(
        context: context,
        builder: (ctx) => SafeArea(
          child: RadioGroup<T>(
            groupValue: current,
            onChanged: (x) => Navigator.pop(ctx, x),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
              ),
              for (final v in values) RadioListTile<T>(value: v, title: Text(label(v))),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(children: [
        ListTile(
          leading: const Icon(Icons.palette_outlined),
          title: Text(l10n.theme),
          subtitle: Text(themeLabel(state.themeMode)),
          onTap: () async {
            final m = await pick<ThemeMode>(
                l10n.theme, ThemeMode.values, state.themeMode, themeLabel);
            if (m != null) state.setThemeMode(m);
          },
        ),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l10n.language),
          subtitle: Text(languageLabel(state.localeCode)),
          onTap: () async {
            // `''` stands for "system default" because null means "dismissed".
            final c = await pick<String>(
              l10n.language,
              const ['', 'en', 'ko'],
              state.localeCode ?? '',
              (v) => languageLabel(v.isEmpty ? null : v),
            );
            if (c != null) state.setLocaleCode(c.isEmpty ? null : c);
          },
        ),
        ListTile(
          leading: const Icon(Icons.file_copy_outlined),
          title: Text(l10n.defaultConflict),
          subtitle: Text(conflictLabel(state.defaultConflict)),
          onTap: () async {
            final c = await pick<ConflictPolicy>(l10n.defaultConflict, ConflictPolicy.values,
                state.defaultConflict, conflictLabel);
            if (c != null) state.setDefaultConflict(c);
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.unarchive_outlined),
          title: Text(l10n.extractLocation),
          subtitle: Text(state.extractDir ?? l10n.extractLocationNextTo),
          trailing: state.extractDir == null
              ? null
              : IconButton(
                  tooltip: l10n.resetToDefault,
                  icon: const Icon(Icons.restart_alt),
                  onPressed: () => state.setExtractDir(null),
                ),
          onTap: () async {
            final dir = await pickWritableFolder(context);
            if (dir != null) state.setExtractDir(dir);
          },
        ),
        ListTile(
          leading: const Icon(Icons.archive_outlined),
          title: Text(l10n.saveLocation),
          subtitle: Text(state.createDir ?? l10n.saveLocationApp),
          trailing: state.createDir == null
              ? null
              : IconButton(
                  tooltip: l10n.resetToDefault,
                  icon: const Icon(Icons.restart_alt),
                  onPressed: () => state.setCreateDir(null),
                ),
          onTap: () async {
            final dir = await pickWritableFolder(context);
            if (dir != null) state.setCreateDir(dir);
          },
        ),
        SwitchListTile(
          secondary: const Icon(Icons.help_outline),
          title: Text(l10n.askEveryTime),
          subtitle: Text(l10n.askEveryTimeSub),
          value: state.askEachTime,
          onChanged: state.setAskEachTime,
        ),
        const _AllFilesAccessTile(),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: Text(l10n.clearCache),
          onTap: () {
            context.read<StorageService>().clearTemp();
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(l10n.cacheCleared)));
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.description_outlined),
          title: Text(l10n.licenses),
          onTap: () => showLicensePage(
            context: context,
            applicationName: l10n.appName,
            applicationVersion: '0.1.0',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.lock_outline),
          title: Text(l10n.about),
          subtitle: Text('${l10n.version('0.1.0')}\n${l10n.privacy}'),
          isThreeLine: true,
        ),
      ]),
    );
  }
}

/// Shows whether Android "All files access" is granted and opens its settings.
class _AllFilesAccessTile extends StatefulWidget {
  const _AllFilesAccessTile();

  @override
  State<_AllFilesAccessTile> createState() => _AllFilesAccessTileState();
}

class _AllFilesAccessTileState extends State<_AllFilesAccessTile> with WidgetsBindingObserver {
  bool? _granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-check when the user comes back from the system settings screen.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final granted = await StorageAccessService.hasAllFilesAccess();
    if (mounted) setState(() => _granted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final granted = _granted ?? true;
    return ListTile(
      leading: Icon(granted ? Icons.verified_user_outlined : Icons.folder_off_outlined),
      title: Text(l10n.allFilesAccess),
      subtitle: Text(granted ? l10n.allFilesAccessOn : l10n.allFilesAccessOff),
      onTap: granted ? null : StorageAccessService.openAllFilesAccessSettings,
    );
  }
}
