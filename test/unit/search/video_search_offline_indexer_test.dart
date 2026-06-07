import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/data/search_index/offline_video_input.dart';
import 'package:video_player_mvp/data/search_index/search_business_store.dart';
import 'package:video_player_mvp/data/search_index/search_embedding_service.dart';
import 'package:video_player_mvp/data/search_index/search_offline_config.dart';
import 'package:video_player_mvp/data/search_index/search_vector_store.dart';
import 'package:video_player_mvp/data/search_index/video_search_offline_indexer.dart';
import 'package:video_player_mvp/data/search_index/video_summary_generator.dart';

void main() {
  group('VideoSearchOfflineIndexer', () {
    test(
      'writes local content summary and keywords to business store',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'search_index_test_',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final vectorStore = _RecordingVectorStore();
        final indexer = VideoSearchOfflineIndexer(
          summaryGenerator: const LocalVideoSummaryGenerator(),
          embeddingService: const DeterministicSearchEmbeddingService(),
          businessStore: JsonSearchBusinessStore(
            file: File('${tempDir.path}/videos.json'),
          ),
          vectorStore: vectorStore,
        );

        await indexer.index(
          const OfflineVideoInput(
            videoId: 'video_001',
            title: 'Flutter 横屏播放器切换',
            description: '介绍横屏播放和清晰度切换。',
            tags: ['Flutter', '播放器', '横屏播放'],
            recommendationWords: ['Flutter 视频播放器', '清晰度切换'],
          ),
        );

        final saved = await JsonSearchBusinessStore(
          file: File('${tempDir.path}/videos.json'),
        ).findByVideoId('video_001');

        expect(saved, isNotNull);
        expect(saved!.summary, contains('标题：Flutter 横屏播放器切换'));
        expect(saved.summary, contains('简介：介绍横屏播放和清晰度切换。'));
        expect(saved.summary, contains('标签：Flutter、播放器、横屏播放'));
        expect(saved.keywords.length, greaterThanOrEqualTo(5));
        expect(saved.keywords, containsAll(['Flutter 视频播放器', '清晰度切换', '横屏播放']));
        expect(vectorStore.videoId, 'video_001');
        expect(vectorStore.summaryEmbedding, hasLength(32));
      },
    );

    test('upserts business document when indexing same video twice', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'search_index_test_',
      );
      addTearDown(() => tempDir.delete(recursive: true));
      final businessStore = JsonSearchBusinessStore(
        file: File('${tempDir.path}/videos.json'),
      );
      final indexer = VideoSearchOfflineIndexer(
        summaryGenerator: const LocalVideoSummaryGenerator(),
        embeddingService: const DeterministicSearchEmbeddingService(),
        businessStore: businessStore,
        vectorStore: _RecordingVectorStore(),
      );

      await indexer.index(
        const OfflineVideoInput(
          videoId: 'video_001',
          title: '旧标题',
          description: '',
          tags: ['旧标签'],
          recommendationWords: ['旧推荐词'],
        ),
      );
      await indexer.index(
        const OfflineVideoInput(
          videoId: 'video_001',
          title: '新标题',
          description: '',
          tags: ['新标签'],
          recommendationWords: ['新推荐词'],
        ),
      );

      final saved = await businessStore.findByVideoId('video_001');

      expect(saved!.title, '新标题');
      expect(saved.keywords, contains('新推荐词'));
      expect(saved.keywords, isNot(contains('旧推荐词')));
      expect(saved.summary, contains('标题：新标题'));
    });
  });

  group('FixedVideoSummaryGenerator', () {
    test('keeps fixed summary for compatibility', () async {
      final generated = await const FixedVideoSummaryGenerator().generate(
        const OfflineVideoInput(
          videoId: 'video_001',
          title: 'Flutter 横屏播放器切换',
          description: '介绍横屏播放和清晰度切换。',
          tags: ['Flutter', '播放器', '横屏播放'],
          recommendationWords: ['Flutter 视频播放器', '清晰度切换'],
        ),
      );

      expect(generated.summary, '这个视频主要介绍 Flutter 视频播放器的横屏播放和清晰度切换。');
      expect(generated.keywords, contains('Flutter 视频播放器'));
    });
  });

  group('DeterministicSearchEmbeddingService', () {
    test('generates stable normalized embedding', () async {
      const service = DeterministicSearchEmbeddingService();

      final first = await service.embed('固定摘要');
      final second = await service.embed('固定摘要');

      expect(first, second);
      expect(first, hasLength(32));
      expect(first.any((value) => value != 0), isTrue);
    });
  });

  group('SearchOfflineConfig', () {
    test('loads API endpoint and text-embedding-3-small model', () {
      final config = SearchOfflineConfig.fromJson(const {
        'apiBaseUrl': 'https://api.bianxieai.com',
        'chatCompletionEndpoint':
            'https://api.bianxieai.com/v1/chat/completions',
        'chatModel': 'gpt-4o-mini-2024-07-18',
        'embeddingEndpoint': 'https://api.bianxieai.com/v1/embeddings',
        'apiKey': 'test-key',
        'embeddingModel': 'text-embedding-3-small',
        'milvusHost': '192.168.1.13',
        'milvusPort': 19530,
      });

      expect(config.apiBaseUrl, 'https://api.bianxieai.com');
      expect(
        config.chatCompletionEndpoint,
        'https://api.bianxieai.com/v1/chat/completions',
      );
      expect(config.chatModel, 'gpt-4o-mini-2024-07-18');
      expect(
        config.embeddingEndpoint,
        'https://api.bianxieai.com/v1/embeddings',
      );
      expect(config.apiKey, 'test-key');
      expect(config.embeddingModel, 'text-embedding-3-small');
      expect(config.milvusHost, '192.168.1.13');
      expect(config.milvusPort, 19530);
      expect(config.milvusCollectionName, 'video_summary_search_flat');
    });

    test('rejects missing API key', () {
      expect(
        () => SearchOfflineConfig.fromJson(const {'apiKey': ''}),
        throwsFormatException,
      );
    });

    test('keeps backward-compatible endpoint default from base URL', () {
      final config = SearchOfflineConfig.fromJson(const {
        'apiBaseUrl': 'https://api.bianxieai.com/',
        'apiKey': 'test-key',
      });

      expect(
        config.embeddingEndpoint,
        'https://api.bianxieai.com/v1/embeddings',
      );
      expect(
        config.chatCompletionEndpoint,
        'https://api.bianxieai.com/v1/chat/completions',
      );
    });
  });
}

class _RecordingVectorStore implements SearchVectorStore {
  String? videoId;
  List<double>? summaryEmbedding;

  @override
  Future<List<SearchVectorResult>> searchSummaryEmbedding({
    required List<double> queryEmbedding,
    int limit = 10,
  }) async {
    return const <SearchVectorResult>[];
  }

  @override
  Future<void> upsertSummaryEmbedding({
    required String videoId,
    required List<double> summaryEmbedding,
  }) async {
    this.videoId = videoId;
    this.summaryEmbedding = summaryEmbedding;
  }
}
