import '../models/video_feed_item.dart';

abstract interface class SearchDataSource {
  Future<List<VideoFeedItem>> searchVideos(String keyword);
}
