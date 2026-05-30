import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/data/models/video_source.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';
import 'package:video_player_mvp/mock/mock_videos.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerController', () {
    late _FakeVideoPlayerPlatform fakePlatform;

    setUp(() {
      fakePlatform = _FakeVideoPlayerPlatform();
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

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _eventControllers = <int, StreamController<VideoEvent>>{};
  final createdUris = <String>[];
  final seekedPositions = <Duration>[];
  final _positions = <int, Duration>{};
  int _nextPlayerId = 0;
  int pauseCount = 0;
  int playCount = 0;
  int disposeCount = 0;
  bool failInitialize = false;
  bool holdDispose = false;
  Completer<void>? _pendingDisposeCompleter;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = ++_nextPlayerId;
    createdUris.add(options.dataSource.uri ?? options.dataSource.asset ?? '');
    _positions[playerId] = Duration.zero;
    _eventControllers[playerId] = StreamController<VideoEvent>.broadcast();
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final controller = _eventControllers[playerId]!;
    Timer.run(() {
      if (controller.isClosed) {
        return;
      }

      if (failInitialize) {
        controller.addError(
          PlatformException(code: 'test', message: 'initialize failed'),
        );
        return;
      }

      controller.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(minutes: 2),
          size: const Size(1280, 720),
          rotationCorrection: 0,
        ),
      );
    });
    return controller.stream;
  }

  @override
  Widget buildView(int playerId) {
    return ColoredBox(
      key: ValueKey<String>('fake-video-view-$playerId'),
      color: Colors.black,
    );
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return buildView(options.playerId);
  }

  @override
  Future<void> dispose(int playerId) async {
    disposeCount += 1;
    if (holdDispose) {
      _pendingDisposeCompleter = Completer<void>();
      await _pendingDisposeCompleter!.future;
    }
    await _eventControllers.remove(playerId)?.close();
    _positions.remove(playerId);
  }

  void releasePendingDispose() {
    holdDispose = false;
    final completer = _pendingDisposeCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    playCount += 1;
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCount += 1;
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seekedPositions.add(position);
    _positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    return _positions[playerId] ?? Duration.zero;
  }

  void setCurrentPosition(Duration position) {
    for (final playerId in _positions.keys) {
      _positions[playerId] = position;
    }
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
