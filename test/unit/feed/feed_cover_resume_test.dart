import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/features/feed/coordinators/feed_playback_coordinator.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';
import 'package:video_player_mvp/mock/mock_videos.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../helpers/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feed cover resume', () {
    late FakeVideoPlayerPlatform fakePlatform;

    setUp(() {
      fakePlatform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakePlatform;
    });

    test(
      'resumes playback after feed is uncovered when it was playing',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);
        final controller = container.read(playerControllerProvider.notifier);

        await controller.playVideo(mockVideoFeedItems.first);
        await _settleMicrotasks();

        final playCountBeforeCover = fakePlatform.playCount;
        final pauseCountBeforeCover = fakePlatform.pauseCount;

        await coordinator.handleFeedCovered();
        await _settleMicrotasks();

        expect(container.read(playerControllerProvider).isPlaying, isFalse);
        expect(fakePlatform.pauseCount, pauseCountBeforeCover + 1);

        await coordinator.handleFeedUncovered();
        await _settleMicrotasks();

        expect(container.read(playerControllerProvider).isPlaying, isTrue);
        expect(fakePlatform.playCount, playCountBeforeCover + 1);
      },
    );

    test(
      'does not resume after feed is uncovered when it was paused',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);
        final controller = container.read(playerControllerProvider.notifier);

        await controller.playVideo(mockVideoFeedItems.first);
        await _settleMicrotasks();
        await controller.pause();
        await _settleMicrotasks();

        final playCountBeforeCover = fakePlatform.playCount;
        final pauseCountBeforeCover = fakePlatform.pauseCount;

        await coordinator.handleFeedCovered();
        await _settleMicrotasks();
        await coordinator.handleFeedUncovered();
        await _settleMicrotasks();

        expect(container.read(playerControllerProvider).isPlaying, isFalse);
        expect(fakePlatform.playCount, playCountBeforeCover);
        expect(fakePlatform.pauseCount, pauseCountBeforeCover + 1);
      },
    );
  });
}

Future<void> _settleMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}
