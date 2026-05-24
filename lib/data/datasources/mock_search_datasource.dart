import '../../mock/mock_feed_items.dart';
import '../models/feed_item.dart';
import '../models/video_feed_item.dart';

class MockSearchDataSource {
  const MockSearchDataSource();

  Future<List<VideoFeedItem>> searchVideos(String keyword) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) {
      return const <VideoFeedItem>[];
    }

    final scoredResults = <_ScoredVideo>[];
    for (final item in mockFeedItems) {
      if (item.type != FeedItemType.video || item is! VideoFeedItem) {
        continue;
      }

      final score = _matchScore(item, normalizedKeyword);
      if (score > 0) {
        scoredResults.add(_ScoredVideo(item: item, score: score));
      }
    }

    scoredResults.sort((a, b) => b.score.compareTo(a.score));
    return scoredResults.map((result) => result.item).toList();
  }

  int _matchScore(VideoFeedItem item, String keyword) {
    var score = 0;

    if (item.title.toLowerCase().contains(keyword)) {
      score += 5;
    }

    if (item.description.toLowerCase().contains(keyword)) {
      score += 3;
    }

    for (final tag in item.tags) {
      if (tag.toLowerCase().contains(keyword)) {
        score += 4;
      }
    }

    for (final word in item.recommendationWords) {
      if (word.toLowerCase().contains(keyword)) {
        score += 2;
      }
    }

    if (item.author.name.toLowerCase().contains(keyword)) {
      score += 1;
    }

    return score;
  }
}

class _ScoredVideo {
  const _ScoredVideo({required this.item, required this.score});

  final VideoFeedItem item;
  final int score;
}
