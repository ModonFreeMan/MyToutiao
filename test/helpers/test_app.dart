import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_mvp/app/app.dart';
import 'package:video_player_mvp/features/storage/providers/storage_provider.dart';

Future<SharedPreferences> createMockPreferences({
  Map<String, Object> values = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

ProviderScope createTestApp(SharedPreferences preferences) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    child: const App(),
  );
}

ProviderContainer createTestContainer(SharedPreferences preferences) {
  return ProviderContainer.test(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  );
}
