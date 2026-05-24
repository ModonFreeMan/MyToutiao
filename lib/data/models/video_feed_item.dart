import 'feed_item.dart';
import 'video_source.dart';

class VideoFeedItem extends FeedItem {
  const VideoFeedItem({
    required super.id,
    required super.title,
    required super.author,
    required super.statistics,
    required super.tags,
    required super.recommendationWords,
    required super.createdAt,
    required this.videoSources,
    required this.coverUrl,
    required this.duration,
    required this.description,
  }) : super(type: FeedItemType.video);

  final List<VideoSource> videoSources;
  final String coverUrl;
  final Duration duration;
  final String description;

  VideoSource sourceForQuality(VideoQuality quality) {
    return videoSources.firstWhere(
      (source) => source.quality == quality,
      orElse: () => videoSources.first,
    );
  }
}
