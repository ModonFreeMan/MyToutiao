import 'package:flutter_test/flutter_test.dart';

import 'package:video_player_mvp/features/search/widgets/search_video_result_item.dart';

import 'test_app.dart';

void main() {
  testWidgets('opens search result page from related search word', (
    WidgetTester tester,
  ) async {
    final preferences = await createMockPreferences();

    await tester.pumpWidget(createTestApp(preferences));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('相关搜索'), findsOneWidget);
    expect(find.text('篮球运球教学'), findsOneWidget);

    await tester.tap(find.text('篮球运球教学'));
    await tester.pumpAndSettle();

    expect(find.text('5 分钟学会篮球变向运球'), findsOneWidget);
    expect(find.byType(SearchVideoResultItem), findsOneWidget);
  });
}
