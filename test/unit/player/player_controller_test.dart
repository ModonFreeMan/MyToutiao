import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/data/models/video_source.dart';
import 'package:video_player_mvp/features/observability/providers/observability_provider.dart';
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

    test('records startup metrics with the bound startup session', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);
      final metrics = container.read(playbackStartupMetricsProvider);
      final item = mockVideoFeedItems.first;
      final startupSession = metrics.markFeedItemVisible(
        videoId: item.id,
        feedIndex: 0,
      );

      await controller.playVideo(item, startupSession: startupSession);
      await _settleMicrotasks();

      final json = metrics.buildReport().toJson();
      expect(json['valid_startup_samples'], 1);
      expect(json['valid_initialize_samples'], 1);
    });

    test('closing playback closes the bound startup session', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);
      final metrics = container.read(playbackStartupMetricsProvider);
      final item = mockVideoFeedItems.first;
      final startupSession = metrics.markFeedItemVisible(
        videoId: item.id,
        feedIndex: 0,
      );

      await controller.playVideo(item, startupSession: startupSession);
      await _settleMicrotasks();
      await controller.stop();

      final json = metrics.buildReport().toJson();
      expect(json['valid_startup_samples'], 0);
      expect(json['incomplete_sessions'], 0);
    });

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

    test(
      'preloadVideo initializes an independent controller without playing',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final stateBefore = container.read(playerControllerProvider);

        await controller.preloadVideo(mockVideoFeedItems[1]);

        final stateAfter = container.read(playerControllerProvider);
        expect(controller.preloadVideoId, mockVideoFeedItems[1].id);
        expect(stateAfter.videoId, stateBefore.videoId);
        expect(stateAfter.wantsToPlay, stateBefore.wantsToPlay);
        expect(stateAfter.isPlaying, stateBefore.isPlaying);
        expect(stateAfter.isInitializing, stateBefore.isInitializing);
        expect(stateAfter.isInitialized, stateBefore.isInitialized);
        expect(stateAfter.currentPosition, stateBefore.currentPosition);
        expect(stateAfter.duration, stateBefore.duration);
        expect(stateAfter.error, stateBefore.error);
        expect(
          stateAfter.isLandscapeRendering,
          stateBefore.isLandscapeRendering,
        );
        expect(controller.videoController, isNull);
        expect(controller.hasPreloadController, isTrue);
        expect(controller.isPreloadInitialized, isTrue);
        expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
        expect(controller.preloadSelectedQuality, VideoQuality.p720);
        expect(fakePlatform.createdUris, hasLength(1));
        expect(fakePlatform.playCount, 0);
      },
    );

    test('preloadVideo does not replace active playback controller', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);
      final activeItem = mockVideoFeedItems.first;
      final preloadItem = mockVideoFeedItems[1];

      await controller.playVideo(activeItem);
      await _settleMicrotasks();
      final activeController = controller.videoController;
      final activeState = container.read(playerControllerProvider);

      await controller.preloadVideo(preloadItem);

      final state = container.read(playerControllerProvider);
      expect(controller.preloadVideoId, preloadItem.id);
      expect(state.videoId, activeState.videoId);
      expect(state.wantsToPlay, activeState.wantsToPlay);
      expect(state.isPlaying, activeState.isPlaying);
      expect(controller.videoController, same(activeController));
      expect(controller.hasPreloadController, isTrue);
      expect(controller.isPreloadInitialized, isTrue);
      expect(fakePlatform.createdUris, hasLength(2));
      expect(fakePlatform.playCount, 1);
    });

    test(
      'preloadVideo skips current active video and disposePreload clears it',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final activeItem = mockVideoFeedItems.first;
        final preloadItem = mockVideoFeedItems[1];

        await controller.preloadVideo(preloadItem);
        await controller.playVideo(activeItem);
        await _settleMicrotasks();
        await controller.preloadVideo(activeItem);

        expect(controller.preloadVideoId, preloadItem.id);

        await controller.disposePreload();

        expect(controller.preloadVideoId, isNull);
        expect(controller.hasPreloadController, isFalse);
        expect(controller.preloadStatus, PreloadControllerStatus.idle);
      },
    );

    test(
      'repeated preload for the same video reuses the preload slot',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final preloadItem = mockVideoFeedItems[1];

        await controller.preloadVideo(preloadItem);
        await controller.preloadVideo(preloadItem);

        expect(controller.preloadVideoId, preloadItem.id);
        expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
        expect(fakePlatform.createdUris, hasLength(1));
        expect(fakePlatform.disposeCount, 0);
      },
    );

    test(
      'repeated preload while initializing does not create another controller',
      () async {
        fakePlatform.holdInitialization = true;
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final preloadItem = mockVideoFeedItems[1];

        final preloadFuture = controller.preloadVideo(preloadItem);
        await _settleMicrotasks();

        expect(controller.preloadVideoId, preloadItem.id);
        expect(controller.preloadStatus, PreloadControllerStatus.initializing);
        expect(fakePlatform.createdUris, hasLength(1));

        await controller.preloadVideo(preloadItem);

        expect(fakePlatform.createdUris, hasLength(1));

        fakePlatform.releaseInitialization();
        await preloadFuture;

        expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
      },
    );

    test(
      'preloading a new video disposes the old preload controller',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);

        await controller.preloadVideo(mockVideoFeedItems[1]);
        await controller.preloadVideo(mockVideoFeedItems[2]);

        expect(controller.preloadVideoId, mockVideoFeedItems[2].id);
        expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
        expect(fakePlatform.createdUris, hasLength(2));
        expect(fakePlatform.disposeCount, 1);
      },
    );

    test(
      'late stale preload initialization success does not override current preload',
      () async {
        fakePlatform.holdInitialization = true;
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final firstPreload = mockVideoFeedItems[1];
        final secondPreload = mockVideoFeedItems[2];

        final firstPreloadFuture = controller.preloadVideo(firstPreload);
        await _settleMicrotasks();

        final secondPreloadFuture = controller.preloadVideo(secondPreload);
        await _settleMicrotasks();

        expect(controller.preloadVideoId, secondPreload.id);
        expect(controller.preloadStatus, PreloadControllerStatus.initializing);
        expect(fakePlatform.disposeCount, 0);

        fakePlatform.releaseInitializationForCreation(0);
        await firstPreloadFuture;
        await _settleMicrotasks();

        expect(controller.preloadVideoId, secondPreload.id);
        expect(controller.preloadStatus, PreloadControllerStatus.initializing);
        expect(fakePlatform.disposeCount, 1);

        fakePlatform.releaseInitializationForCreation(1);
        await secondPreloadFuture;

        expect(controller.preloadVideoId, secondPreload.id);
        expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
        expect(fakePlatform.disposeCount, 1);
      },
    );

    test(
      'late stale preload initialization failure does not override current preload',
      () async {
        fakePlatform.holdInitialization = true;
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final firstPreload = mockVideoFeedItems[1];
        final secondPreload = mockVideoFeedItems[2];

        final firstPreloadFuture = controller.preloadVideo(firstPreload);
        await _settleMicrotasks();

        final secondPreloadFuture = controller.preloadVideo(secondPreload);
        await _settleMicrotasks();

        expect(controller.preloadVideoId, secondPreload.id);
        expect(controller.preloadStatus, PreloadControllerStatus.initializing);
        expect(fakePlatform.disposeCount, 0);

        fakePlatform.failInitializationForCreation(0);
        await firstPreloadFuture;
        await _settleMicrotasks();

        expect(controller.preloadVideoId, secondPreload.id);
        expect(controller.preloadStatus, PreloadControllerStatus.initializing);
        expect(fakePlatform.disposeCount, 1);

        fakePlatform.releaseInitializationForCreation(1);
        await secondPreloadFuture;

        expect(controller.preloadVideoId, secondPreload.id);
        expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
        expect(fakePlatform.disposeCount, 1);
      },
    );

    test(
      'disposePreload invalidates pending initialization and disposes once',
      () async {
        fakePlatform.holdInitialization = true;
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final preloadItem = mockVideoFeedItems[1];

        final preloadFuture = controller.preloadVideo(preloadItem);
        await _settleMicrotasks();

        final disposeFuture = controller.disposePreload();
        await _settleMicrotasks();

        expect(controller.preloadVideoId, isNull);
        expect(controller.hasPreloadController, isFalse);
        expect(controller.preloadStatus, PreloadControllerStatus.idle);
        expect(fakePlatform.disposeCount, 0);

        fakePlatform.releaseInitializationForCreation(0);
        await preloadFuture;
        await _settleMicrotasks();

        expect(controller.preloadVideoId, isNull);
        expect(controller.preloadStatus, PreloadControllerStatus.idle);
        expect(fakePlatform.disposeCount, 1);
        await disposeFuture;
      },
    );

    test(
      'preload initialize failure does not affect active playback',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final activeItem = mockVideoFeedItems.first;
        final preloadItem = mockVideoFeedItems[1];

        await controller.playVideo(activeItem);
        await _settleMicrotasks();
        final activeState = container.read(playerControllerProvider);
        final activeController = controller.videoController;

        fakePlatform.failInitialize = true;
        await controller.preloadVideo(preloadItem);

        final state = container.read(playerControllerProvider);
        expect(controller.preloadVideoId, preloadItem.id);
        expect(controller.hasPreloadController, isFalse);
        expect(controller.preloadStatus, PreloadControllerStatus.failed);
        expect(state.videoId, activeState.videoId);
        expect(state.isPlaying, activeState.isPlaying);
        expect(state.wantsToPlay, activeState.wantsToPlay);
        expect(state.error, activeState.error);
        expect(controller.videoController, same(activeController));
        expect(fakePlatform.disposeCount, 1);
      },
    );

    test(
      'playVideo matching preload disposes preload before active initialization',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final preloadItem = mockVideoFeedItems[1];

        await controller.preloadVideo(preloadItem);
        expect(controller.hasPreloadController, isTrue);

        await controller.playVideo(preloadItem);
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        expect(state.videoId, preloadItem.id);
        expect(state.isInitialized, isTrue);
        expect(state.isPlaying, isTrue);
        expect(controller.preloadVideoId, isNull);
        expect(controller.hasPreloadController, isFalse);
        expect(fakePlatform.createdUris, hasLength(2));
        expect(fakePlatform.disposeCount, 1);
      },
    );

    test('provider dispose releases active and preload controllers', () async {
      final container = ProviderContainer.test();
      final controller = container.read(playerControllerProvider.notifier);

      await controller.playVideo(mockVideoFeedItems.first);
      await controller.preloadVideo(mockVideoFeedItems[1]);

      expect(fakePlatform.createdUris, hasLength(2));

      container.dispose();
      await _settleMicrotasks();

      expect(fakePlatform.disposeCount, 2);
    });
  });
}

Future<void> _settleMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}
