import '../models/feed_item.dart';

abstract interface class FeedDataSource {
  Future<List<FeedItem>> fetchFeedItems({
    required int page,
    required int pageSize,
  });
}
