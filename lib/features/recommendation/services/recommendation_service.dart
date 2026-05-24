import '../../../data/models/feed_item.dart';
import '../../../data/repositories/recommendation_repository.dart';

class RecommendationService {
  const RecommendationService({required this.repository});

  final RecommendationRepository repository;

  Future<List<String>> matchWords(FeedItem item) async {
    if (item.recommendationWords.isNotEmpty) {
      return item.recommendationWords;
    }

    final tagWords = await repository.fetchWordsByTags(item.tags);
    if (tagWords.isNotEmpty) {
      return tagWords;
    }

    return repository.fetchDefaultWords();
  }
}
