import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/data/datasources/recommendation_data_source.dart';
import 'package:video_player_mvp/data/models/author.dart';
import 'package:video_player_mvp/data/models/statistics.dart';
import 'package:video_player_mvp/data/models/video_feed_item.dart';
import 'package:video_player_mvp/data/models/video_source.dart';
import 'package:video_player_mvp/data/repositories/recommendation_repository.dart';
import 'package:video_player_mvp/features/recommendation/services/recommendation_service.dart';

void main() {
  group('RecommendationService', () {
    test('uses bound recommendation words first', () async {
      final service = _createService(
        tagWords: {
          '篮球': ['tag word'],
        },
        textWords: {
          '篮球': ['text word'],
        },
      );

      final words = await service.matchWords(
        _createItem(
          tags: const ['篮球'],
          recommendationWords: const ['bound word'],
          title: '篮球教学',
          description: '篮球训练',
        ),
      );

      expect(words, const ['bound word']);
    });

    test('uses tag words when bound words are empty', () async {
      final service = _createService(
        tagWords: {
          '篮球': ['tag word'],
        },
        textWords: {
          '篮球': ['text word'],
        },
      );

      final words = await service.matchWords(
        _createItem(tags: const ['篮球'], title: '篮球教学', description: '篮球训练'),
      );

      expect(words, const ['tag word']);
    });

    test('uses title words when tags do not match', () async {
      final service = _createService(
        textWords: {
          '骑行': ['title word'],
        },
      );

      final words = await service.matchWords(
        _createItem(title: '城市骑行路线', description: '周末出门'),
      );

      expect(words, const ['title word']);
    });

    test('uses description words when title does not match', () async {
      final service = _createService(
        textWords: {
          '露营': ['description word'],
        },
      );

      final words = await service.matchWords(
        _createItem(title: '周末早餐', description: '适合露营的热咖啡'),
      );

      expect(words, const ['description word']);
    });

    test('uses default words when no source matches', () async {
      final service = _createService();

      final words = await service.matchWords(
        _createItem(title: '未知内容', description: '没有可匹配关键词'),
      );

      expect(words, const ['default word']);
    });
  });
}

RecommendationService _createService({
  Map<String, List<String>> tagWords = const {},
  Map<String, List<String>> textWords = const {},
}) {
  return RecommendationService(
    repository: RecommendationRepository(
      dataSource: _FakeRecommendationDataSource(
        tagWords: tagWords,
        textWords: textWords,
      ),
    ),
  );
}

VideoFeedItem _createItem({
  String title = '测试标题',
  String description = '测试描述',
  List<String> tags = const [],
  List<String> recommendationWords = const [],
}) {
  return VideoFeedItem(
    id: 'test-video',
    title: title,
    author: const Author(id: 'author', name: '作者', avatarUrl: ''),
    statistics: const Statistics(
      likeCount: 0,
      commentCount: 0,
      favoriteCount: 0,
      shareCount: 0,
    ),
    tags: tags,
    recommendationWords: recommendationWords,
    createdAt: DateTime(2026),
    videoSources: const [
      VideoSource(
        quality: VideoQuality.p720,
        url: 'https://example.com/video.mp4',
        width: 1280,
        height: 720,
        bitrate: 1000,
      ),
    ],
    coverUrl: 'https://example.com/cover.jpg',
    duration: const Duration(seconds: 30),
    description: description,
  );
}

class _FakeRecommendationDataSource implements RecommendationDataSource {
  const _FakeRecommendationDataSource({
    required this.tagWords,
    required this.textWords,
  });

  final Map<String, List<String>> tagWords;
  final Map<String, List<String>> textWords;

  @override
  Future<List<String>> fetchWordsByTags(List<String> tags) async {
    final words = <String>[];
    for (final tag in tags) {
      words.addAll(tagWords[tag] ?? const []);
    }
    return words;
  }

  @override
  Future<List<String>> fetchWordsByText(String text) async {
    for (final entry in textWords.entries) {
      if (text.contains(entry.key)) {
        return entry.value;
      }
    }
    return const [];
  }

  @override
  Future<List<String>> fetchDefaultWords() async {
    return const ['default word'];
  }
}
