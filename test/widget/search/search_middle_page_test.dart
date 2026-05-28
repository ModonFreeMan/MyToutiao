import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_app.dart';

void main() {
  testWidgets('saves and shows search history', (WidgetTester tester) async {
    final preferences = await createMockPreferences();

    await tester.pumpWidget(createTestApp(preferences));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('搜索你感兴趣的视频'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '阶段七关键词');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('没有找到“阶段七关键词”相关视频'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, '阶段七关键词'), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('搜索你感兴趣的视频'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.widgetWithText(ActionChip, '阶段七关键词'), findsOneWidget);
  });
}
