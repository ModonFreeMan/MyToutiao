import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  const StorageService();

  Future<List<String>> getStringList(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(key) ?? const <String>[];
  }

  Future<void> setStringList(String key, List<String> values) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(key, values);
  }

  Future<void> remove(String key) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(key);
  }
}
