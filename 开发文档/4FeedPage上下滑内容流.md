第 4 阶段已完成：`FeedPage` 现在使用竖向 `PageView.builder`，根据 `FeedItem.type` 渲染 `VideoFeedCard` / `ImageFeedCard`，并通过 `onPageChanged` 调用 `setCurrentIndex`，接近底部时沿用现有 ViewModel 触发加载更多。

主要改动：
- [feed_page.dart](D:/Flutter/VideoPlayer/lib/features/feed/pages/feed_page.dart)：从文字列表切换为全屏上下滑内容流
- [video_feed_card.dart](D:/Flutter/VideoPlayer/lib/features/feed/widgets/video_feed_card.dart)：视频封面卡，展示封面、标题、作者、时长、互动栏
- [image_feed_card.dart](D:/Flutter/VideoPlayer/lib/features/feed/widgets/image_feed_card.dart)：图片卡展示
- [feed_content_info.dart](D:/Flutter/VideoPlayer/lib/features/feed/widgets/feed_content_info.dart)：底部作者/标题/描述信息层
- [right_action_bar.dart](D:/Flutter/VideoPlayer/lib/features/feed/widgets/right_action_bar.dart)：点赞、评论、收藏、分享 UI
- [format_utils.dart](D:/Flutter/VideoPlayer/lib/core/utils/format_utils.dart)：补了互动数字紧凑格式化


测试也更新为验证首个视频卡展示，以及上滑后图片卡能展示。