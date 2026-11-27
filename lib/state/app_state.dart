import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/models.dart';

/// App-wide settings and history, persisted with `shared_preferences`.
class AppState extends ChangeNotifier {
  AppState(this._prefs) {
    _themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString(_kTheme),
      orElse: () => ThemeMode.system,
    );
    _localeCode = _prefs.getString(_kLocale);
    _conflict = ConflictPolicy.values.firstWhere(
      (c) => c.name == _prefs.getString(_kConflict),
      orElse: () => ConflictPolicy.rename,
    );
    _history = _decodeHistory(_prefs.getString(_kHistory));
    _extractDir = _prefs.getString(_kExtractDir);
    _createDir = _prefs.getString(_kCreateDir);
    _askEachTime = _prefs.getBool(_kAsk) ?? false;
  }

  static const _kTheme = 'theme_mode';
  static const _kLocale = 'locale';
  static const _kConflict = 'conflict_policy';
  static const _kHistory = 'history';
  static const _kExtractDir = 'extract_dir';
  static const _kCreateDir = 'create_dir';
  static const _kAsk = 'ask_each_time';
  static const maxHistory = 50;

  final SharedPreferences _prefs;

  late ThemeMode _themeMode;
  String? _localeCode;
  late ConflictPolicy _conflict;
  late List<String> _history;
  String? _extractDir;
  String? _createDir;
  late bool _askEachTime;

  ThemeMode get themeMode => _themeMode;

  /// `null` follows the system language.
  Locale? get locale => _localeCode == null ? null : Locale(_localeCode!);
  String? get localeCode => _localeCode;

  ConflictPolicy get defaultConflict => _conflict;

  /// Paths of archives the user opened recently, newest first.
  List<String> get history => List.unmodifiable(_history);

  /// Default folder for extraction; `null` means a new folder next to the archive.
  String? get extractDir => _extractDir;

  /// Default folder for new archives; `null` means the app's own storage.
  String? get createDir => _createDir;

  /// Whether to ask for a folder every time an archive is extracted or created.
  bool get askEachTime => _askEachTime;

  Future<void> setExtractDir(String? dir) => _setString(_kExtractDir, dir, (v) => _extractDir = v);

  Future<void> setCreateDir(String? dir) => _setString(_kCreateDir, dir, (v) => _createDir = v);

  Future<void> setAskEachTime(bool value) async {
    _askEachTime = value;
    notifyListeners();
    await _prefs.setBool(_kAsk, value);
  }

  Future<void> _setString(String key, String? value, void Function(String?) assign) async {
    assign(value);
    notifyListeners();
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_kTheme, mode.name);
  }

  Future<void> setLocaleCode(String? code) async {
    _localeCode = code;
    notifyListeners();
    if (code == null) {
      await _prefs.remove(_kLocale);
    } else {
      await _prefs.setString(_kLocale, code);
    }
  }

  Future<void> setDefaultConflict(ConflictPolicy policy) async {
    _conflict = policy;
    notifyListeners();
    await _prefs.setString(_kConflict, policy.name);
  }

  Future<void> addToHistory(String path) async {
    _history
      ..remove(path)
      ..insert(0, path);
    if (_history.length > maxHistory) {
      _history = _history.sublist(0, maxHistory);
    }
    notifyListeners();
    await _prefs.setString(_kHistory, jsonEncode(_history));
  }

  Future<void> removeFromHistory(String path) async {
    if (_history.remove(path)) {
      notifyListeners();
      await _prefs.setString(_kHistory, jsonEncode(_history));
    }
  }

  static List<String> _decodeHistory(String? raw) {
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }
}
