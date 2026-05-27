修改问题：状态层和资源控制层混在一起
播放器状态里放了插件控制器，PlayerState 持有 VideoPlayerController。
状态对象应该只是当前播放器状态的快照，为UI渲染服务。控制流应该交给Controller
原设计里已经有 PlayerController，所以播放器资源应该被它管理。
PlayerController 持有 VideoPlayerController
PlayerState 只保存 isPlaying、position、duration、isBuffering 等 UI 状态
已完成修改，播放器资源现在归 `PlayerController` 管，`PlayerState` 只保留 UI 快照状态。

改动点：
- [player_state.dart](d:/Flutter/VideoPlayer/lib/features/player/states/player_state.dart) 删除了 `VideoPlayerController` 字段和 `video_player` 依赖。
- [player_controller.dart](d:/Flutter/VideoPlayer/lib/features/player/controllers/player_controller.dart) 保留私有 `_controller`，新增只读 `videoController` getter，并移除所有向 state 写入 controller 的逻辑。
- [video_player_view.dart](d:/Flutter/VideoPlayer/lib/features/player/widgets/video_player_view.dart) 继续 watch `PlayerState` 触发 UI 更新，但真实播放器控制器改为从 `PlayerController.notifier` 读取。
