import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:video_player_mvp/app/app.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';

import '../helpers/fake_video_player_platform.dart';
import '../helpers/test_app.dart';

void main() {
  late FakeVideoPlayerPlatform fakeVideoPlayerPlatform;

  setUp(() {
    fakeVideoPlayerPlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakeVideoPlayerPlatform;
  });

  testWidgets('runs the video flow from feed to search result and playback', (
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
