import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/mock_feed_datasource.dart';
import '../models/feed_item.dart';

final mockFeedDataSourceProvider = Provider<MockFeedDataSource>((ref) {
  return const MockFeedDataSource();
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(dataSource: ref.watch(mockFeedDataSourceProvider));
});

class FeedRepository {
  const FeedRepository({required this.dataSource});

  final MockFeedDataSource dataSource;

  Future<List<FeedItem>> fetchFeedItems({
    required int page,
    required int pageSize,
  }) {
    return dataSource.fetchFeedItems(page: page, pageSize: pageSize);
  }
}
