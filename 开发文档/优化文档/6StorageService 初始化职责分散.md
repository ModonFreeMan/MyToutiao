# 6 StorageService 初始化职责分散

## 当前问题

`StorageService` 原本在每次读写时调用 `SharedPreferences.getInstance()`。

这种方式会带来几个问题：

- 初始化逻辑分散在具体读写方法里，服务生命周期不清晰。
- 每次访问都需要关心异步获取 `SharedPreferences`，读写流程变重。
- 测试时不方便统一注入 mock `SharedPreferences`。
- Provider 层无法明确表达 `StorageService` 依赖已经初始化完成。

从架构职责看，`StorageService` 应该负责封装存储读写行为，而不是在每个方法里重复处理底层存储实例的创建。

## 优化目标

将 `SharedPreferences` 的初始化收口到应用启动和 Provider 装配阶段，再通过构造函数注入给 `StorageService`。

优化后应达到：

- `StorageService` 不再在读写方法中调用 `SharedPreferences.getInstance()`。
- `SharedPreferences` 在 `main.dart` 启动时完成初始化。
- `sharedPreferencesProvider` 负责暴露已初始化的实例。
- 测试可以统一注入 mock `SharedPreferences`，避免 Provider 未初始化问题。

## 优化范围

本次优化涉及存储服务、应用启动入口、Provider 注入和测试辅助能力。

核心代码范围：

- `StorageService`：改为通过构造函数接收 `SharedPreferences`。
- `sharedPreferencesProvider`：新增底层存储实例 Provider。
- `main.dart`：应用启动时初始化 `SharedPreferences`，并通过 `ProviderScope` override 注入。
- [test_app.dart](d:/Flutter/VideoPlayer/test/test_app.dart)：统一创建 mock `SharedPreferences` 和测试用 `ProviderScope` / `ProviderContainer`。

测试范围：

- 相关 widget 测试。
- 相关 full flow 测试。
- 依赖 `StorageService` 或 `SharedPreferences` 的 Provider 测试。

## 优化方案

将 `StorageService` 从“内部自行获取依赖”调整为“外部注入依赖”。

调整前：

```text
StorageService 方法
  -> SharedPreferences.getInstance()
  -> 执行读写
```

调整后：

```text
main.dart 初始化 SharedPreferences
  -> ProviderScope override sharedPreferencesProvider
  -> StorageService(sharedPreferences)
  -> 执行读写
```

`StorageService` 只保留存储读写职责：

```dart
class StorageService {
  const StorageService(this._preferences);

  final SharedPreferences _preferences;
}
```

Provider 层负责装配依赖：

```dart
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(sharedPreferencesProvider));
});
```

测试侧通过统一的 `test_app.dart` 创建 mock 存储实例，并提供测试用 `ProviderScope` / `ProviderContainer`，避免每个测试重复处理初始化和 override。

## 优化验证

从职责边界验证：

- `StorageService` 只负责存储读写，不再负责创建 `SharedPreferences`。
- `main.dart` 负责应用启动期初始化。
- Provider 负责依赖装配和测试替换。

从测试能力验证：

- widget 测试可以通过测试工具统一注入 mock `SharedPreferences`。
- full flow 测试不会因为 `sharedPreferencesProvider` 未初始化而失败。
- 依赖存储能力的测试不需要真实设备或真实持久化状态。

从运行行为验证：

- 应用启动时先完成 `SharedPreferences` 初始化，再创建依赖它的 Provider。
- 读写方法直接使用已注入实例，避免重复调用 `getInstance()`。
- 存储服务生命周期更明确，后续替换存储实现或增加迁移逻辑时有统一入口。
