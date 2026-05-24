import 'author.dart';
import 'statistics.dart';

enum FeedItemType {
  video,
  image,
}

abstract class FeedItem {
  const FeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.author,
    required this.statistics,
    required this.tags,
    required this.recommendationWords,
    required this.createdAt,
  });

  final String id;
  final FeedItemType type;
  final String title;
  final Author author;
  final Statistics statistics;
  final List<String> tags;
  final List<String> recommendationWords;
  final DateTime createdAt;
}
