import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/search_data_source.dart';
import '../datasources/mock_search_datasource.dart';
import '../models/video_feed_item.dart';

final searchDataSourceProvider = Provider<SearchDataSource>((ref) {
  return const MockSearchDataSource();
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(dataSource: ref.watch(searchDataSourceProvider));
});

class SearchRepository {
  const SearchRepository({required this.dataSource});

  final SearchDataSource dataSource;

  Future<List<VideoFeedItem>> searchVideos(String keyword) {
    return dataSource.searchVideos(keyword);
  }
}
