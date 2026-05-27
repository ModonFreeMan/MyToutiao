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
    required this.imageUrls,
    required this.description,
  }) : super(type: FeedItemType.image);

  final List<String> imageUrls;
  final String description;

  String get imageUrl => imageUrls.first;
}
