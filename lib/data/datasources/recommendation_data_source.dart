abstract interface class RecommendationDataSource {
  Future<List<String>> fetchWordsByTags(List<String> tags);

  Future<List<String>> fetchDefaultWords();
}
