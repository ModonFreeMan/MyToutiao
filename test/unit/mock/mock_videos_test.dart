import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/mock/mock_videos.dart';

void main() {
  group('mock video sources', () {
    test('include remote fallback sample videos', () {
      final urls = mockVideoFeedItems
          .expand((item) => item.videoSources)
          .map((source) => source.url)
          .toSet();

      expect(
        urls,
        containsAll(const [
          'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
          'https://flutter.github.io/assets-for-api-docs/assets/videos/hls/bee.m3u8',
          'https://media.w3.org/2010/05/video/movie_300.mp4',
        ]),
      );
    });

    test('include local Eyevinn multi-variant HLS sample for quality switching', () {
      final urls = mockVideoFeedItems
          .expand((item) => item.videoSources)
          .map((source) => source.url)
          .toSet();

      expect(
        urls,
        containsAll(const [
          'http://192.168.1.13:8080/video_sources/eyevinn-vinn/360p/index.m3u8',
          'http://192.168.1.13:8080/video_sources/eyevinn-vinn/720p/index.m3u8',
          'http://192.168.1.13:8080/video_sources/eyevinn-vinn/1080p/index.m3u8',
        ]),
      );
    });

    test('use local HLS variants for local playback mock videos', () {
      final localPlaybackItems = mockVideoFeedItems.take(9);

      for (final item in localPlaybackItems) {
        expect(
          item.videoSources.every(
            (source) =>
                source.url.startsWith('http://192.168.1.13:8080/') &&
                source.url.contains('.m3u8'),
          ),
          isTrue,
          reason: item.id,
        );
      }
    });

    test('include multiple local quality-switching samples', () {
      final urls = mockVideoFeedItems
          .expand((item) => item.videoSources)
          .map((source) => source.url)
          .toSet();

      expect(
        urls,
        containsAll(const [
          'http://192.168.1.13:8080/video_sources/big-buck-bunny/1080p/index.m3u8',
          'http://192.168.1.13:8080/video_sources/sintel/1080p/index.m3u8',
          'http://192.168.1.13:8080/video_sources/mux-test-stream/1080p/index.m3u8',
          'http://192.168.1.13:8080/video_sources/mux-arte-china/1080p/index.m3u8',
          'http://192.168.1.13:8080/video_sources/apple-bipbop/1080p/index.m3u8',
          'http://192.168.1.13:8080/video_sources/tears-of-steel/1080p/index.m3u8',
          'http://192.168.1.13:8080/video_sources/eyevinn-tears-of-steel-4k/1080p/index.m3u8',
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
