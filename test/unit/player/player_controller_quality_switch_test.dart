import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/data/models/video_source.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';
import 'package:video_player_mvp/mock/mock_videos.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../helpers/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerController quality switch', () {
    late FakeVideoPlayerPlatform fakePlatform;

    setUp(() {
      fakePlatform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakePlatform;
    });

    test('stores error when switching quality fails', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);
      final item = mockVideoFeedItems.first;

      await controller.playVideo(item);
      await _settleMicrotasks();
      await controller.seekToProgress(0.5);
      await _settleMicrotasks();

      fakePlatform.failInitialize = true;

      await controller.switchQuality(item, VideoQuality.p1080);
      await _settleMicrotasks();

      final state = container.read(playerControllerProvider);
      expect(state.videoId, item.id);
      expect(state.selectedQuality, VideoQuality.p1080);
      expect(state.currentPosition, const Duration(minutes: 1));
      expect(state.isInitializing, isFalse);
      expect(state.isInitialized, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.error, isNotNull);
      expect(fakePlatform.disposeCount, 2);
    });
  });
}

Future<void> _settleMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}
