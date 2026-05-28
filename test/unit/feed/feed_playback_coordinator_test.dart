import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/features/feed/coordinators/feed_playback_coordinator.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';
import 'package:video_player_mvp/mock/mock_videos.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedPlaybackCoordinator', () {
    late _FakeVideoPlayerPlatform fakePlatform;

    setUp(() {
      fakePlatform = _FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakePlatform;
    });

    test('starts playback when a non-current video card is tapped', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);
      final item = mockVideoFeedItems.first;

      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();

      final state = container.read(playerControllerProvider);
      expect(state.videoId, item.id);
      expect(state.isInitialized, isTrue);
      expect(state.isPlaying, isTrue);
      expect(fakePlatform.createdUris, hasLength(1));
      expect(fakePlatform.playCount, 1);
    });

    test('toggles current video playback when video card is tapped', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);
      final item = mockVideoFeedItems.first;

      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();
      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();

      var state = container.read(playerControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(fakePlatform.pauseCount, greaterThanOrEqualTo(1));

      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();

      state = container.read(playerControllerProvider);
      expect(state.isPlaying, isTrue);
      expect(fakePlatform.playCount, greaterThanOrEqualTo(2));
      expect(fakePlatform.createdUris, hasLength(1));
    });

    test('prepares current video for landscape rendering', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);
      final item = mockVideoFeedItems.first;

      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();
      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();

      expect(container.read(playerControllerProvider).isPlaying, isFalse);

      await coordinator.handleLandscapeRequested(item);
      await _settleMicrotasks();

      var state = container.read(playerControllerProvider);
      expect(state.videoId, item.id);
      expect(state.isPlaying, isTrue);
      expect(state.isLandscapeRendering, isTrue);
      expect(fakePlatform.createdUris, hasLength(1));

      coordinator.handleLandscapeClosed();

      state = container.read(playerControllerProvider);
      expect(state.isLandscapeRendering, isFalse);
    });

    test('landscape request initializes target video when needed', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);
      final item = mockVideoFeedItems[1];

      await coordinator.handleLandscapeRequested(item);
      await _settleMicrotasks();

      final state = container.read(playerControllerProvider);
      expect(state.videoId, item.id);
      expect(state.isInitialized, isTrue);
      expect(state.isPlaying, isTrue);
      expect(state.isLandscapeRendering, isTrue);
      expect(fakePlatform.createdUris, hasLength(1));
    });
  });
}

Future<void> _settleMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _eventControllers = <int, StreamController<VideoEvent>>{};
  final createdUris = <String>[];
  final _positions = <int, Duration>{};
  int _nextPlayerId = 0;
  int pauseCount = 0;
  int playCount = 0;

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
    await _eventControllers.remove(playerId)?.close();
    _positions.remove(playerId);
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
    _positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    return _positions[playerId] ?? Duration.zero;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
