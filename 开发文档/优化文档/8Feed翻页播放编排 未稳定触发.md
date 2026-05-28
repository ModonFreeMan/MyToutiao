# 8 Feed 翻页播放编排未稳定触发

## 当前问题

基础播放链路测试暴露出一个播放状态同步问题：

```text
用户从首个视频页上滑到图片页后，
页面已经展示图片内容，
FeedViewModel.currentIndex 也已经变为图片页索引，
但 PlayerController.videoId 仍然停留在上一个视频 video_001。
```

新增测试中的失败断言为：

```text
Expected: null
Actual: 'video_001'
```

这说明 Feed 页面切换到非视频内容后，播放器没有稳定暴露“已经停止”的业务状态。

核心问题不是单纯的 Feed 监听位置，而是：

```text
播放器控制器的业务状态生命周期和底层播放器资源生命周期没有解耦，
导致 Feed 已经切到非视频项时，业务层仍暴露旧 videoId。
```

Feed 编排层需要的是“当前页面是否应该有 active video”的同步结果；而 `PlayerController.stop()` 当前把这个结果延迟到 `dispose` 完成之后。`dispose` 是底层播放器资源释放细节，具有异步性和平台差异，不应该阻塞业务状态清空。

当前播放编排链路是：

```text
FeedViewModel.currentIndex 变化
  -> FeedPage ref.listen
  -> FeedPlaybackCoordinator.handleFeedCurrentChanged
  -> PlayerController.stop / playVideo
```

当链路走到 `PlayerController.stop()` 时，如果 stop 先等待底层播放器释放，再清空 `PlayerState`，就会出现 UI 和 Feed 状态已经切换，但业务层仍读取到旧 `videoId` 的情况。

这个问题会导致：

- 离开视频页后旧视频仍保持当前播放状态。
- 进入图片页时 `PlayerController` 仍指向旧视频。
- 后续再进入其他视频页时，播放链路可能基于过期状态继续编排。
- 基础播放链路缺少一条能真实暴露该问题的整体测试。

## 优化目标

让播放器业务状态与 Feed 当前内容保持同步，并将业务状态生命周期与底层资源释放生命周期解耦。

优化后应达到：

- 首屏视频进入页面后自动初始化并播放。
- 点击当前视频区域可以暂停，再次点击可以恢复播放。
- 拖动进度条可以触发 seek。
- 上滑到图片页时，`PlayerController.videoId` 必须同步变为 `null`。
- 旧播放器资源应该在后台继续释放，但资源释放不阻塞业务状态清空。
- 再上滑到下一个视频页时必须初始化并播放新视频。
- 搜索结果定位、程序化切换 Feed 索引时，也能触发同一套播放编排。

## 优化范围

本次优化涉及 PlayerController 停止状态机、Feed 播放编排、播放器整体测试和测试辅助 fake 平台。

核心代码范围：

- [feed_page.dart](d:/Flutter/VideoPlayer/lib/features/feed/pages/feed_page.dart:21)：调整 Feed 当前项变化与播放编排的触发位置。
- [feed_playback_coordinator.dart](d:/Flutter/VideoPlayer/lib/features/feed/coordinators/feed_playback_coordinator.dart:20)：继续作为 Feed 播放、停止、恢复的统一入口。
- [player_controller.dart](d:/Flutter/VideoPlayer/lib/features/player/controllers/player_controller.dart:27)：先修正 `stop()` / `stopIfCurrent()` 的业务状态清空语义，再保持播放器初始化、暂停、恢复和 seek 状态机职责。
- [player_controller_test.dart](d:/Flutter/VideoPlayer/test/unit/player/player_controller_test.dart:1)：新增 stop 状态机单元测试，证明业务状态不等待底层 dispose。
- [basic_playback_flow_test.dart](d:/Flutter/VideoPlayer/test/integration/basic_playback_flow_test.dart:1)：新增基础播放链路整体测试，用于先暴露问题，再验证修复。
- [fake_video_player_platform.dart](d:/Flutter/VideoPlayer/test/helpers/fake_video_player_platform.dart:1)：抽取 fake 视频平台，模拟初始化、播放、暂停、seek 和释放。

## 优化方案

先修正播放器停止状态机，再将“当前 Feed 内容变化后如何控制播放器”收口为明确且稳定的页面级编排。

第一步是解耦业务状态和资源释放：

```text
PlayerController.stop()
  -> 先清空 PlayerState，videoId 立即变为 null
  -> 再释放底层 VideoPlayerController

PlayerController.stopIfCurrent(videoId)
  -> 命中当前视频时，同样先清业务状态
  -> 再释放底层资源
```

这一步要由 `PlayerController` 单元测试先证明：

```text
当底层 dispose 尚未完成时，
PlayerController.videoId 已经变为 null。
```

资源释放是另一层验证，不混入基础播放链路断言：

```text
业务链路测试只判断：
  Feed 当前项是图片 => PlayerController.videoId 为 null
  Feed 当前项是视频 => PlayerController.videoId 为对应视频

资源释放测试另行判断：
  旧 VideoPlayerController 最终被 dispose
```

特别注意：不要用 dispose 超时把真实问题吞掉。

合理目标是：

```text
dispose 不阻塞业务状态清空。
```

而不是：

```text
dispose 卡住或失败时完全无感吞掉。
```

更好的语义是：

```text
业务 state 先清空；
底层 dispose 可以继续异步执行；
dispose 失败或超时必须记录；
但不回滚已经清空的业务状态。
```

也就是说，资源释放失败可以不影响 Feed 编排，但不能被完全隐藏。否则后续可能出现资源泄漏、测试假通过、播放器实例堆积等问题。

最终方案：

```text
Feed 当前项变化是播放编排的唯一业务触发源；
VideoFeedCard 不负责决定播放哪个视频。
```

也就是说，不管来源是手势翻页、搜索定位、程序化跳转、恢复 Feed 状态，还是未来 deep link 定位视频，最后都应该落到同一条链路：

```text
Feed current item changed
  -> FeedPlaybackCoordinator.handleFeedCurrentChanged(...)
  -> Video item: PlayerController.playVideo(item)
  -> Non-video item: PlayerController.stop()
```

具体实现优先采用：

```text
FeedPage initState
  -> ref.listenManual(feedViewModelProvider.select(...))
  -> 当前 Feed 项变化后调用 FeedPlaybackCoordinator.handleFeedCurrentChanged(...)
```

`PageView.onPageChanged` 不直接负责播放编排，只负责把用户手势翻页结果写入业务状态：

```text
PageView.onPageChanged
  -> FeedViewModel.setCurrentIndex

ref.listenManual current item
  -> 统一负责播放编排
```

不建议只依赖 `PageView.onPageChanged`，因为它只能覆盖用户手势翻页，不能完整覆盖：

- 搜索结果定位。
- 程序化切换 `currentIndex`。
- 恢复 Feed 状态。
- 未来 deep link 定位视频。

监听内容不应只看裸 `currentIndex`，还需要覆盖首屏数据加载场景。因为首次加载时 `currentIndex` 仍然是 `0`，但 `items` 会从空列表变成首屏数据，如果只监听 `currentIndex`，首个视频可能不会触发播放编排。

因此建议监听一个派生的当前项标识，例如当前 item 的 id 和类型：

```text
feedViewModelProvider.select((state) {
  return current item id/type;
})
```

这样可以覆盖：

- 首屏数据加载后当前项从 `null` 变为 `video_001`。
- 用户手势翻页导致当前项变化。
- 搜索结果定位导致当前项变化。
- 程序化恢复或 deep link 导致当前项变化。

优化时应避免让播放编排分散回各个 `VideoFeedCard` 生命周期里。卡片层只负责用户点击当前视频区域时的暂停、恢复、重试；Feed 当前项变化仍由页面层或协调器统一处理。

整体职责保持为：

```text
FeedPage
  -> 只负责监听当前 Feed 项变化，并把变化交给播放协调器

FeedViewModel
  -> 负责维护 items、currentIndex、分页和定位结果

FeedPlaybackCoordinator
  -> 判断当前内容类型并编排播放/停止

PlayerController
  -> 负责播放器状态机和底层 VideoPlayerController 生命周期

VideoFeedCard
  -> 只处理当前视频上的点击暂停、恢复、重试、横屏入口
```

## 优化验证

从红灯测试验证：

- 先运行 `flutter test test\unit\player\player_controller_test.dart --plain-name "stop clears business state before platform dispose completes"`。
- 该测试应先暴露：底层 dispose 未完成时，`PlayerController.videoId` 仍停留在旧视频。
- 运行 `flutter test test\integration\basic_playback_flow_test.dart`。
- 当前失败点应稳定暴露为：滑到图片页后 `playerControllerProvider.videoId` 仍为 `video_001`。

从修复后行为验证：

- `PlayerController.stop()` 调用后，即使底层 dispose 尚未完成，`videoId` 也立即变为 `null`。
- App 启动后首个视频 `video_001` 初始化完成并播放。
- 点击视频区域后 `isPlaying` 变为 `false`，fake 平台记录 pause。
- 再次点击视频区域后 `isPlaying` 变为 `true`，fake 平台记录 play。
- 拖动 `Slider` 后 fake 平台记录 seek 位置。
- 上滑到图片页 `雨后城市天台的晚霞` 后，`PlayerController.videoId` 变为 `null`。
- 再上滑到视频页 `周末城市骑行路线推荐` 后，`PlayerController.videoId` 变为 `video_002`，并进入播放状态。

从回归测试验证：

- `feed_player_test.dart` 继续覆盖视频页到图片页的基础停止行为。
- `video_full_flow_test.dart` 继续覆盖 Feed、搜索、回到目标视频并播放的完整链路。
- `feed_playback_coordinator_test.dart` 继续覆盖点击视频、横屏请求、Feed 覆盖/恢复等业务编排。

通过标准：

```text
Feed 当前内容发生变化时，播放器状态必须与当前内容类型一致：
视频页播放对应视频，非视频页停止播放器。

业务状态清空不等待底层播放器资源释放完成。
```
