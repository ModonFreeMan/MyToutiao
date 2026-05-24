import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:video_player_mvp/app/app.dart';

void main() {
  Future<void> flingToNextPage(WidgetTester tester) async {
    await tester.fling(find.byType(PageView), const Offset(0, -500), 1000);
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('app starts on FeedPage', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: App()));

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('5 分钟学会篮球变向运球'), findsOneWidget);
    expect(find.text('@球场训练营'), findsOneWidget);
    expect(find.text('视频 1:18'), findsOneWidget);

    await flingToNextPage(tester);

    expect(find.text('雨后城市天台的晚霞'), findsOneWidget);
    expect(find.text('图片'), findsOneWidget);
  });
}
