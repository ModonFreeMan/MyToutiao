import 'feed_item.dart';

class ImageFeedItem extends FeedItem {
  const ImageFeedItem({
    required super.id,
    required super.title,
    required super.author,
    required super.statistics,
    required super.tags,
    required super.recommendationWords,
    required super.createdAt,
    required this.imageUrl,
    required this.description,
  }) : super(type: FeedItemType.image);

  final String imageUrl;
  final String description;
}
