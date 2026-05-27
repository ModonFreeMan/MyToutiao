import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/recommendation_data_source.dart';
import '../datasources/mock_recommendation_datasource.dart';

final recommendationDataSourceProvider = Provider<RecommendationDataSource>((
  ref,
) {
  return const MockRecommendationDataSource();
});

final recommendationRepositoryProvider = Provider<RecommendationRepository>((
  ref,
) {
  return RecommendationRepository(
    dataSource: ref.watch(recommendationDataSourceProvider),
  );
});

class RecommendationRepository {
  const RecommendationRepository({required this.dataSource});

  final RecommendationDataSource dataSource;

  Future<List<String>> fetchWordsByTags(List<String> tags) {
    return dataSource.fetchWordsByTags(tags);
  }

  Future<List<String>> fetchWordsByText(String text) {
    return dataSource.fetchWordsByText(text);
  }

  Future<List<String>> fetchDefaultWords() {
    return dataSource.fetchDefaultWords();
  }
}
