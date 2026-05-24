import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:video_player_mvp/app/app.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';

void main() {
  late _FakeVideoPlayerPlatform fakeVideoPlayerPlatform;

  setUp(() {
    fakeVideoPlayerPlatform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakeVideoPlayerPlatform;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('runs the video flow from feed to search result and playback', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pump(const Duration(milliseconds: 700));

    var playerState = container.read(playerControllerProvider);
    expect(playerState.videoId, 'video_001');
    expect(playerState.isInitialized, isTrue);
    expect(playerState.isPlaying, isTrue);
    expect(find.text('5 分钟学会篮球变向运球'), findsOneWidget);
    expect(find.text('720P'), findsOneWidget);

    await tester.tap(find.text('搜索你感兴趣的视频'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(fakeVideoPlayerPlatform.pauseCount, greaterThanOrEqualTo(1));
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), '手冲');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('手冲咖啡入门：稳定萃取三件事'), findsOneWidget);

    await tester.tap(find.text('手冲咖啡入门：稳定萃取三件事'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 300));

    playerState = container.read(playerControllerProvider);
    expect(find.text('搜索你感兴趣的视频'), findsOneWidget);
    expect(find.text('手冲咖啡入门：稳定萃取三件事'), findsOneWidget);
    expect(playerState.videoId, 'video_005');
    expect(playerState.isInitialized, isTrue);
    expect(playerState.isPlaying, isTrue);

    expect(fakeVideoPlayerPlatform.createdUris.last, contains('bee.mp4'));

    await container.read(playerControllerProvider.notifier).togglePlayPause();
    await tester.pump(const Duration(milliseconds: 200));

    playerState = container.read(playerControllerProvider);
    expect(playerState.isPlaying, isFalse);
    expect(fakeVideoPlayerPlatform.pauseCount, greaterThanOrEqualTo(2));
  });
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _eventControllers = <int, StreamController<VideoEvent>>{};
  final createdUris = <String>[];
  final _positions = <int, Duration>{};
  int _nextPlayerId = 0;
  int pauseCount = 0;

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
    final nextPosition =
        (_positions[playerId] ?? Duration.zero) +
        const Duration(milliseconds: 100);
    _positions[playerId] = nextPosition;
    return nextPosition;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
