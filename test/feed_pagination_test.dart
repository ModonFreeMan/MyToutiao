import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_player_mvp/app/app.dart';

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

  testWidgets('loads next feed page near the end', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('露营早餐：热咖啡和烤吐司'), findsNothing);

    await flingToNextPage(tester);
    await flingToNextPage(tester);
    await tester.pump(const Duration(milliseconds: 400));

    await flingToNextPage(tester);
    await flingToNextPage(tester);

    expect(find.text('露营早餐：热咖啡和烤吐司'), findsOneWidget);
  });
}
