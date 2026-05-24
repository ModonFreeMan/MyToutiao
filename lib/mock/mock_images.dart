import '../data/models/author.dart';
import '../data/models/image_feed_item.dart';
import '../data/models/statistics.dart';

final mockImageFeedItems = <ImageFeedItem>[
  ImageFeedItem(
    id: 'image_001',
    title: '雨后城市天台的晚霞',
    author: const Author(
      id: 'author_005',
      name: '一张照片',
      avatarUrl: 'https://i.pravatar.cc/150?img=5',
    ),
    statistics: const Statistics(
      likeCount: 6700,
      commentCount: 238,
      favoriteCount: 980,
      shareCount: 144,
    ),
    tags: const ['摄影', '城市', '晚霞', '生活'],
    recommendationWords: const ['城市摄影', '晚霞拍摄技巧', '雨后天空', '手机摄影'],
    createdAt: DateTime(2026, 5, 20, 19, 5),
    imageUrl:
        'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1200',
    description: '雨停后的天台视角，云层散开时刚好露出一整片橙色晚霞。',
  ),
  ImageFeedItem(
    id: 'image_002',
    title: '露营早餐：热咖啡和烤吐司',
    author: const Author(
      id: 'author_006',
      name: '去野一下',
      avatarUrl: 'https://i.pravatar.cc/150?img=18',
    ),
    statistics: const Statistics(
      likeCount: 9200,
      commentCount: 376,
      favoriteCount: 1680,
      shareCount: 221,
    ),
    tags: const ['露营', '早餐', '户外', '咖啡'],
    recommendationWords: const ['露营早餐', '户外咖啡', '周末露营', '露营装备清单'],
    createdAt: DateTime(2026, 5, 22, 8, 15),
    imageUrl:
        'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=1200',
    description: '山谷里气温刚升起来，一杯热咖啡和简单早餐就很满足。',
  ),
  ImageFeedItem(
    id: 'image_003',
    title: '旧书店窗边的午后光',
    author: const Author(
      id: 'author_013',
      name: '街角观察员',
      avatarUrl: 'https://i.pravatar.cc/150?img=22',
    ),
    statistics: const Statistics(
      likeCount: 5400,
      commentCount: 192,
      favoriteCount: 810,
      shareCount: 97,
    ),
    tags: const ['书店', '摄影', '城市', '午后'],
    recommendationWords: const ['书店摄影', '城市散步', '午后光影', '独立书店'],
    createdAt: DateTime(2026, 5, 22, 16, 10),
    imageUrl:
        'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?w=1200',
    description: '窗边堆着旧杂志和明信片，阳光落在木桌上的纹理刚刚好。',
  ),
  ImageFeedItem(
    id: 'image_004',
    title: '雨夜便利店的一盏暖灯',
    author: const Author(
      id: 'author_014',
      name: '夜行相册',
      avatarUrl: 'https://i.pravatar.cc/150?img=34',
    ),
    statistics: const Statistics(
      likeCount: 7300,
      commentCount: 284,
      favoriteCount: 1040,
      shareCount: 131,
    ),
    tags: const ['夜景', '街拍', '便利店', '雨天'],
    recommendationWords: const ['雨夜街拍', '便利店摄影', '夜景构图', '城市光影'],
    createdAt: DateTime(2026, 5, 23, 0, 20),
    imageUrl:
        'https://images.unsplash.com/photo-1519608487953-e999c86e7455?w=1200',
    description: '雨水把路面照成镜子，便利店的暖灯让整条街都安静下来。',
  ),
  ImageFeedItem(
    id: 'image_005',
    title: '海边黄昏的慢跑剪影',
    author: const Author(
      id: 'author_015',
      name: '海风周记',
      avatarUrl: 'https://i.pravatar.cc/150?img=49',
    ),
    statistics: const Statistics(
      likeCount: 8900,
      commentCount: 345,
      favoriteCount: 1490,
      shareCount: 205,
    ),
    tags: const ['海边', '跑步', '黄昏', '生活'],
    recommendationWords: const ['海边慢跑', '黄昏摄影', '跑步路线', '海岸生活'],
    createdAt: DateTime(2026, 5, 23, 18, 35),
    imageUrl:
        'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1200',
    description: '落日把海面压成金色，一组慢跑剪影刚好穿过浪线。',
  ),
];
