题4：Repository 仍然直接绑定 Mock 数据源 
现在 FeedRepository、SearchRepository、RecommendationRepository 都直接依赖 MockDataSource。和“Repository 屏蔽数据来源、后续替换真实接口”的设计目标还有距离。

这次做了三件事：

- 新增抽象数据源接口：
  - [feed_data_source.dart](d:/Flutter/VideoPlayer/lib/data/datasources/feed_data_source.dart:3)
  - [search_data_source.dart](d:/Flutter/VideoPlayer/lib/data/datasources/search_data_source.dart:3)
  - [recommendation_data_source.dart](d:/Flutter/VideoPlayer/lib/data/datasources/recommendation_data_source.dart:1)

- 让现有 Mock 实现接口：
  - `MockFeedDataSource implements FeedDataSource`
  - `MockSearchDataSource implements SearchDataSource`
  - `MockRecommendationDataSource implements RecommendationDataSource`

- Repository 改为依赖抽象接口：
  - [feed_repository.dart](d:/Flutter/VideoPlayer/lib/data/repositories/feed_repository.dart:7) 使用 `feedDataSourceProvider`
  - [search_repository.dart](d:/Flutter/VideoPlayer/lib/data/repositories/search_repository.dart:7) 使用 `searchDataSourceProvider`
  - [recommendation_repository.dart](d:/Flutter/VideoPlayer/lib/data/repositories/recommendation_repository.dart:6) 使用 `recommendationDataSourceProvider`

现在 Mock 只在 Provider 装配层出现，后续替换真实接口时只需要把 `*DataSourceProvider` 返回的实现换掉，Repository / ViewModel / Page 都不用跟着改。