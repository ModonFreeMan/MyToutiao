# video_player_mvp

Flutter 短视频播放器 MVP，模拟今日头条视频流体验，覆盖内容流播放、搜索、推荐词、横屏、清晰度切换、preload 起播优化、观测指标和混合检索。

> 说明：本项目的设计文档、技术文档和实现过程均为 AI 辅助生成。

## 核心能力

- 全屏 Feed 内容流，上下滑切换视频和图片内容。
- 视频播放、暂停、进度展示、拖动进度、清晰度切换。
- 横屏全屏播放，并在返回竖屏后保持播放意图和进度。
- 单槽位 preload，支持方向感知候选、命中后 promote 为 active controller。
- 搜索中间页、搜索历史、搜索结果页和搜索结果回 Feed 定位播放。
- 推荐词入口，按当前内容派生相关搜索词。
- 起播、首帧、缓冲、preload hit / miss / promote 等观测指标。
- Dense search：离线业务文档、Embedding、向量召回和关键词融合排序。

## 技术栈

| 类别 | 选型 |
| --- | --- |
| 开发框架 | Flutter |
| 语言 | Dart |
| 状态管理 | Riverpod |
| 播放能力 | video_player |
| 本地存储 | SharedPreferences |
| 搜索增强 | 离线业务文档、Embedding、Milvus-compatible Vector Store |

## 架构概览

```text
Page / Widget
  ↓
Coordinator / Orchestrator
  ↓
ViewModel / Controller
  ↓
Service / Repository
  ↓
DataSource
```

核心模块：

```text
lib
├─ app              # App 入口、路由、主题
├─ core             # 常量、错误、日志、工具
├─ common           # 通用组件和基础模型
├─ data             # 数据模型、Repository、DataSource、搜索索引
├─ features
│  ├─ feed          # 内容流、分页、播放编排入口
│  ├─ player        # 播放器状态、active/preload controller
│  ├─ search        # 搜索中间页、搜索结果页、搜索状态
│  ├─ recommendation# 推荐词服务
│  ├─ observability # 播放链路观测指标
│  ├─ performance   # 性能统计
│  └─ storage       # 本地存储和搜索历史
└─ mock             # Mock 内容、视频、图片、推荐词、搜索数据
```

## 关键文档

- [技术方案.md](技术方案.md)：完整架构、模块职责、数据结构、状态流、核心流程和性能优化方案。
- [技术文档.md](技术文档.md)：实现方式、UML、主要流程图、3 周工作拆分和排期。
- [开发文档/测试文档/README.md](开发文档/测试文档/README.md)：测试文档索引。
- [开发文档/12.9 预加载效果评估与回归验证.md](开发文档/12.9%20预加载效果评估与回归验证.md)：preload 效果评估说明。
- [开发文档/测试文档/12.9 预加载效果评估与回归验证结果记录.md](开发文档/测试文档/12.9%20预加载效果评估与回归验证结果记录.md)：baseline / preload 采样结果。

## 本地运行

本项目约定：使用 `flutter` 和 `dart` 命令时需要提权运行。

获取依赖：

```powershell
flutter pub get
```

运行应用：

```powershell
flutter run
```

运行静态分析：

```powershell
flutter analyze
```

运行测试：

```powershell
flutter test
```

运行指定测试示例：

```powershell
flutter test test\unit\player\player_controller_test.dart
flutter test test\integration\preload_metrics_collection_test.dart
```

## 搜索离线配置

Dense search 默认读取：

```text
config/search_offline_config.json
```

仓库提供示例配置：

```text
config/search_offline_config.example.json
```

如果离线配置、业务文档或向量服务不可用，搜索会回退到 `MockSearchDataSource`。

离线索引相关工具：

```powershell
dart run tool\build_search_offline_index.dart
dart run tool\search_dense_query.dart
```

## 性能观测

项目通过 `PlaybackStartupMetrics` 旁路采集播放链路事件，覆盖：

- Feed 当前项可见
- 播放器初始化开始 / 结束 / 失败
- 播放请求和实际播放
- 首帧近似渲染
- 缓冲开始 / 结束
- preload start / ready / failed / hit / miss / promote

可通过 debug report 导出 JSON，并使用对比工具分析 baseline 与 preload：

```powershell
dart run tool\compare_preload_reports.dart build\reports\baseline.json build\reports\preload.json
```

## Android 双应用对照包

项目支持同时构建两个 Android release APK，用于对比 Feed preload 开关效果。

| 应用名 | 包名 | preload |
| --- | --- | --- |
| VideoPlayer Preload | `com.example.video_player_mvp.preload` | 开启 |
| VideoPlayer NoPreload | `com.example.video_player_mvp.nopreload` | 关闭 |

两个应用的 `applicationId` 不同，可以同时安装在同一台手机上。

### 构建 APK

在项目根目录执行：

```powershell
flutter build apk --release --flavor preload --dart-define=FEED_PRELOAD_ENABLED=true
flutter build apk --release --flavor noPreload --dart-define=FEED_PRELOAD_ENABLED=false
```

生成文件：

```text
build\app\outputs\flutter-apk\app-preload-release.apk
build\app\outputs\flutter-apk\app-nopreload-release.apk
```

### 安装到指定手机

先确认设备 id：

```powershell
flutter devices
```

安装两个 APK：

```powershell
adb -s <device-id> install -r build\app\outputs\flutter-apk\app-preload-release.apk
adb -s <device-id> install -r build\app\outputs\flutter-apk\app-nopreload-release.apk
```

如果 `adb` 不在 PATH，可以使用 Android SDK 下的完整路径：

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s <device-id> install -r build\app\outputs\flutter-apk\app-preload-release.apk
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s <device-id> install -r build\app\outputs\flutter-apk\app-nopreload-release.apk
```

### 验证安装

```powershell
adb -s <device-id> shell pm list packages com.example.video_player_mvp
```

预期至少包含：

```text
package:com.example.video_player_mvp.preload
package:com.example.video_player_mvp.nopreload
```

## 当前性能采样摘要

2026-06-02 手工采样显示：

```text
startup_ms:
  p90: baseline 686ms -> preload only 0ms
  p95: baseline 686ms -> preload only 0ms

first_frame_ms:
  p90: baseline 890ms -> preload only 213ms
  p95: baseline 890ms -> preload only 213ms

preload_hit_rate: 91.7%
preload_promoted_to_active: 11
```