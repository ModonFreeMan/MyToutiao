import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:video_player_mvp/app/app.dart';
import 'package:video_player_mvp/features/feed/view_models/feed_view_model.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';

import '../helpers/fake_video_player_platform.dart';
import '../helpers/test_app.dart';

void main() {
  late FakeVideoPlayerPlatform fakeVideoPlayerPlatform;

  setUp(() {
    fakeVideoPlayerPlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakeVideoPlayerPlatform;
  });

  Finder findVerticalFeedPageView() {
    return find.byWidgetPredicate(
      (widget) => widget is PageView && widget.scrollDirection == Axis.vertical,
    );
  }

  Future<void> flingToNextPage(WidgetTester tester) async {
    await tester.drag(findVerticalFeedPageView(), const Offset(0, -700));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  testWidgets('runs the basic playback flow from feed gestures', (
    WidgetTester tester,
  ) async {
    final preferences = await createMockPreferences();
    final container = createTestContainer(preferences);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pump(const Duration(milliseconds: 700));

    var playerState = container.read(playerControllerProvider);
    expect(playerState.videoId, 'video_001');
    expect(playerState.isInitialized, isTrue);
    expect(playerState.isPlaying, isTrue);
    expect(fakeVideoPlayerPlatform.createdUris, hasLength(1));
    final initialPlayCount = fakeVideoPlayerPlatform.playCount;
    final initialPauseCount = fakeVideoPlayerPlatform.pauseCount;
    expect(initialPlayCount, greaterThanOrEqualTo(1));
    expect(find.text('5 分钟学会篮球变向运球'), findsOneWidget);

    await tester.tapAt(tester.getCenter(findVerticalFeedPageView()));
    await tester.pump(const Duration(milliseconds: 200));

    playerState = container.read(playerControllerProvider);
    expect(playerState.videoId, 'video_001');
    expect(playerState.isPlaying, isFalse);
    expect(fakeVideoPlayerPlatform.pauseCount, initialPauseCount + 1);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    await tester.tapAt(tester.getCenter(findVerticalFeedPageView()));
    await tester.pump(const Duration(milliseconds: 200));

    playerState = container.read(playerControllerProvider);
    expect(playerState.isPlaying, isTrue);
    expect(fakeVideoPlayerPlatform.playCount, initialPlayCount + 1);

    await tester.drag(find.byType(Slider), const Offset(240, 0));
    await tester.pump(const Duration(milliseconds: 200));

    expect(fakeVideoPlayerPlatform.seekedPositions, isNotEmpty);
    expect(
      fakeVideoPlayerPlatform.seekedPositions.last,
      greaterThan(Duration.zero),
    );

    await flingToNextPage(tester);

    expect(find.text('雨后城市天台的晚霞'), findsOneWidget);
    expect(container.read(feedViewModelProvider).currentIndex, 1);
    expect(container.read(playerControllerProvider).videoId, isNull);
    expect(
      container.read(playerControllerProvider.notifier).videoController,
      isNull,
    );

    await flingToNextPage(tester);

    playerState = container.read(playerControllerProvider);
    expect(find.text('周末城市骑行路线推荐'), findsOneWidget);
    expect(playerState.videoId, 'video_002');
    expect(playerState.isInitialized, isTrue);
    expect(playerState.isPlaying, isTrue);
    expect(fakeVideoPlayerPlatform.createdUris, hasLength(2));

    await container.read(playerControllerProvider.notifier).pause();
  });
}
