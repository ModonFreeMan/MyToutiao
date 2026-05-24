import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/mock_recommendation_datasource.dart';

final mockRecommendationDataSourceProvider =
    Provider<MockRecommendationDataSource>((ref) {
      return const MockRecommendationDataSource();
    });

final recommendationRepositoryProvider = Provider<RecommendationRepository>((
  ref,
) {
  return RecommendationRepository(
    dataSource: ref.watch(mockRecommendationDataSourceProvider),
  );
});

class RecommendationRepository {
  const RecommendationRepository({required this.dataSource});

  final MockRecommendationDataSource dataSource;

  Future<List<String>> fetchWordsByTags(List<String> tags) {
    return dataSource.fetchWordsByTags(tags);
  }

  Future<List<String>> fetchDefaultWords() {
    return dataSource.fetchDefaultWords();
  }
}
