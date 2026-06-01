import '../data/models/author.dart';
import '../data/models/statistics.dart';
import '../data/models/video_feed_item.dart';
import '../data/models/video_source.dart';

const _sintelTrailerUrl = 'https://media.w3.org/2010/05/sintel/trailer.mp4';
const _w3cMovie300Url = 'https://media.w3.org/2010/05/video/movie_300.mp4';
const _oceansUrl = 'https://vjs.zencdn.net/v/oceans.mp4';
const _flutterBeeUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';
const _flutterBeeHlsUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/hls/bee.m3u8';
const _flutterButterflyUrl =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

List<VideoSource> _sourcesFor({
  required String p360Url,
  required String p720Url,
  required String p1080Url,
}) {
  return [
    VideoSource(
      quality: VideoQuality.p360,
      url: p360Url,
      width: 640,
      height: 360,
      bitrate: 800,
    ),
    VideoSource(
      quality: VideoQuality.p720,
      url: p720Url,
      width: 1280,
      height: 720,
      bitrate: 1800,
    ),
    VideoSource(
      quality: VideoQuality.p1080,
      url: p1080Url,
      width: 1920,
      height: 1080,
      bitrate: 3200,
    ),
  ];
}

final mockVideoFeedItems = <VideoFeedItem>[
  VideoFeedItem(
    id: 'video_001',
    title: '5 分钟学会篮球变向运球',
    author: const Author(
      id: 'author_001',
      name: '球场训练营',
      avatarUrl: 'https://i.pravatar.cc/150?img=12',
    ),
    statistics: const Statistics(
      likeCount: 12800,
      commentCount: 936,
      favoriteCount: 2140,
      shareCount: 512,
    ),
    tags: const ['篮球', '运球', '教学', '运动'],
    recommendationWords: const ['篮球运球教学', '变向运球', '篮球新手训练', '篮球控球技巧'],
    createdAt: DateTime(2026, 5, 20, 18, 30),
    videoSources: _sourcesFor(
      p360Url: _sintelTrailerUrl,
      p720Url: _flutterBeeUrl,
      p1080Url: _flutterButterflyUrl,
    ),
    coverUrl:
        'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=1200',
    duration: const Duration(milliseconds: 52209),
    description: '从节奏、重心和护球三个动作拆解变向运球，新手也能跟练。',
  ),
  VideoFeedItem(
    id: 'video_002',
    title: '周末城市骑行路线推荐',
    author: const Author(
      id: 'author_002',
      name: '城市漫游指南',
      avatarUrl: 'https://i.pravatar.cc/150?img=25',
    ),
    statistics: const Statistics(
      likeCount: 8600,
      commentCount: 418,
      favoriteCount: 1320,
      shareCount: 286,
    ),
    tags: const ['骑行', '城市', '周末', '旅行'],
    recommendationWords: const ['城市骑行路线', '周末去哪玩', '骑行装备', '短途旅行'],
    createdAt: DateTime(2026, 5, 21, 9, 10),
    videoSources: _sourcesFor(
      p360Url: _oceansUrl,
      p720Url: _flutterBeeHlsUrl,
      p1080Url: _w3cMovie300Url,
    ),
    coverUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1200',
    duration: const Duration(milliseconds: 46613),
    description: '一条适合半天完成的城市骑行路线，沿途包含公园、咖啡店和河岸步道。',
  ),
  VideoFeedItem(
    id: 'video_003',
    title: '家常番茄牛腩这样炖更入味',
    author: const Author(
      id: 'author_003',
      name: '阿晴厨房',
      avatarUrl: 'https://i.pravatar.cc/150?img=47',
    ),
    statistics: const Statistics(
      likeCount: 24500,
      commentCount: 1820,
      favoriteCount: 5300,
      shareCount: 971,
    ),
    tags: const ['美食', '家常菜', '牛腩', '晚餐'],
    recommendationWords: const ['番茄牛腩做法', '家常菜教程', '牛肉怎么炖', '晚餐菜谱'],
    createdAt: DateTime(2026, 5, 21, 20, 45),
    videoSources: _sourcesFor(
      p360Url: _w3cMovie300Url,
      p720Url: _sintelTrailerUrl,
      p1080Url: _flutterBeeUrl,
    ),
    coverUrl:
        'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200',
    duration: const Duration(milliseconds: 300140),
    description: '先炒番茄再慢炖，汤汁浓郁，牛腩软烂，适合配米饭。',
  ),
  VideoFeedItem(
    id: 'video_004',
    title: '清晨 20 分钟拉伸唤醒身体',
    author: const Author(
      id: 'author_004',
      name: '轻健身计划',
      avatarUrl: 'https://i.pravatar.cc/150?img=32',
    ),
    statistics: const Statistics(
      likeCount: 15300,
      commentCount: 724,
      favoriteCount: 3860,
      shareCount: 430,
    ),
    tags: const ['健身', '拉伸', '晨练', '健康'],
    recommendationWords: const ['晨间拉伸', '居家健身', '肩颈放松', '新手健身计划'],
    createdAt: DateTime(2026, 5, 22, 7, 20),
    videoSources: _sourcesFor(
      p360Url: _flutterButterflyUrl,
      p720Url: _oceansUrl,
      p1080Url: _flutterBeeHlsUrl,
    ),
    coverUrl:
        'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=1200',
    duration: const Duration(milliseconds: 46613),
    description: '无需器械的晨间拉伸组合，重点放松肩颈、背部和腿后侧。',
  ),
  VideoFeedItem(
    id: 'video_005',
    title: '手冲咖啡入门：稳定萃取三件事',
    author: const Author(
      id: 'author_007',
      name: '咖啡实验室',
      avatarUrl: 'https://i.pravatar.cc/150?img=14',
    ),
    statistics: const Statistics(
      likeCount: 11200,
      commentCount: 642,
      favoriteCount: 2840,
      shareCount: 318,
    ),
    tags: const ['咖啡', '手冲', '教程', '生活方式'],
    recommendationWords: const ['手冲咖啡教程', '咖啡豆研磨度', 'V60 萃取', '居家咖啡'],
    createdAt: DateTime(2026, 5, 22, 10, 30),
    videoSources: _sourcesFor(
      p360Url: _flutterBeeUrl,
      p720Url: _oceansUrl,
      p1080Url: _sintelTrailerUrl,
    ),
    coverUrl:
        'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=1200',
    duration: const Duration(milliseconds: 46613),
    description: '从水温、研磨度和注水节奏入手，帮你减少手冲咖啡的苦涩和杂味。',
  ),
  VideoFeedItem(
    id: 'video_006',
    title: '桌面收纳改造：小空间也能清爽工作',
    author: const Author(
      id: 'author_008',
      name: '整理研究所',
      avatarUrl: 'https://i.pravatar.cc/150?img=28',
    ),
    statistics: const Statistics(
      likeCount: 9800,
      commentCount: 511,
      favoriteCount: 2460,
      shareCount: 276,
    ),
    tags: const ['收纳', '桌面', '效率', '家居'],
    recommendationWords: const ['桌面收纳', '工作区改造', '小空间整理', '效率工具'],
    createdAt: DateTime(2026, 5, 22, 14, 5),
    videoSources: _sourcesFor(
      p360Url: _flutterBeeHlsUrl,
      p720Url: _w3cMovie300Url,
      p1080Url: _oceansUrl,
    ),
    coverUrl:
        'https://images.unsplash.com/photo-1497366811353-6870744d04b2?w=1200',
    duration: const Duration(milliseconds: 52209),
    description: '用分区、走线和常用物优先原则，改造一张拥挤的工作桌。',
  ),
  VideoFeedItem(
    id: 'video_007',
    title: '夜景人像拍摄：街灯也能当主光',
    author: const Author(
      id: 'author_009',
      name: '影像笔记',
      avatarUrl: 'https://i.pravatar.cc/150?img=41',
    ),
    statistics: const Statistics(
      likeCount: 17400,
      commentCount: 903,
      favoriteCount: 3910,
      shareCount: 486,
    ),
    tags: const ['摄影', '夜景', '人像', '手机摄影'],
    recommendationWords: const ['夜景人像', '街灯拍照', '手机夜拍技巧', '摄影构图'],
    createdAt: DateTime(2026, 5, 22, 21, 40),
    videoSources: _sourcesFor(
      p360Url: _sintelTrailerUrl,
      p720Url: _flutterButterflyUrl,
      p1080Url: _w3cMovie300Url,
    ),
    coverUrl:
        'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=1200',
    duration: const Duration(milliseconds: 52209),
    description: '利用街灯方向、反光墙面和曝光补偿，拍出更干净的夜景人像。',
  ),
  VideoFeedItem(
    id: 'video_008',
    title: '新手滑板第一课：站姿和刹停',
    author: const Author(
      id: 'author_010',
      name: '街头运动课',
      avatarUrl: 'https://i.pravatar.cc/150?img=8',
    ),
    statistics: const Statistics(
      likeCount: 13700,
      commentCount: 788,
      favoriteCount: 2680,
      shareCount: 359,
    ),
    tags: const ['滑板', '运动', '新手', '教学'],
    recommendationWords: const ['滑板入门', '滑板刹停', '新手站姿', '街头运动'],
    createdAt: DateTime(2026, 5, 23, 11, 15),
    videoSources: _sourcesFor(
      p360Url: _oceansUrl,
      p720Url: _sintelTrailerUrl,
      p1080Url: _flutterBeeUrl,
    ),
    coverUrl:
        'https://images.unsplash.com/photo-1520045892732-304bc3ac5d8e?w=1200',
    duration: const Duration(milliseconds: 46613),
    description: '先学会稳定站姿、上板和基础刹停，再进入转弯与小坡练习。',
  ),
  VideoFeedItem(
    id: 'video_009',
    title: '西湖一日徒步路线：避开拥挤打卡点',
    author: const Author(
      id: 'author_011',
      name: '慢行地图',
      avatarUrl: 'https://i.pravatar.cc/150?img=53',
    ),
    statistics: const Statistics(
      likeCount: 12100,
      commentCount: 566,
      favoriteCount: 3140,
      shareCount: 402,
    ),
    tags: const ['徒步', '西湖', '旅行', '路线'],
    recommendationWords: const ['西湖徒步路线', '杭州一日游', '避开人群旅行', '城市徒步'],
    createdAt: DateTime(2026, 5, 23, 15, 25),
    videoSources: _sourcesFor(
      p360Url: _w3cMovie300Url,
      p720Url: _flutterBeeHlsUrl,
      p1080Url: _flutterButterflyUrl,
    ),
    coverUrl:
        'https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?w=1200',
    duration: const Duration(milliseconds: 46613),
    description: '从北山街出发串联小众湖岸、茶园和观景点，适合轻装一日徒步。',
  ),
  VideoFeedItem(
    id: 'video_010',
    title: 'Flutter 动画微交互：按钮反馈更自然',
    author: const Author(
      id: 'author_012',
      name: '代码手账',
      avatarUrl: 'https://i.pravatar.cc/150?img=60',
    ),
    statistics: const Statistics(
      likeCount: 7600,
      commentCount: 429,
      favoriteCount: 2190,
      shareCount: 233,
    ),
    tags: const ['Flutter', '动画', '开发', '交互'],
    recommendationWords: const ['Flutter 动画', '微交互设计', '按钮反馈', 'Dart 开发'],
    createdAt: DateTime(2026, 5, 23, 19, 50),
    videoSources: _sourcesFor(
      p360Url: _flutterBeeUrl,
      p720Url: _w3cMovie300Url,
      p1080Url: _flutterBeeHlsUrl,
    ),
    coverUrl:
        'https://images.unsplash.com/photo-1515879218367-8466d910aaa4?w=1200',
    duration: const Duration(milliseconds: 300140),
    description: '用 AnimatedScale、AnimatedOpacity 和曲线控制，让按钮按压反馈更轻盈。',
  ),
];
