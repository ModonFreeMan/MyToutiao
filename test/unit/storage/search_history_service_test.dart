import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/features/storage/services/search_history_service.dart';
import 'package:video_player_mvp/features/storage/services/storage_service.dart';

import '../../helpers/test_app.dart';

void main() {
  group('SearchHistoryService', () {
    test('returns existing histories', () async {
      final preferences = await createMockPreferences(
        values: const {
          'search_history_keywords': ['篮球', '咖啡'],
        },
      );
      final service = SearchHistoryService(
        storageService: StorageService(preferences),
      );

      await expectLater(service.getHistories(), completion(['篮球', '咖啡']));
    });

    test('ignores empty keyword and keeps histories unchanged', () async {
      final preferences = await createMockPreferences(
        values: const {
          'search_history_keywords': ['篮球'],
        },
      );
      final service = SearchHistoryService(
        storageService: StorageService(preferences),
      );

      final histories = await service.saveKeyword('   ');

      expect(histories, ['篮球']);
      expect(preferences.getStringList('search_history_keywords'), ['篮球']);
    });

    test('adds keyword to the front', () async {
      final preferences = await createMockPreferences(
        values: const {
          'search_history_keywords': ['篮球'],
        },
      );
      final service = SearchHistoryService(
        storageService: StorageService(preferences),
      );

      final histories = await service.saveKeyword('咖啡');

      expect(histories, ['咖啡', '篮球']);
    });

    test('moves duplicated keyword to the front', () async {
      final preferences = await createMockPreferences(
        values: const {
          'search_history_keywords': ['篮球', '咖啡', '拉伸'],
        },
      );
      final service = SearchHistoryService(
        storageService: StorageService(preferences),
      );

      final histories = await service.saveKeyword('咖啡');

      expect(histories, ['咖啡', '篮球', '拉伸']);
    });

    test('keeps at most 20 histories', () async {
      final preferences = await createMockPreferences(
        values: {
          'search_history_keywords': List<String>.generate(
            20,
            (index) => '历史$index',
          ),
        },
      );
      final service = SearchHistoryService(
        storageService: StorageService(preferences),
      );

      final histories = await service.saveKeyword('最新');

      expect(histories, hasLength(20));
      expect(histories.first, '最新');
      expect(histories, isNot(contains('历史19')));
    });

    test('clears histories', () async {
      final preferences = await createMockPreferences(
        values: const {
          'search_history_keywords': ['篮球'],
        },
      );
      final service = SearchHistoryService(
        storageService: StorageService(preferences),
      );

      await service.clearHistories();

      expect(preferences.getStringList('search_history_keywords'), isNull);
    });
  });
}
