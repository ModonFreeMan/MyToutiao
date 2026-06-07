import 'dart:io';

import '../../mock/mock_feed_items.dart';
import '../models/feed_item.dart';
import '../models/video_feed_item.dart';
import '../search_index/search_business_store.dart';
import '../search_index/search_embedding_service.dart';
import '../search_index/search_offline_config.dart';
import '../search_index/search_video_document.dart';
import '../search_index/search_vector_store.dart';
import '../search_index/video_dense_search_service.dart';
import 'mock_search_datasource.dart';
import 'search_data_source.dart';

class DenseSearchDataSource implements SearchDataSource {
  DenseSearchDataSource({
    required this.serviceLoader,
    required this.businessStore,
    List<FeedItem>? feedItems,
    this.fallback,
    this.limit = 20,
  }) : _feedItems = feedItems ?? mockFeedItems;

  factory DenseSearchDataSource.localConfig({
    String configPath = 'config/search_offline_config.json',
    List<FeedItem>? feedItems,
    SearchDataSource fallback = const MockSearchDataSource(),
    int limit = 20,
  }) {
    return DenseSearchDataSource(
      serviceLoader: () async {
        final config = await SearchOfflineConfig.load(File(configPath));
        return VideoDenseSearchService(
          embeddingService: OpenAICompatibleSearchEmbeddingService(
            apiKey: config.apiKey,
            endpoint: config.embeddingEndpoint,
            model: config.embeddingModel,
          ),
          vectorStore: MilvusSearchVectorStore(
            host: config.milvusHost,
            port: config.milvusPort,
            collectionName: config.milvusCollectionName,
          ),
        );
      },
      businessStore: JsonSearchBusinessStore(
        file: File('build/search/video_documents.json'),
      ),
      feedItems: feedItems,
      fallback: fallback,
      limit: limit,
    );
  }

  final Future<VideoDenseSearchService> Function() serviceLoader;
  final SearchBusinessStore businessStore;
  final List<FeedItem> _feedItems;
  final SearchDataSource? fallback;
  final int limit;
  Future<VideoDenseSearchService>? _serviceFuture;

  @override
  Future<List<VideoFeedItem>> searchVideos(String keyword) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return const <VideoFeedItem>[];
    }

    try {
      final service = await (_serviceFuture ??= serviceLoader());
      final vectorResults = await service.search(
        normalizedKeyword,
        limit: limit,
      );
      final documents = await businessStore.findAll();
      final videosById = _videosById();
      final scoredResults = _mergeResults(
        keyword: normalizedKeyword,
        vectorResults: vectorResults,
        documents: documents,
      );

      return scoredResults
          .map((result) => videosById[result.videoId])
          .whereType<VideoFeedItem>()
          .toList(growable: false);
    } catch (_) {
      final fallbackDataSource = fallback;
      if (fallbackDataSource == null) {
        rethrow;
      }

      return fallbackDataSource.searchVideos(keyword);
    }
  }

  Map<String, VideoFeedItem> _videosById() {
    return {
      for (final item in _feedItems)
        if (item is VideoFeedItem) item.id: item,
    };
  }

  List<_HybridSearchResult> _mergeResults({
    required String keyword,
    required List<SearchVectorResult> vectorResults,
    required List<SearchVideoDocument> documents,
  }) {
    final vectorScores = <String, double>{
      for (final result in vectorResults) result.videoId: result.score,
    };
    final keywordScores = <String, int>{};

    for (final document in documents) {
      final score = _keywordScore(document, keyword);
      if (score > 0) {
        keywordScores[document.videoId] = score;
      }
    }

    final maxKeywordScore = keywordScores.values.fold<int>(
      0,
      (max, score) => score > max ? score : max,
    );
    final videoIds = <String>{...vectorScores.keys, ...keywordScores.keys};
    final results = <_HybridSearchResult>[];

    for (final videoId in videoIds) {
      final vectorScore = vectorScores[videoId] ?? 0;
      final keywordScore = keywordScores[videoId] ?? 0;
      final normalizedKeywordScore = maxKeywordScore == 0
          ? 0.0
          : keywordScore / maxKeywordScore;
      final finalScore = vectorScore * 0.7 + normalizedKeywordScore * 0.3;

      if (finalScore > 0) {
        results.add(
          _HybridSearchResult(videoId: videoId, finalScore: finalScore),
        );
      }
    }

    results.sort((a, b) => b.finalScore.compareTo(a.finalScore));
    return results;
  }

  int _keywordScore(SearchVideoDocument document, String keyword) {
    var score = 0;
    final normalizedKeyword = keyword.toLowerCase();

    if (document.title.toLowerCase().contains(normalizedKeyword)) {
      score += 5;
    }

    for (final word in document.keywords) {
      if (word.toLowerCase().contains(normalizedKeyword)) {
        score += 4;
        break;
      }
    }

    if (document.summary.toLowerCase().contains(normalizedKeyword)) {
      score += 1;
    }

    return score;
  }
}

class _HybridSearchResult {
  const _HybridSearchResult({required this.videoId, required this.finalScore});

  final String videoId;
  final double finalScore;
}
