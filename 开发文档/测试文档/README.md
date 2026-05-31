# 测试文档

## 测试目标

当前测试覆盖推荐词匹配逻辑、Feed 分页状态、Feed 播放编排、Feed 覆盖恢复、搜索状态、搜索历史、播放器状态机、播放器初始化竞态、清晰度切换失败、清晰度切换集成链路、进度保持、起播性能指标归属与 baseline report、搜索数据源、Feed 基础播放链路、横屏播放链路、搜索页面、推荐词入口，以及“视频 Feed -> 搜索 -> 搜索结果 -> 回到 Feed 定位播放”的视频全链路，确保 MVP 的核心交互和观测能力可以稳定运行。

## 文档索引

- [测试用例说明.md](D:/Flutter/VideoPlayer/开发文档/测试文档/测试用例说明.md:1)：记录每个测试文件的测试内容和通过标准。

## 测试目录结构

```text
test/
├── helpers/
│   ├── fake_video_player_platform.dart
│   └── test_app.dart
├── integration/
│   ├── basic_playback_flow_test.dart
│   ├── landscape_player_flow_test.dart
│   ├── search_and_quality_flow_test.dart
│   └── video_full_flow_test.dart
├── unit/
│   ├── feed/
│   │   ├── feed_cover_resume_test.dart
│   │   ├── feed_playback_coordinator_test.dart
│   │   └── feed_view_model_test.dart
│   ├── observability/
│   │   └── playback_startup_metrics_test.dart
│   ├── player/
│   │   ├── player_controller_initialization_race_test.dart
│   │   ├── player_controller_progress_test.dart
│   │   ├── player_controller_quality_switch_test.dart
│   │   └── player_controller_test.dart
│   ├── recommendation/
│   │   └── recommendation_service_test.dart
│   ├── search/
│   │   ├── mock_search_datasource_test.dart
│   │   └── search_view_model_test.dart
│   └── storage/
│       └── search_history_service_test.dart
└── widget/
    ├── feed/
    │   ├── feed_page_test.dart
    │   ├── feed_pagination_test.dart
    │   ├── feed_player_test.dart
    │   └── recommendation_entry_test.dart
    └── search/
        ├── search_middle_page_test.dart
        └── search_result_page_test.dart
```

## 分层规范

- `test/unit/`：纯业务逻辑测试，不启动完整页面。
- `test/widget/`：页面或组件交互测试，按功能域继续分组。
- `test/integration/`：跨页面、跨模块的核心链路测试。
- `test/helpers/`：测试夹具、Provider 覆盖、mock 初始化等共享辅助代码。

## 运行命令

```bash
flutter analyze
flutter test
```

最近一次验证结果：

```text
flutter analyze: No issues found
flutter test: All tests passed, 85/85
```
