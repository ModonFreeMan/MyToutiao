import '../../mock/mock_feed_items.dart';
import '../models/feed_item.dart';

class MockFeedDataSource {
  const MockFeedDataSource();

  Future<List<FeedItem>> fetchFeedItems({
    required int page,
    required int pageSize,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final start = (page - 1) * pageSize;
    if (start >= mockFeedItems.length) {
      return const <FeedItem>[];
    }

    final end = (start + pageSize).clamp(0, mockFeedItems.length);
    return mockFeedItems.sublist(start, end);
  }
}
