import '../../../data/models/feed_item.dart';
import '../../../data/models/image_feed_item.dart';
import '../../../data/models/video_feed_item.dart';
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

    final titleWords = await repository.fetchWordsByText(item.title);
    if (titleWords.isNotEmpty) {
      return titleWords;
    }

    final descriptionWords = await repository.fetchWordsByText(
      _descriptionOf(item),
    );
    if (descriptionWords.isNotEmpty) {
      return descriptionWords;
    }

    return repository.fetchDefaultWords();
  }

  String _descriptionOf(FeedItem item) {
    return switch (item) {
      VideoFeedItem(:final description) => description,
      ImageFeedItem(:final description) => description,
      _ => '',
    };
  }
}
