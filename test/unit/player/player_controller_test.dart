import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/data/models/video_source.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';
import 'package:video_player_mvp/mock/mock_videos.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../helpers/fake_video_player_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerController', () {
    late FakeVideoPlayerPlatform fakePlatform;

    setUp(() {
      fakePlatform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakePlatform;
    });

    test(
      'plays a video and reuses initialized controller for same video',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final item = mockVideoFeedItems.first;

        await controller.playVideo(item);
        await _settleMicrotasks();

        var state = container.read(playerControllerProvider);
        expect(state.videoId, item.id);
        expect(state.selectedQuality, VideoQuality.p720);
        expect(state.isInitialized, isTrue);
        expect(state.isPlaying, isTrue);
        expect(fakePlatform.createdUris, hasLength(1));

        await controller.playVideo(item);
        await _settleMicrotasks();

        state = container.read(playerControllerProvider);
        expect(state.isPlaying, isTrue);
        expect(fakePlatform.createdUris, hasLength(1));
      },
    );

    test('stores error when initialization fails', () async {
      fakePlatform.failInitialize = true;
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      await container
          .read(playerControllerProvider.notifier)
          .playVideo(mockVideoFeedItems.first);

      final state = container.read(playerControllerProvider);
      expect(state.videoId, 'video_001');
      expect(state.isInitializing, isFalse);
      expect(state.isInitialized, isFalse);
      expect(state.isPlaying, isFalse);
      expect(state.error, isNotNull);
    });

    test('switches quality and keeps previous position', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);
      final item = mockVideoFeedItems.first;

      await controller.playVideo(item);
      await _settleMicrotasks();
      await controller.seekToProgress(0.5);
      await _settleMicrotasks();

      await controller.switchQuality(item, VideoQuality.p1080);
      await _settleMicrotasks();

      final state = container.read(playerControllerProvider);
      expect(state.selectedQuality, VideoQuality.p1080);
      expect(state.isInitialized, isTrue);
      expect(state.isPlaying, isTrue);
      expect(state.currentPosition, const Duration(minutes: 1));
      expect(fakePlatform.createdUris, hasLength(2));
      expect(fakePlatform.seekedPositions.last, const Duration(minutes: 1));
    });

    test('clamps seek progress to valid range', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);

      await controller.playVideo(mockVideoFeedItems.first);
      await _settleMicrotasks();

      await controller.seekToProgress(2);
      await _settleMicrotasks();
      expect(fakePlatform.seekedPositions.last, const Duration(minutes: 2));

      await controller.seekToProgress(-1);
      await _settleMicrotasks();
      expect(fakePlatform.seekedPositions.last, Duration.zero);
    });

    test('stopIfCurrent only stops the active video', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);

      await controller.playVideo(mockVideoFeedItems.first);
      await _settleMicrotasks();

      await controller.stopIfCurrent('video_999');
      expect(container.read(playerControllerProvider).videoId, 'video_001');

      await controller.stopIfCurrent('video_001');
      expect(container.read(playerControllerProvider).videoId, isNull);
      expect(fakePlatform.disposeCount, 1);
    });

    test(
      'stop clears business state before platform dispose completes',
      () async {
        fakePlatform.holdDispose = true;
        addTearDown(fakePlatform.releasePendingDispose);
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);

        await controller.playVideo(mockVideoFeedItems.first);
        await _settleMicrotasks();
        expect(container.read(playerControllerProvider).videoId, 'video_001');

        final stopFuture = controller.stop();
        await _settleMicrotasks();

        expect(container.read(playerControllerProvider).videoId, isNull);

        fakePlatform.releasePendingDispose();
        await stopFuture;
      },
    );

    test('pause and resume are safe before initialization', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);

      await controller.pause();
      await controller.resume();
      await controller.togglePlayPause();

      expect(container.read(playerControllerProvider).videoId, isNull);
      expect(fakePlatform.pauseCount, 0);
      expect(fakePlatform.playCount, 0);
    });

    test('native pause keeps playback intent until user pauses', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);

      await controller.playVideo(mockVideoFeedItems.first);
      await _settleMicrotasks();

      fakePlatform.emitIsPlayingState(false);
      await _settleMicrotasks();

      var state = container.read(playerControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.wantsToPlay, isTrue);

      await controller.ensurePlaybackIntent(mockVideoFeedItems.first.id);
      await _settleMicrotasks();

      state = container.read(playerControllerProvider);
      expect(state.isPlaying, isTrue);
      expect(state.wantsToPlay, isTrue);

      await controller.pause();
      await _settleMicrotasks();

      state = container.read(playerControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(state.wantsToPlay, isFalse);
    });
  });
}

Future<void> _settleMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}
