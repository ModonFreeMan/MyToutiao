import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';
import 'package:video_player_mvp/mock/mock_videos.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../helpers/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerController initialization race', () {
    late FakeVideoPlayerPlatform fakePlatform;

    setUp(() {
      fakePlatform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakePlatform;
    });

    test('stale initialization cannot overwrite the latest video', () async {
      fakePlatform.holdInitialization = true;
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);
      final firstItem = mockVideoFeedItems.first;
      final secondItem = mockVideoFeedItems[1];

      final firstPlay = controller.playVideo(firstItem);
      await _settleMicrotasks();

      expect(container.read(playerControllerProvider).videoId, firstItem.id);
      expect(container.read(playerControllerProvider).isInitializing, isTrue);

      final secondPlay = controller.playVideo(secondItem);
      await _settleMicrotasks();

      expect(container.read(playerControllerProvider).videoId, secondItem.id);
      expect(container.read(playerControllerProvider).isInitializing, isTrue);

      fakePlatform.releaseInitialization();
      await Future.wait([firstPlay, secondPlay]);
      await _settleMicrotasks();

      final state = container.read(playerControllerProvider);
      expect(state.videoId, secondItem.id);
      expect(state.isInitialized, isTrue);
      expect(state.isPlaying, isTrue);
      expect(fakePlatform.createdUris, hasLength(2));
      expect(fakePlatform.disposeCount, 1);
    });
  });
}

Future<void> _settleMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}
