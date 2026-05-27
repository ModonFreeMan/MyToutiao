# 5 Repository 依赖具体数据源

## 当前问题

`FeedRepository`、`SearchRepository`、`RecommendationRepository` 原本直接依赖 Mock 数据源实现。

这种写法会让 Repository 知道当前数据来自 Mock：

```text
Repository
  -> MockDataSource
```

这和“Repository 屏蔽数据来源，后续可替换真实接口”的设计目标不一致。后续如果接入远程接口或本地缓存，Repository 需要跟着修改 import、字段类型和构造参数，容易把数据来源细节继续向 ViewModel、Service 或 Page 扩散。

## 优化目标

让 Repository 只依赖 DataSource 抽象接口，具体数据来源由 Provider 装配决定。

优化后应达到：

- Repository 不再直接依赖 `MockFeedDataSource`、`MockSearchDataSource`、`MockRecommendationDataSource`。
- Mock、Remote、Local 等具体数据源都通过同一组抽象接口接入。
- 替换真实接口时，只需要调整 Provider 返回的具体实现。
- ViewModel、Service、Page 不感知数据来源变化。

## 优化范围

本次优化涉及数据源接口、Mock 数据源实现和 Repository 装配方式。

新增抽象数据源接口：

- [feed_data_source.dart](d:/Flutter/VideoPlayer/lib/data/datasources/feed_data_source.dart:3)
- [search_data_source.dart](d:/Flutter/VideoPlayer/lib/data/datasources/search_data_source.dart:3)
- [recommendation_data_source.dart](d:/Flutter/VideoPlayer/lib/data/datasources/recommendation_data_source.dart:1)

调整 Mock 数据源：

- `MockFeedDataSource implements FeedDataSource`
- `MockSearchDataSource implements SearchDataSource`
- `MockRecommendationDataSource implements RecommendationDataSource`

调整 Repository：

- [feed_repository.dart](d:/Flutter/VideoPlayer/lib/data/repositories/feed_repository.dart:7)
- [search_repository.dart](d:/Flutter/VideoPlayer/lib/data/repositories/search_repository.dart:7)
- [recommendation_repository.dart](d:/Flutter/VideoPlayer/lib/data/repositories/recommendation_repository.dart:6)

## 优化方案

为每类数据源补充抽象接口，例如：

```dart
abstract interface class FeedDataSource {
  Future<List<FeedItem>> fetchFeedItems({
    required int page,
    required int pageSize,
  });
}
```

让现有 Mock 实现接口：

```dart
class MockFeedDataSource implements FeedDataSource {
  const MockFeedDataSource();
}
```

Repository 字段类型从具体 Mock 改为抽象接口：

```dart
final FeedDataSource dataSource;
```

具体实现放到 Provider 层装配：

```dart
final feedDataSourceProvider = Provider<FeedDataSource>((ref) {
  return const MockFeedDataSource();
});

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(
    dataSource: ref.watch(feedDataSourceProvider),
  );
});
```

调整后的依赖关系为：

```text
ViewModel / Service
  -> Repository
  -> DataSource 抽象接口
  -> MockDataSource / RemoteDataSource / LocalDataSource
```

后续接入真实接口时，只需要把 `*DataSourceProvider` 返回值替换为真实实现：

```dart
final feedDataSourceProvider = Provider<FeedDataSource>((ref) {
  return ApiFeedDataSource(client: ref.watch(apiClientProvider));
});
```

## 优化验证

从职责边界验证：

- Repository 只表达业务数据访问语义，不再绑定 Mock 实现。
- DataSource 负责具体数据来源。
- Provider 负责选择当前使用哪种数据源实现。

从替换能力验证：

- `FeedRepository` 可从 `MockFeedDataSource` 切换到 `ApiFeedDataSource`，Repository 本身不需要修改。
- `SearchRepository` 可从 `MockSearchDataSource` 切换到 `ApiSearchDataSource`，上层调用不需要修改。
- `RecommendationRepository` 可从 `MockRecommendationDataSource` 切换到 `ApiRecommendationDataSource`，Service 和 Page 不需要修改。

从代码一致性验证：

- Mock 只在 Provider 装配层出现。
- Repository import 的是 `*DataSource` 抽象接口，而不是 `mock_*_datasource.dart`。
- ViewModel、Service、Page 继续通过 Repository 获取数据，不感知底层来源。
