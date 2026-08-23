import 'package:shared_preferences/shared_preferences.dart';

/// Key–value persistence, behind an interface so repositories can be exercised
/// against an in-memory store instead of the platform plugin.
abstract interface class PreferencesService {
  Future<String?> getString(String key);
  Future<int?> getInt(String key);
  Future<bool?> getBool(String key);

  /// Integers stored as a string list. Unparseable entries are discarded rather
  /// than thrown on — a store written by another version must not break launch.
  Future<List<int>?> getIntList(String key);

  Future<Set<String>> keysWithPrefix(String prefix);

  Future<void> setString(String key, String value);
  Future<void> setInt(String key, int value);
  Future<void> setBool(String key, bool value);
  Future<void> setIntList(String key, List<int> values);
}

class SharedPreferencesService implements PreferencesService {
  Future<SharedPreferences> get _prefs async =>
      _cached ??= await SharedPreferences.getInstance();

  SharedPreferences? _cached;

  @override
  Future<String?> getString(String key) async => (await _prefs).getString(key);

  @override
  Future<int?> getInt(String key) async => (await _prefs).getInt(key);

  @override
  Future<bool?> getBool(String key) async => (await _prefs).getBool(key);

  @override
  Future<List<int>?> getIntList(String key) async {
    final stored = (await _prefs).getStringList(key);
    if (stored == null) return null;
    return [for (final entry in stored) ?int.tryParse(entry)];
  }

  @override
  Future<Set<String>> keysWithPrefix(String prefix) async =>
      (await _prefs).getKeys().where((key) => key.startsWith(prefix)).toSet();

  @override
  Future<void> setString(String key, String value) async =>
      (await _prefs).setString(key, value);

  @override
  Future<void> setInt(String key, int value) async =>
      (await _prefs).setInt(key, value);

  @override
  Future<void> setBool(String key, bool value) async =>
      (await _prefs).setBool(key, value);

  @override
  Future<void> setIntList(String key, List<int> values) async =>
      (await _prefs).setStringList(key, [for (final v in values) '$v']);
}
