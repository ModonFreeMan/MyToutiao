import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_mvp/features/search/view_models/search_view_model.dart';
import 'package:video_player_mvp/features/storage/providers/storage_provider.dart';
import 'package:video_player_mvp/features/storage/services/search_history_service.dart';
import 'package:video_player_mvp/features/storage/services/storage_service.dart';

import '../../helpers/test_app.dart';

void main() {
  group('SearchViewModel', () {
    test('loads histories initially', () async {
      final preferences = await createMockPreferences(
        values: const {
          'search_history_keywords': ['篮球', '咖啡'],
        },
      );
      final container = _createContainer(preferences);
      addTearDown(container.dispose);

      await _settleMicrotasks();

      final state = container.read(searchViewModelProvider);
      expect(state.histories, ['篮球', '咖啡']);
      expect(state.isLoading, isFalse);
    });

    test('updates keyword and clears previous error', () async {
      final service = _ThrowingSearchHistoryService(
        await createMockPreferences(),
        getError: StateError('load failed'),
      );
      final container = _createContainerWithService(service);
      addTearDown(container.dispose);

      await _settleMicrotasks();
      expect(container.read(searchViewModelProvider).error, isNotNull);

      container.read(searchViewModelProvider.notifier).updateKeyword('拉伸');

      final state = container.read(searchViewModelProvider);
      expect(state.keyword, '拉伸');
      expect(state.error, isNull);
    });

    test('submits trimmed keyword and saves histories', () async {
      final preferences = await createMockPreferences(
        values: const {
          'search_history_keywords': ['篮球'],
        },
      );
      final container = _createContainer(preferences);
      addTearDown(container.dispose);

      await _settleMicrotasks();
      await container
          .read(searchViewModelProvider.notifier)
          .submitSearch('  咖啡  ');

      final state = container.read(searchViewModelProvider);
      expect(state.keyword, '咖啡');
      expect(state.histories, ['咖啡', '篮球']);
      expect(state.isSearching, isFalse);
      expect(state.error, isNull);
    });

    test('ignores empty search keyword', () async {
      final preferences = await createMockPreferences();
      final container = _createContainer(preferences);
      addTearDown(container.dispose);

      await _settleMicrotasks();
      await container.read(searchViewModelProvider.notifier).submitSearch(' ');

      final state = container.read(searchViewModelProvider);
      expect(state.keyword, '');
      expect(state.histories, isEmpty);
    });

    test('stores error when submit fails', () async {
      final service = _ThrowingSearchHistoryService(
        await createMockPreferences(),
        saveError: StateError('save failed'),
      );
      final container = _createContainerWithService(service);
      addTearDown(container.dispose);

      await _settleMicrotasks();
      await container.read(searchViewModelProvider.notifier).submitSearch('咖啡');

      final state = container.read(searchViewModelProvider);
      expect(state.isSearching, isFalse);
      expect(state.error, contains('save failed'));
    });

    test('clears histories', () async {
      final preferences = await createMockPreferences(
        values: const {
          'search_history_keywords': ['篮球'],
        },
      );
      final container = _createContainer(preferences);
      addTearDown(container.dispose);

      await _settleMicrotasks();
      await container.read(searchViewModelProvider.notifier).clearHistories();

      final state = container.read(searchViewModelProvider);
      expect(state.histories, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('stores error when clearing histories fails', () async {
      final service = _ThrowingSearchHistoryService(
        await createMockPreferences(),
        clearError: StateError('clear failed'),
      );
      final container = _createContainerWithService(service);
      addTearDown(container.dispose);

      await _settleMicrotasks();
      await container.read(searchViewModelProvider.notifier).clearHistories();

      final state = container.read(searchViewModelProvider);
      expect(state.isLoading, isFalse);
      expect(state.error, contains('clear failed'));
    });
  });
}

ProviderContainer _createContainer(SharedPreferences preferences) {
  return ProviderContainer.test(
    overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
  )..read(searchViewModelProvider);
}

ProviderContainer _createContainerWithService(SearchHistoryService service) {
  return ProviderContainer.test(
    overrides: [searchHistoryServiceProvider.overrideWithValue(service)],
  )..read(searchViewModelProvider);
}

Future<void> _settleMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

class _ThrowingSearchHistoryService extends SearchHistoryService {
  _ThrowingSearchHistoryService(
    SharedPreferences preferences, {
    this.getError,
    this.saveError,
    this.clearError,
  }) : super(storageService: StorageService(preferences));

  final Object? getError;
  final Object? saveError;
  final Object? clearError;

  @override
  Future<List<String>> getHistories() {
    final error = getError;
    if (error != null) {
      throw error;
    }

    return super.getHistories();
  }

  @override
  Future<List<String>> saveKeyword(String keyword) {
    final error = saveError;
    if (error != null) {
      throw error;
    }

    return super.saveKeyword(keyword);
  }

  @override
  Future<void> clearHistories() {
    final error = clearError;
    if (error != null) {
      throw error;
    }

    return super.clearHistories();
  }
}
