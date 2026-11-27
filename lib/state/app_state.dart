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
  }

  static const _kTheme = 'theme_mode';
  static const _kLocale = 'locale';
  static const _kConflict = 'conflict_policy';
  static const _kHistory = 'history';
  static const maxHistory = 50;

  final SharedPreferences _prefs;

  late ThemeMode _themeMode;
  String? _localeCode;
  late ConflictPolicy _conflict;
  late List<String> _history;

  ThemeMode get themeMode => _themeMode;

  /// `null` follows the system language.
  Locale? get locale => _localeCode == null ? null : Locale(_localeCode!);
  String? get localeCode => _localeCode;

  ConflictPolicy get defaultConflict => _conflict;

  /// Paths of archives the user opened recently, newest first.
  List<String> get history => List.unmodifiable(_history);

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
