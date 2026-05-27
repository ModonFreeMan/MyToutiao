import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  const StorageService(this._preferences);

  final SharedPreferences _preferences;

  Future<List<String>> getStringList(String key) async {
    return _preferences.getStringList(key) ?? const <String>[];
  }

  Future<void> setStringList(String key, List<String> values) async {
    await _preferences.setStringList(key, values);
  }

  Future<void> remove(String key) async {
    await _preferences.remove(key);
  }
}
