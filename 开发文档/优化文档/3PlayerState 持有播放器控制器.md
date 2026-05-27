# 3 PlayerState 持有播放器控制器

## 当前问题

`PlayerState` 原本持有 `VideoPlayerController`，导致播放器状态层和资源控制层混在一起。

`PlayerState` 的职责应该是保存 UI 渲染所需的播放器状态快照，例如：

- `isPlaying`
- `position`
- `duration`
- `isBuffering`

而 `VideoPlayerController` 是具体播放器插件资源，包含资源初始化、播放、暂停、释放等控制能力。将它放进 State 会让状态对象承担资源管理职责，也会让 UI 状态和插件控制器生命周期绑定过深。

## 优化目标

将播放器资源控制权收口到 `PlayerController`，让 `PlayerState` 只保留 UI 状态快照。

优化后应达到：

- `PlayerState` 不再依赖 `video_player` 插件。
- `PlayerState` 不再持有 `VideoPlayerController`。
- `PlayerController` 统一管理播放器插件控制器的创建、读取和释放。
- UI 继续通过 `PlayerState` 响应播放状态变化。

## 优化范围

本次优化涉及播放器状态、播放器控制器和播放器视图。

核心代码范围：

- [player_state.dart](d:/Flutter/VideoPlayer/lib/features/player/states/player_state.dart)：删除 `VideoPlayerController` 字段和 `video_player` 依赖。
- [player_controller.dart](d:/Flutter/VideoPlayer/lib/features/player/controllers/player_controller.dart)：保留私有 `_controller`，并提供只读 `videoController` getter。
- [video_player_view.dart](d:/Flutter/VideoPlayer/lib/features/player/widgets/video_player_view.dart)：继续监听 `PlayerState` 触发 UI 更新，真实播放器控制器改为从 `PlayerController.notifier` 读取。

## 优化方案

将播放器状态和播放器资源控制拆开：

```text
PlayerController
  -> 持有 VideoPlayerController
  -> 负责播放、暂停、初始化、释放

PlayerState
  -> 保存 isPlaying / position / duration / isBuffering
  -> 服务 UI 渲染
```

调整后，`PlayerController` 内部保留私有播放器控制器：

```dart
VideoPlayerController? _controller;
```

并通过只读 getter 暴露给确实需要渲染原生播放器视图的组件：

```dart
VideoPlayerController? get videoController => _controller;
```

`PlayerState` 不再写入或复制播放器控制器，只保存可序列化、可比较、适合驱动 UI 的状态字段。

`VideoPlayerView` 继续 watch `PlayerState`，用于响应播放状态、缓冲状态、进度等 UI 变化；当需要实际播放器实例时，再从 `PlayerController.notifier` 获取。

## 优化验证

从职责边界验证：

- `PlayerState` 只表达当前播放器 UI 状态。
- `PlayerController` 负责播放器资源生命周期和控制流。
- 插件控制器不再进入状态对象。

从依赖关系验证：

- `player_state.dart` 不再 import `video_player`。
- `VideoPlayerController` 只出现在播放器控制器或确实需要渲染播放器的视图层。
- State 层不再和插件资源生命周期耦合。

从运行行为验证：

- 播放、暂停、进度、缓冲状态仍能驱动 UI 更新。
- `VideoPlayerView` 可以继续获取真实播放器控制器进行渲染。
- 释放播放器资源时由 `PlayerController` 统一处理，避免 State 持有已释放资源。
