import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';
import 'package:video_player_mvp/mock/mock_videos.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../helpers/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerController progress preservation', () {
    late FakeVideoPlayerPlatform fakePlatform;

    setUp(() {
      fakePlatform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakePlatform;
    });

    test(
      'pause preserves platform position before cached position updates',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);

        await controller.playVideo(mockVideoFeedItems.first);
        await _settleMicrotasks();

        fakePlatform.setCurrentPosition(const Duration(seconds: 3));

        await controller.togglePlayPause();
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        expect(state.isPlaying, isFalse);
        expect(state.currentPosition, const Duration(seconds: 3));
      },
    );

    test(
      'resume keeps paused progress before cached position updates',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);

        await controller.playVideo(mockVideoFeedItems.first);
        await _settleMicrotasks();

        await controller.seekToProgress(3000 / 120000);
        fakePlatform.setCurrentPosition(const Duration(milliseconds: 3200));

        await controller.pause();
        await _settleMicrotasks();

        expect(
          container.read(playerControllerProvider).currentPosition,
          const Duration(milliseconds: 3200),
        );

        await controller.resume();
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        expect(state.isPlaying, isTrue);
        expect(state.currentPosition, const Duration(milliseconds: 3200));
      },
    );

    test(
      'resume keeps non-initial paused progress before cached position updates',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);

        await controller.playVideo(mockVideoFeedItems.first);
        await _settleMicrotasks();

        await controller.seekToProgress(8100 / 120000);
        fakePlatform.setCurrentPosition(const Duration(milliseconds: 8400));

        await controller.pause();
        await _settleMicrotasks();

        expect(
          container.read(playerControllerProvider).currentPosition,
          const Duration(milliseconds: 8400),
        );

        await controller.resume();
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        expect(state.isPlaying, isTrue);
        expect(state.currentPosition, const Duration(milliseconds: 8400));
      },
    );

    test(
      'tap resume does not move progress backward by stale cached offsets',
      () async {
        final cases = <({Duration cached, Duration actual})>[
          (
            cached: Duration(milliseconds: 2870),
            actual: Duration(milliseconds: 3140),
          ),
          (
            cached: Duration(milliseconds: 6730),
            actual: Duration(milliseconds: 6895),
          ),
          (
            cached: Duration(milliseconds: 10420),
            actual: Duration(milliseconds: 10810),
          ),
        ];

        for (final testCase in cases) {
          final container = ProviderContainer.test();
          addTearDown(container.dispose);
          final controller = container.read(playerControllerProvider.notifier);

          await controller.playVideo(mockVideoFeedItems.first);
          await _settleMicrotasks();

          await controller.seekToProgress(
            testCase.cached.inMilliseconds / 120000,
          );
          fakePlatform.setCurrentPosition(testCase.actual);

          await controller.togglePlayPause();
          await _settleMicrotasks();

          expect(
            container.read(playerControllerProvider).currentPosition,
            testCase.actual,
          );

          await controller.togglePlayPause();
          await _settleMicrotasks();

          final state = container.read(playerControllerProvider);
          expect(state.isPlaying, isTrue);
          expect(
            state.currentPosition,
            testCase.actual,
            reason:
                'tap resume must not regress by '
                '${testCase.actual - testCase.cached}',
          );
        }
      },
    );

    test(
      'tap resume realigns playback to paused position when cache lagged',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);

        await controller.playVideo(mockVideoFeedItems.first);
        await _settleMicrotasks();

        const cachedPosition = Duration(milliseconds: 8100);
        const pausedPosition = Duration(milliseconds: 8400);

        await controller.seekToProgress(cachedPosition.inMilliseconds / 120000);
        fakePlatform.setCurrentPosition(pausedPosition);

        await controller.togglePlayPause();
        await _settleMicrotasks();

        expect(
          container.read(playerControllerProvider).currentPosition,
          pausedPosition,
        );

        final seekCountBeforeResume = fakePlatform.seekedPositions.length;

        await controller.togglePlayPause();
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        expect(state.isPlaying, isTrue);
        expect(state.currentPosition, pausedPosition);
        expect(
          fakePlatform.seekedPositions.skip(seekCountBeforeResume),
          contains(pausedPosition),
          reason:
              'tap resume should realign platform playback to the paused '
              'position when cached position lags by '
              '${pausedPosition - cachedPosition}',
        );
      },
    );
  });
}

Future<void> _settleMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}
