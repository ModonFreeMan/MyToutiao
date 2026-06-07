import 'dart:convert';
import 'dart:io';

class SearchOfflineConfig {
  const SearchOfflineConfig({
    required this.apiKey,
    this.apiBaseUrl = 'https://api.bianxieai.com',
    this.chatCompletionEndpoint =
        'https://api.bianxieai.com/v1/chat/completions',
    this.chatModel = 'gpt-4o-mini-2024-07-18',
    this.embeddingEndpoint = 'https://api.bianxieai.com/v1/embeddings',
    this.embeddingModel = 'text-embedding-3-small',
    this.milvusHost = '192.168.1.13',
    this.milvusPort = 19530,
    this.milvusCollectionName = 'video_summary_search_flat',
    this.businessStorePath = 'build/search/video_documents.json',
  });

  final String apiKey;
  final String apiBaseUrl;
  final String chatCompletionEndpoint;
  final String chatModel;
  final String embeddingEndpoint;
  final String embeddingModel;
  final String milvusHost;
  final int milvusPort;
  final String milvusCollectionName;
  final String businessStorePath;

  static Future<SearchOfflineConfig> load(File file) async {
    if (!await file.exists()) {
      throw StateError(
        'Missing search offline config: ${file.path}. '
        'Copy config/search_offline_config.example.json to this path and fill apiKey.',
      );
    }

    final decoded =
        jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return SearchOfflineConfig.fromJson(decoded);
  }

  factory SearchOfflineConfig.fromJson(Map<String, Object?> json) {
    final apiKey = json['apiKey'];
    if (apiKey is! String || apiKey.trim().isEmpty) {
      throw const FormatException(
        'search offline config requires non-empty apiKey.',
      );
    }

    return SearchOfflineConfig(
      apiKey: apiKey,
      apiBaseUrl: json['apiBaseUrl'] as String? ?? 'https://api.bianxieai.com',
      chatCompletionEndpoint:
          json['chatCompletionEndpoint'] as String? ??
          _endpointFromBaseUrl(
            json['apiBaseUrl'] as String? ?? 'https://api.bianxieai.com',
            '/v1/chat/completions',
          ),
      chatModel: json['chatModel'] as String? ?? 'gpt-4o-mini-2024-07-18',
      embeddingEndpoint:
          json['embeddingEndpoint'] as String? ??
          _endpointFromBaseUrl(
            json['apiBaseUrl'] as String? ?? 'https://api.bianxieai.com',
            '/v1/embeddings',
          ),
      embeddingModel:
          json['embeddingModel'] as String? ?? 'text-embedding-3-small',
      milvusHost: json['milvusHost'] as String? ?? '192.168.1.13',
      milvusPort: json['milvusPort'] as int? ?? 19530,
      milvusCollectionName:
          json['milvusCollectionName'] as String? ??
          'video_summary_search_flat',
      businessStorePath:
          json['businessStorePath'] as String? ??
          'build/search/video_documents.json',
    );
  }

  static String _endpointFromBaseUrl(String baseUrl, String path) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$normalizedBaseUrl$path';
  }
}
