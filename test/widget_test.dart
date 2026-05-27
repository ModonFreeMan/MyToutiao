import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_player_mvp/features/feed/widgets/image_feed_card.dart';
import 'package:video_player_mvp/mock/mock_images.dart';

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

  testWidgets('app starts on FeedPage', (WidgetTester tester) async {
    final preferences = await createMockPreferences();

    await tester.pumpWidget(createTestApp(preferences));

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('5 分钟学会篮球变向运球'), findsOneWidget);
    expect(find.text('@球场训练营'), findsOneWidget);
    expect(find.text('视频 1:18'), findsOneWidget);

    await flingToNextPage(tester);

    expect(find.text('雨后城市天台的晚霞'), findsOneWidget);
    expect(
      find.text('图文 1/${mockImageFeedItems.first.imageUrls.length}'),
      findsOneWidget,
    );
  });

  testWidgets('image feed page supports horizontal image carousel', (
    WidgetTester tester,
  ) async {
    final imageItem = mockImageFeedItems.first;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ImageFeedCard(item: imageItem)),
        ),
      ),
    );

    expect(find.text('图文 1/${imageItem.imageUrls.length}'), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('image-feed-carousel')),
      const Offset(-500, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text('图文 2/${imageItem.imageUrls.length}'), findsOneWidget);
  });

  testWidgets('mock image feed items use variable image counts', (
    WidgetTester tester,
  ) async {
    final imageCounts = mockImageFeedItems
        .map((item) => item.imageUrls.length)
        .toSet();

    expect(imageCounts.length, greaterThan(1));
    expect(imageCounts, containsAll(<int>[3, 4, 5]));
  });

  testWidgets('feed pages can be changed by mouse drag', (
    WidgetTester tester,
  ) async {
    final preferences = await createMockPreferences();

    await tester.pumpWidget(createTestApp(preferences));

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('5 分钟学会篮球变向运球'), findsOneWidget);

    await tester.drag(
      findVerticalFeedPageView(),
      const Offset(0, -500),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('雨后城市天台的晚霞'), findsOneWidget);
  });
}
