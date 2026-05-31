import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:video_player_mvp/app/app.dart';
import 'package:video_player_mvp/data/models/video_source.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';
import 'package:video_player_mvp/features/search/widgets/search_video_result_item.dart';

import '../helpers/fake_video_player_platform.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('opens search results from related search word', (
    WidgetTester tester,
  ) async {
    final preferences = await createMockPreferences();

    await tester.pumpWidget(createTestApp(preferences));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('5 分钟学会篮球变向运球'), findsOneWidget);
    expect(find.text('相关搜索'), findsOneWidget);
    expect(find.text('篮球运球教学'), findsOneWidget);

    await tester.tap(find.text('篮球运球教学'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('5 分钟学会篮球变向运球'), findsOneWidget);
    expect(find.byType(SearchVideoResultItem), findsOneWidget);
  });

  testWidgets('saves search history and shows it when returning to search', (
    WidgetTester tester,
  ) async {
    final preferences = await createMockPreferences();

    await tester.pumpWidget(createTestApp(preferences));
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('搜索你感兴趣的视频'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.enterText(find.byType(TextField), '阶段七关键词');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('没有找到“阶段七关键词”相关视频'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.widgetWithText(ActionChip, '阶段七关键词'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('搜索你感兴趣的视频'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.widgetWithText(ActionChip, '阶段七关键词'), findsOneWidget);
  });

  testWidgets('switches video quality from feed controls', (
    WidgetTester tester,
  ) async {
    final fakeVideoPlayerPlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakeVideoPlayerPlatform;

    final preferences = await createMockPreferences();
    final container = createTestContainer(preferences);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('5 分钟学会篮球变向运球'), findsOneWidget);
    expect(find.text('720P'), findsOneWidget);
    expect(fakeVideoPlayerPlatform.createdUris, hasLength(2));
    expect(
      container.read(playerControllerProvider.notifier).preloadVideoId,
      'video_002',
    );

    await tester.tap(find.byTooltip('切换清晰度'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.widgetWithText(PopupMenuItem<VideoQuality>, '1080P'),
      findsOneWidget,
    );

    await tester.tapAt(
      tester.getCenter(
        find.widgetWithText(PopupMenuItem<VideoQuality>, '1080P'),
      ),
    );
    for (var i = 0; i < 20; i += 1) {
      await tester.pump(const Duration(milliseconds: 100));
      if (container.read(playerControllerProvider).selectedQuality ==
          VideoQuality.p1080) {
        break;
      }
    }

    final playerState = container.read(playerControllerProvider);
    expect(playerState.videoId, 'video_001');
    expect(playerState.selectedQuality, VideoQuality.p1080);
    expect(playerState.isInitialized, isTrue);
    expect(playerState.isPlaying, isTrue);
    expect(find.text('1080P'), findsWidgets);
    expect(fakeVideoPlayerPlatform.createdUris, hasLength(3));

    await container.read(playerControllerProvider.notifier).pause();
    await tester.pump();
  });
}
