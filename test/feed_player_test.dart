import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_player_mvp/app/app.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';

import 'test_app.dart';

void main() {
  Finder findVerticalFeedPageView() {
    return find.byWidgetPredicate(
      (widget) => widget is PageView && widget.scrollDirection == Axis.vertical,
    );
  }

  Future<void> flingToNextPage(WidgetTester tester) async {
    await tester.fling(findVerticalFeedPageView(), const Offset(0, -500), 1000);
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('starts player for video item and stops on image item', (
    WidgetTester tester,
  ) async {
    final preferences = await createMockPreferences();
    final container = createTestContainer(preferences);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );

    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(playerControllerProvider).videoId, 'video_001');
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

    await flingToNextPage(tester);

    expect(find.text('雨后城市天台的晚霞'), findsOneWidget);
    expect(container.read(playerControllerProvider).videoId, isNull);
  });
}
