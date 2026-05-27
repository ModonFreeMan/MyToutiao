import '../../mock/mock_recommendations.dart';
import 'recommendation_data_source.dart';

class MockRecommendationDataSource implements RecommendationDataSource {
  const MockRecommendationDataSource();

  @override
  Future<List<String>> fetchWordsByTags(List<String> tags) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    final words = <String>[];
    for (final tag in tags) {
      words.addAll(mockRecommendationWordsByTag[tag] ?? const <String>[]);
    }

    return words.toSet().toList();
  }

  @override
  Future<List<String>> fetchDefaultWords() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return mockDefaultRecommendationWords;
  }
}
