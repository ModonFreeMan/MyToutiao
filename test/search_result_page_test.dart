import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:video_player_mvp/app/app.dart';
import 'package:video_player_mvp/features/search/widgets/search_video_result_item.dart';

void main() {
  testWidgets('searches videos and opens the selected feed item', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('搜索你感兴趣的视频'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '拉伸');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('清晨 20 分钟拉伸唤醒身体'), findsOneWidget);
    expect(find.byType(SearchVideoResultItem), findsOneWidget);

    await tester.tap(find.byType(SearchVideoResultItem));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('搜索你感兴趣的视频'), findsOneWidget);
    expect(find.text('清晨 20 分钟拉伸唤醒身体'), findsOneWidget);
  });
}
