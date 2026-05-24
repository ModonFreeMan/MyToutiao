import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/mock_search_datasource.dart';
import '../models/video_feed_item.dart';

final mockSearchDataSourceProvider = Provider<MockSearchDataSource>((ref) {
  return const MockSearchDataSource();
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(dataSource: ref.watch(mockSearchDataSourceProvider));
});

class SearchRepository {
  const SearchRepository({required this.dataSource});

  final MockSearchDataSource dataSource;

  Future<List<VideoFeedItem>> searchVideos(String keyword) {
    return dataSource.searchVideos(keyword);
  }
}
