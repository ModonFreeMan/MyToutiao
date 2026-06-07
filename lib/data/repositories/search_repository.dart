import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/dense_search_datasource.dart';
import '../datasources/search_data_source.dart';
import '../models/video_feed_item.dart';

final searchDataSourceProvider = Provider<SearchDataSource>((ref) {
  return DenseSearchDataSource.localConfig();
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
