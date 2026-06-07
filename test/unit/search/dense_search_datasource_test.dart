import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/data/datasources/dense_search_datasource.dart';
import 'package:video_player_mvp/data/datasources/mock_search_datasource.dart';
import 'package:video_player_mvp/data/search_index/search_business_store.dart';
import 'package:video_player_mvp/data/search_index/search_embedding_service.dart';
import 'package:video_player_mvp/data/search_index/search_video_document.dart';
import 'package:video_player_mvp/data/search_index/search_vector_store.dart';
import 'package:video_player_mvp/data/search_index/video_dense_search_service.dart';
import 'package:video_player_mvp/mock/mock_feed_items.dart';

void main() {
  group('DenseSearchDataSource', () {
    test('maps vector result ids to videos in vector order', () async {
      final dataSource = DenseSearchDataSource(
        serviceLoader: () async => VideoDenseSearchService(
          embeddingService: _StaticEmbeddingService(),
          vectorStore: _StaticVectorStore(
            results: const <SearchVectorResult>[
              SearchVectorResult(videoId: 'video_010', score: 0.47),
              SearchVectorResult(videoId: 'unknown_video', score: 0.4),
              SearchVectorResult(videoId: 'video_001', score: 0.16),
            ],
          ),
        ),
        businessStore: const _StaticBusinessStore(),
        feedItems: mockFeedItems,
      );

      final results = await dataSource.searchVideos('Flutter');

      expect(results.map((item) => item.id), ['video_010', 'video_001']);
    });

    test('combines vector score and normalized keyword score', () async {
      final dataSource = DenseSearchDataSource(
        serviceLoader: () async => VideoDenseSearchService(
          embeddingService: _StaticEmbeddingService(),
          vectorStore: _StaticVectorStore(
            results: const <SearchVectorResult>[
              SearchVectorResult(videoId: 'video_001', score: 0.5),
              SearchVectorResult(videoId: 'video_010', score: 0.1),
            ],
          ),
        ),
        businessStore: const _StaticBusinessStore(
          documents: <SearchVideoDocument>[
            SearchVideoDocument(
              videoId: 'video_010',
              title: 'Flutter 动画微交互：按钮反馈更自然',
              summary: 'Flutter 按钮动画',
              keywords: <String>['Flutter', '按钮反馈'],
            ),
            SearchVideoDocument(
              videoId: 'video_001',
              title: '篮球变向运球',
              summary: '篮球训练',
              keywords: <String>['篮球'],
            ),
          ],
        ),
        feedItems: mockFeedItems,
      );

      final results = await dataSource.searchVideos('Flutter');

      expect(results.map((item) => item.id).take(2), [
        'video_010',
        'video_001',
      ]);
    });

    test('falls back to mock search when dense search fails', () async {
      final dataSource = DenseSearchDataSource(
        serviceLoader: () async => throw StateError('missing config'),
        businessStore: const _StaticBusinessStore(),
        feedItems: mockFeedItems,
        fallback: const MockSearchDataSource(),
      );

      final results = await dataSource.searchVideos('按钮反馈');

      expect(results.map((item) => item.id), ['video_010']);
    });

    test('returns empty results for blank keyword', () async {
      final dataSource = DenseSearchDataSource(
        serviceLoader: () async => throw StateError('should not load service'),
        businessStore: const _StaticBusinessStore(),
      );

      await expectLater(dataSource.searchVideos('   '), completion(isEmpty));
    });
  });
}

class _StaticEmbeddingService implements SearchEmbeddingService {
  @override
  int get dimension => 3;

  @override
  Future<List<double>> embed(String text) async {
    return const <double>[0.1, 0.2, 0.3];
  }
}

class _StaticVectorStore implements SearchVectorStore {
  const _StaticVectorStore({required this.results});

  final List<SearchVectorResult> results;

  @override
  Future<List<SearchVectorResult>> searchSummaryEmbedding({
    required List<double> queryEmbedding,
    int limit = 10,
  }) async {
    return results.take(limit).toList(growable: false);
  }

  @override
  Future<void> upsertSummaryEmbedding({
    required String videoId,
    required List<double> summaryEmbedding,
  }) async {}
}

class _StaticBusinessStore implements SearchBusinessStore {
  const _StaticBusinessStore({this.documents = const <SearchVideoDocument>[]});

  final List<SearchVideoDocument> documents;

  @override
  Future<List<SearchVideoDocument>> findAll() async {
    return documents;
  }

  @override
  Future<SearchVideoDocument?> findByVideoId(String videoId) async {
    for (final document in documents) {
      if (document.videoId == videoId) {
        return document;
      }
    }

    return null;
  }

  @override
  Future<void> upsert(SearchVideoDocument document) async {}
}
