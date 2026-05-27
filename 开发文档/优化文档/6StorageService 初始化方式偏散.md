问题5：StorageService 初始化方式偏散
每次读写都 SharedPreferences.getInstance()，更理想的是在 Provider 层初始化后注入，便于测试和控制生命周期。

核心变化：
- `StorageService` 改为通过构造函数接收 `SharedPreferences`，不再每次读写都 `getInstance()`。
- 新增 `sharedPreferencesProvider`，由 `main.dart` 启动时初始化后 override 注入。
- 测试新增 [test_app.dart](d:/Flutter/VideoPlayer/test/test_app.dart)，统一创建 mock `SharedPreferences` 和测试用 `ProviderScope` / `ProviderContainer`。
- 已同步调整相关 widget/full flow 测试，避免 Provider 未初始化。

验证结果：
- `dart format` 已执行
- `flutter analyze` 通过，无问题
- `flutter test` 通过，全部测试成功Japgolly