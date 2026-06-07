import 'dart:io';

import 'package:video_player_mvp/data/models/feed_item.dart';
import 'package:video_player_mvp/data/models/video_feed_item.dart';
import 'package:video_player_mvp/data/search_index/offline_video_input.dart';
import 'package:video_player_mvp/data/search_index/search_business_store.dart';
import 'package:video_player_mvp/data/search_index/search_embedding_service.dart';
import 'package:video_player_mvp/data/search_index/search_offline_config.dart';
import 'package:video_player_mvp/data/search_index/search_vector_store.dart';
import 'package:video_player_mvp/data/search_index/video_search_offline_indexer.dart';
import 'package:video_player_mvp/data/search_index/video_summary_generator.dart';
import 'package:video_player_mvp/mock/mock_feed_items.dart';

Future<void> main(List<String> args) async {
  final configPath =
      _argValue(args, '--config') ?? 'config/search_offline_config.json';
  final config = await SearchOfflineConfig.load(File(configPath));
  final outputPath =
      _argValue(args, '--business-store') ?? config.businessStorePath;
  final host = _argValue(args, '--milvus-host') ?? config.milvusHost;
  final port = int.parse(
    _argValue(args, '--milvus-port') ?? config.milvusPort.toString(),
  );
  final collectionName =
      _argValue(args, '--milvus-collection') ?? config.milvusCollectionName;
  final limit = int.parse(_argValue(args, '--limit') ?? '3');

  final indexer = VideoSearchOfflineIndexer(
    summaryGenerator: const LocalVideoSummaryGenerator(),
    embeddingService: OpenAICompatibleSearchEmbeddingService(
      apiKey: config.apiKey,
      endpoint: config.embeddingEndpoint,
      model: config.embeddingModel,
    ),
    businessStore: JsonSearchBusinessStore(file: File(outputPath)),
    vectorStore: MilvusSearchVectorStore(
      host: host,
      port: port,
      collectionName: collectionName,
    ),
  );

  final videos = mockFeedItems
      .whereType<VideoFeedItem>()
      .where((item) => item.type == FeedItemType.video)
      .take(limit);

  for (final video in videos) {
    final document = await indexer.index(
      OfflineVideoInput(
        videoId: video.id,
        title: video.title,
        description: video.description,
        tags: video.tags,
        recommendationWords: video.recommendationWords,
      ),
    );
    stdout.writeln('indexed ${document.videoId}: ${document.title}');
  }

  stdout.writeln('business store: $outputPath');
  stdout.writeln('milvus: $host:$port/$collectionName');
  stdout.writeln('embedding endpoint: ${config.embeddingEndpoint}');
  stdout.writeln('embedding model: ${config.embeddingModel}');
}

String? _argValue(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) {
    return null;
  }

  return args[index + 1];
}
