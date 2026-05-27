abstract interface class RecommendationDataSource {
  Future<List<String>> fetchWordsByTags(List<String> tags);

  Future<List<String>> fetchWordsByText(String text);

  Future<List<String>> fetchDefaultWords();
}
