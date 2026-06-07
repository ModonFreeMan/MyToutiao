import 'dart:io';

import 'package:video_player_mvp/data/search_index/search_embedding_service.dart';
import 'package:video_player_mvp/data/search_index/search_offline_config.dart';
import 'package:video_player_mvp/data/search_index/search_vector_store.dart';
import 'package:video_player_mvp/data/search_index/video_dense_search_service.dart';

Future<void> main(List<String> args) async {
  final options = _DenseSearchOptions.parse(args);
  if (options.query.trim().isEmpty) {
    stderr.writeln('Usage: dart run tool/search_dense_query.dart <query>');
    exitCode = 64;
    return;
  }

  final config = await SearchOfflineConfig.load(File(options.configPath));
  final service = VideoDenseSearchService(
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

  final results = await service.search(options.query, limit: options.limit);
  for (final result in results) {
    stdout.writeln('${result.videoId}\t${result.score}');
  }
}

class _DenseSearchOptions {
  const _DenseSearchOptions({
    required this.query,
    required this.configPath,
    required this.limit,
  });

  final String query;
  final String configPath;
  final int limit;

  static _DenseSearchOptions parse(List<String> args) {
    var configPath = 'config/search_offline_config.json';
    var limit = 10;
    final queryParts = <String>[];

    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      switch (arg) {
        case '--config':
          configPath = args[++index];
          break;
        case '--limit':
          limit = int.parse(args[++index]);
          break;
        default:
          queryParts.add(arg);
      }
    }

    return _DenseSearchOptions(
      query: queryParts.join(' '),
      configPath: configPath,
      limit: limit,
    );
  }
}
