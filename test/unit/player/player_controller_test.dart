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

    test('disposePreload is idempotent when idle', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);

      await controller.disposePreload();
      await controller.disposePreload();

      expect(controller.preloadVideoId, isNull);
      expect(controller.hasPreloadController, isFalse);
      expect(controller.preloadStatus, PreloadControllerStatus.idle);
      expect(fakePlatform.disposeCount, 0);
    });

    test('failed preload target can be retried', () async {
      fakePlatform.failInitialize = true;
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);
      final preloadItem = mockVideoFeedItems[1];

      await controller.preloadVideo(preloadItem);

      expect(controller.preloadVideoId, preloadItem.id);
      expect(controller.hasPreloadController, isFalse);
      expect(controller.preloadStatus, PreloadControllerStatus.failed);
      expect(fakePlatform.disposeCount, 1);

      fakePlatform.failInitialize = false;
      await controller.preloadVideo(preloadItem);

      expect(controller.preloadVideoId, preloadItem.id);
      expect(controller.hasPreloadController, isTrue);
      expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
      expect(fakePlatform.createdUris, hasLength(2));
      expect(fakePlatform.disposeCount, 1);
    });

    test(
      'preload initialize failure swallows cleanup dispose errors',
      () async {
        fakePlatform
          ..failInitialize = true
          ..failDispose = true;
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final preloadItem = mockVideoFeedItems[1];

        await expectLater(controller.preloadVideo(preloadItem), completes);

        expect(controller.preloadVideoId, preloadItem.id);
        expect(controller.hasPreloadController, isFalse);
        expect(controller.preloadStatus, PreloadControllerStatus.failed);
        expect(fakePlatform.disposeCount, 1);
      },
    );

    test('stale preload completion swallows cleanup dispose errors', () async {
      fakePlatform
        ..holdInitialization = true
        ..failDispose = true;
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);
      final firstPreload = mockVideoFeedItems[1];
      final secondPreload = mockVideoFeedItems[2];

      final firstPreloadFuture = controller.preloadVideo(firstPreload);
      await _settleMicrotasks();

      final secondPreloadFuture = controller.preloadVideo(secondPreload);
      await _settleMicrotasks();

      fakePlatform.releaseInitializationForCreation(0);
      await expectLater(firstPreloadFuture, completes);
      await _settleMicrotasks();

      expect(controller.preloadVideoId, secondPreload.id);
      expect(controller.preloadStatus, PreloadControllerStatus.initializing);
      expect(fakePlatform.disposeCount, 1);

      fakePlatform.failDispose = false;
      fakePlatform.releaseInitializationForCreation(1);
      await secondPreloadFuture;

      expect(controller.preloadVideoId, secondPreload.id);
      expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
    });

    test(
      'provider dispose invalidates pending preload and disposes it once',
      () async {
        fakePlatform.holdInitialization = true;
        final container = ProviderContainer.test();
        final controller = container.read(playerControllerProvider.notifier);

        final preloadFuture = controller.preloadVideo(mockVideoFeedItems[1]);
        await _settleMicrotasks();

        expect(controller.preloadStatus, PreloadControllerStatus.initializing);
        container.dispose();
        await _settleMicrotasks();

        expect(fakePlatform.disposeCount, 0);

        fakePlatform.releaseInitializationForCreation(0);
        await preloadFuture;
        await _settleMicrotasks();

        expect(fakePlatform.disposeCount, 1);
      },
    );

    test(
      'preload completion does not restore paused playback intent',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);

        await controller.playVideo(mockVideoFeedItems.first);
        await _settleMicrotasks();
        await controller.pause();
        await _settleMicrotasks();

        final stateBeforePreload = container.read(playerControllerProvider);
        final playCountBeforePreload = fakePlatform.playCount;
        fakePlatform.holdInitialization = true;

        final preloadFuture = controller.preloadVideo(mockVideoFeedItems[1]);
        await _settleMicrotasks();
        fakePlatform.releaseInitializationForCreation(1);
        await preloadFuture;
        await _settleMicrotasks();

        final stateAfterPreload = container.read(playerControllerProvider);
        expect(stateBeforePreload.wantsToPlay, isFalse);
        expect(stateAfterPreload.videoId, stateBeforePreload.videoId);
        expect(stateAfterPreload.wantsToPlay, isFalse);
        expect(stateAfterPreload.isPlaying, isFalse);
        expect(fakePlatform.playCount, playCountBeforePreload);
        expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
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
      'playVideo promotes matching preloaded controller to active',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final activeItem = mockVideoFeedItems.first;
        final preloadItem = mockVideoFeedItems[1];

        await controller.playVideo(activeItem);
        await _settleMicrotasks();
        final activeController = controller.videoController;

        await controller.preloadVideo(preloadItem);
        final preloadedController = controller.videoController;
        expect(controller.hasPreloadController, isTrue);
        expect(preloadedController, same(activeController));

        await controller.playVideo(preloadItem);
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        expect(state.videoId, preloadItem.id);
        expect(state.isInitialized, isTrue);
        expect(state.isPlaying, isTrue);
        expect(state.selectedQuality, VideoQuality.p720);
        expect(controller.videoController, isNot(same(activeController)));
        expect(controller.preloadVideoId, isNull);
        expect(controller.hasPreloadController, isFalse);
        expect(controller.preloadStatus, PreloadControllerStatus.idle);
        expect(fakePlatform.disposeCount, 1);
        expect(fakePlatform.createdUris, hasLength(2));
        expect(fakePlatform.playCount, 2);
      },
    );

    test(
      'preload initializing is a miss and falls back to active initialization',
      () async {
        fakePlatform.holdInitialization = true;
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final preloadItem = mockVideoFeedItems[1];

        final preloadFuture = controller.preloadVideo(preloadItem);
        await _settleMicrotasks();
        expect(controller.preloadStatus, PreloadControllerStatus.initializing);

        final playFuture = controller.playVideo(preloadItem);
        await _settleMicrotasks();
        expect(controller.preloadVideoId, isNull);
        expect(controller.preloadStatus, PreloadControllerStatus.idle);

        fakePlatform.releaseInitializationForCreation(0);
        await preloadFuture;
        await _settleMicrotasks();
        fakePlatform.releaseInitializationForCreation(1);
        await playFuture;
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        expect(state.videoId, preloadItem.id);
        expect(state.isInitialized, isTrue);
        expect(state.isPlaying, isTrue);
        expect(fakePlatform.createdUris, hasLength(2));
        expect(fakePlatform.disposeCount, 1);
      },
    );

    test(
      'preload failed is a miss and falls back to active initialization',
      () async {
        fakePlatform.failInitialize = true;
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final metrics = container.read(playbackStartupMetricsProvider);
        final preloadItem = mockVideoFeedItems[1];
        final startupSession = metrics.markFeedItemVisible(
          videoId: preloadItem.id,
          feedIndex: 1,
        );

        await controller.preloadVideo(preloadItem);
        expect(controller.preloadVideoId, preloadItem.id);
        expect(controller.preloadStatus, PreloadControllerStatus.failed);

        fakePlatform.failInitialize = false;
        await controller.playVideo(preloadItem, startupSession: startupSession);
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        final json = metrics.buildReport().toJson();
        expect(state.videoId, preloadItem.id);
        expect(state.isInitialized, isTrue);
        expect(state.isPlaying, isTrue);
        expect(controller.preloadVideoId, isNull);
        expect(controller.preloadStatus, PreloadControllerStatus.idle);
        expect(fakePlatform.createdUris, hasLength(2));
        expect(json['preload_misses'], 1);
        expect(json['preload_hits'], 0);
      },
    );

    test('forceRestart bypasses preload without counting miss', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(playerControllerProvider.notifier);
      final metrics = container.read(playbackStartupMetricsProvider);
      final preloadItem = mockVideoFeedItems[1];
      final startupSession = metrics.markFeedItemVisible(
        videoId: preloadItem.id,
        feedIndex: 1,
      );

      await controller.preloadVideo(preloadItem);
      await controller.playVideo(
        preloadItem,
        forceRestart: true,
        startupSession: startupSession,
      );
      await _settleMicrotasks();

      final state = container.read(playerControllerProvider);
      final json = metrics.buildReport().toJson();
      expect(state.videoId, preloadItem.id);
      expect(state.isInitialized, isTrue);
      expect(controller.preloadVideoId, preloadItem.id);
      expect(fakePlatform.createdUris, hasLength(2));
      expect(json['preload_misses'], 0);
      expect(json['preload_hits'], 0);
      expect(json['preload_visible_items'], 0);
    });

    test(
      'reusing current active video does not count unrelated preload as miss',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final metrics = container.read(playbackStartupMetricsProvider);
        final activeItem = mockVideoFeedItems.first;
        final preloadItem = mockVideoFeedItems[1];
        final startupSession = metrics.markFeedItemVisible(
          videoId: activeItem.id,
          feedIndex: 0,
        );

        await controller.playVideo(activeItem);
        await controller.preloadVideo(preloadItem);
        await _settleMicrotasks();

        await controller.playVideo(activeItem, startupSession: startupSession);
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        final json = metrics.buildReport().toJson();
        expect(state.videoId, activeItem.id);
        expect(state.isInitialized, isTrue);
        expect(state.isPlaying, isTrue);
        expect(controller.preloadVideoId, preloadItem.id);
        expect(json['preload_misses'], 0);
        expect(json['preload_visible_items'], 0);
      },
    );

    test(
      'stale promote cannot overwrite newer active and disposes extracted controller once',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final controller = container.read(playerControllerProvider.notifier);
        final metrics = container.read(playbackStartupMetricsProvider);
        final activeItem = mockVideoFeedItems.first;
        final preloadItem = mockVideoFeedItems[1];
        final newerItem = mockVideoFeedItems[2];
        final staleStartupSession = metrics.markFeedItemVisible(
          videoId: preloadItem.id,
          feedIndex: 1,
        );

        await controller.playVideo(activeItem);
        await _settleMicrotasks();
        await controller.preloadVideo(preloadItem);
        expect(fakePlatform.createdUris, hasLength(2));

        fakePlatform.holdPlay = true;
        final stalePromoteFuture = controller.playVideo(
          preloadItem,
          startupSession: staleStartupSession,
        );
        await _settleMicrotasks();

        expect(
          container.read(playerControllerProvider).videoId,
          preloadItem.id,
        );
        expect(controller.preloadVideoId, isNull);
        expect(controller.preloadStatus, PreloadControllerStatus.idle);

        fakePlatform.holdPlay = false;
        await controller.playVideo(newerItem, forceRestart: true);
        await _settleMicrotasks();

        expect(container.read(playerControllerProvider).videoId, newerItem.id);
        expect(container.read(playerControllerProvider).isPlaying, isTrue);

        fakePlatform.releasePendingPlay();
        await stalePromoteFuture;
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        final json = metrics.buildReport().toJson();
        expect(state.videoId, newerItem.id);
        expect(state.isInitialized, isTrue);
        expect(state.isPlaying, isTrue);
        expect(fakePlatform.createdUris, hasLength(3));
        expect(
          fakePlatform.disposedPlayerIds.where((id) => id == 2),
          hasLength(1),
        );
        expect(fakePlatform.disposedPlayerIds, containsAll(<int>[1, 2]));
        expect(fakePlatform.disposedPlayerIds, isNot(contains(3)));
        expect(json['preload_hits'], 1);
        expect(json['preload_promoted_to_active'], 0);
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
