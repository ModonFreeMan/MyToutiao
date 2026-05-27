import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/feed_data_source.dart';
import '../datasources/mock_feed_datasource.dart';
import '../models/feed_item.dart';

final feedDataSourceProvider = Provider<FeedDataSource>((ref) {
  return const MockFeedDataSource();
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(dataSource: ref.watch(feedDataSourceProvider));
});

class FeedRepository {
  const FeedRepository({required this.dataSource});

  final FeedDataSource dataSource;

  Future<List<FeedItem>> fetchFeedItems({
    required int page,
    required int pageSize,
  }) {
    return dataSource.fetchFeedItems(page: page, pageSize: pageSize);
  }
}
