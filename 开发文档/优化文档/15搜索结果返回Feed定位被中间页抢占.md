# 15 搜索结果返回 Feed 定位被中间页抢占

## 问题

用户从首页进入搜索，搜索“城市”，选择“西湖”结果后，Feed 可能最终跳到“家常番茄”。

已确认：

```text
focusItemById('video_009') 能正确跨页找到西湖。
但如果 PageView 随后上报 index 3，currentIndex 会被覆盖成番茄。
```

所以问题不是搜索分页，也不是找不到目标，而是：

```text
程序化定位期间，PageView 的旧页 / 中间页回调覆盖了 coordinator 的目标。
```

## 最小方案

职责保持简单：

```text
Coordinator：
  负责发起“搜索结果选中，定位到目标视频”。

FeedViewModel：
  负责分页找到目标。
  保存一个 pendingFocusedIndex。
  在保护期内忽略非目标 page change。

FeedPage：
  看到 pendingFocusedIndex 时，用 jumpToPage 同步 UI。
  不处理搜索业务。
```

具体规则：

```text
focusItemById 找到目标后：
  currentIndex = targetIndex
  pendingFocusedIndex = targetIndex

setCurrentIndex(index) 时：
  如果 pendingFocusedIndex != null 且 index != pendingFocusedIndex：
    忽略
  否则：
    接受 index

PageView 到达目标 index 后：
  清除 pendingFocusedIndex
```

这样“去西湖”的程序化定位不会被番茄页的回调覆盖。

## 不做

```text
不改搜索排序。
不改搜索分页。
不改 Feed 分页大小。
不让搜索页操作 PageController。
不引入复杂导航 service。
```

## 测试

保留两个最小测试：

```text
1. focusItemById('video_009') 能定位到西湖 index。
2. 定位到西湖后，模拟 setCurrentIndex(3)，currentIndex 仍保持西湖。
```

再保留一个集成测试：

```text
首页进入搜索
-> 搜索“城市”
-> 点击“西湖一日徒步路线：避开拥挤打卡点”
-> 返回 Feed
-> PlayerController.videoId 是 video_009
-> 不显示 / 不播放 video_003 番茄
```
