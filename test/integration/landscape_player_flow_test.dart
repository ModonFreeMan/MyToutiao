import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/app/app.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../helpers/fake_video_player_platform.dart';
import '../helpers/test_app.dart';

void main() {
  late FakeVideoPlayerPlatform fakeVideoPlayerPlatform;

  setUp(() {
    fakeVideoPlayerPlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakeVideoPlayerPlatform;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('opens and closes landscape player from feed video', (
    WidgetTester tester,
  ) async {
    final preferences = await createMockPreferences();
    final container = createTestContainer(preferences);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(container.read(playerControllerProvider).videoId, 'video_001');
    expect(container.read(playerControllerProvider).isPlaying, isTrue);

    await tester.tap(find.byTooltip('横屏播放'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    var playerState = container.read(playerControllerProvider);
    expect(playerState.videoId, 'video_001');
    expect(playerState.isLandscapeRendering, isTrue);
    expect(find.text('5 分钟学会篮球变向运球'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    playerState = container.read(playerControllerProvider);
    expect(playerState.videoId, 'video_001');
    expect(playerState.isLandscapeRendering, isFalse);
    expect(playerState.isPlaying, isTrue);
    expect(find.byTooltip('横屏播放'), findsOneWidget);

    await container.read(playerControllerProvider.notifier).pause();
    await tester.pump();
  });
}
