import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/mock/mock_videos.dart';

void main() {
  group('mock video sources', () {
    test('include Flutter sample videos', () {
      final urls = mockVideoFeedItems
          .expand((item) => item.videoSources)
          .map((source) => source.url)
          .toSet();

      expect(
        urls,
        containsAll(const [
          'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
          'https://flutter.github.io/assets-for-api-docs/assets/videos/hls/bee.m3u8',
          'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
        ]),
      );
    });

    test('use different urls for different qualities', () {
      for (final item in mockVideoFeedItems) {
        final urls = item.videoSources.map((source) => source.url).toSet();

        expect(urls, hasLength(item.videoSources.length), reason: item.id);
      }
    });
  });
}
