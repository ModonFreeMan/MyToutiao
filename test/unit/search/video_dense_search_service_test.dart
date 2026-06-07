import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/data/search_index/search_embedding_service.dart';
import 'package:video_player_mvp/data/search_index/search_vector_store.dart';
import 'package:video_player_mvp/data/search_index/video_dense_search_service.dart';

void main() {
  group('VideoDenseSearchService', () {
    test('embeds query and returns vector search results', () async {
      final embeddingService = _RecordingEmbeddingService();
      final vectorStore = _RecordingSearchVectorStore();
      final service = VideoDenseSearchService(
        embeddingService: embeddingService,
        vectorStore: vectorStore,
      );

      final results = await service.search('  Flutter 横屏播放  ', limit: 3);

      expect(embeddingService.text, 'Flutter 横屏播放');
      expect(vectorStore.queryEmbedding, <double>[0.1, 0.2, 0.3]);
      expect(vectorStore.limit, 3);
      expect(results, hasLength(2));
      expect(results.first.videoId, 'video_010');
      expect(results.first.score, 0.92);
    });

    test('returns empty results for blank query', () async {
      final embeddingService = _RecordingEmbeddingService();
      final vectorStore = _RecordingSearchVectorStore();
      final service = VideoDenseSearchService(
        embeddingService: embeddingService,
        vectorStore: vectorStore,
      );

      final results = await service.search('   ');

      expect(results, isEmpty);
      expect(embeddingService.text, isNull);
      expect(vectorStore.queryEmbedding, isNull);
    });
  });
}

class _RecordingEmbeddingService implements SearchEmbeddingService {
  String? text;

  @override
  int get dimension => 3;

  @override
  Future<List<double>> embed(String text) async {
    this.text = text;
    return <double>[0.1, 0.2, 0.3];
  }
}

class _RecordingSearchVectorStore implements SearchVectorStore {
  int? limit;
  List<double>? queryEmbedding;

  @override
  Future<List<SearchVectorResult>> searchSummaryEmbedding({
    required List<double> queryEmbedding,
    int limit = 10,
  }) async {
    this.queryEmbedding = queryEmbedding;
    this.limit = limit;
    return const <SearchVectorResult>[
      SearchVectorResult(videoId: 'video_010', score: 0.92),
      SearchVectorResult(videoId: 'video_001', score: 0.81),
    ];
  }

  @override
  Future<void> upsertSummaryEmbedding({
    required String videoId,
    required List<double> summaryEmbedding,
  }) async {}
}
