import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/data/datasources/mock_search_datasource.dart';
import 'package:video_player_mvp/mock/mock_feed_items.dart';

void main() {
  group('MockSearchDataSource', () {
    test('returns empty results for blank keyword', () async {
      const dataSource = MockSearchDataSource();

      await expectLater(dataSource.searchVideos('   '), completion(isEmpty));
    });

    test('returns only video items', () async {
      const dataSource = MockSearchDataSource();

      final results = await dataSource.searchVideos('城市');

      expect(results, isNotEmpty);
      expect(results.every((item) => item.id.startsWith('video_')), isTrue);
      expect(results.map((item) => item.id), isNot(contains('image_001')));
    });

    test('orders results by weighted match score', () async {
      const dataSource = MockSearchDataSource();

      final results = await dataSource.searchVideos('旅行');

      expect(results.map((item) => item.id).take(2), [
        'video_002',
        'video_009',
      ]);
      expect(
        mockFeedItems.where((item) => item.title.contains('雨后城市')).first.id,
        'image_001',
      );
    });

    test('matches recommendation words', () async {
      const dataSource = MockSearchDataSource();

      final results = await dataSource.searchVideos('按钮反馈');

      expect(results.map((item) => item.id), ['video_010']);
    });
  });
}
