import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:video_player_mvp/app/app.dart';
import 'package:video_player_mvp/data/datasources/mock_search_datasource.dart';
import 'package:video_player_mvp/data/repositories/search_repository.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';
import 'package:video_player_mvp/features/storage/providers/storage_provider.dart';

import '../helpers/fake_video_player_platform.dart';
import '../helpers/test_app.dart';

void main() {
  setUp(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  testWidgets(
    'opens a distant search result without landing on an intermediate page',
    (WidgetTester tester) async {
      final preferences = await createMockPreferences();
      final container = ProviderContainer.test(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          searchDataSourceProvider.overrideWithValue(
            const MockSearchDataSource(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.text('搜索你感兴趣的视频'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.enterText(find.byType(TextField), '城市');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('西湖一日徒步路线：避开拥挤打卡点'), findsOneWidget);

      await tester.tap(find.text('西湖一日徒步路线：避开拥挤打卡点'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 300));

      final playerState = container.read(playerControllerProvider);
      expect(find.text('搜索你感兴趣的视频'), findsOneWidget);
      expect(find.text('西湖一日徒步路线：避开拥挤打卡点'), findsAtLeastNWidgets(1));
      expect(find.text('家常番茄牛腩这样炖更入味'), findsNothing);
      expect(playerState.videoId, 'video_009');
      expect(playerState.isInitialized, isTrue);
      expect(playerState.isPlaying, isTrue);

      await container.read(playerControllerProvider.notifier).pause();
      await tester.pump(const Duration(milliseconds: 200));
    },
  );
}
