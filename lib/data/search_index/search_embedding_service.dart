import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

abstract interface class SearchEmbeddingService {
  int get dimension;

  Future<List<double>> embed(String text);
}

class OpenAICompatibleSearchEmbeddingService implements SearchEmbeddingService {
  OpenAICompatibleSearchEmbeddingService({
    required this.apiKey,
    String? endpoint,
    String? baseUrl,
    this.model = 'text-embedding-3-small',
    this.dimension = 1536,
    HttpClient? httpClient,
  }) : endpoint =
           endpoint ??
           _endpointFromBaseUrl(baseUrl ?? 'https://api.bianxieai.com'),
       _httpClient = httpClient ?? HttpClient();

  final String apiKey;
  final String endpoint;
  final String model;
  final HttpClient _httpClient;

  @override
  final int dimension;

  @override
  Future<List<double>> embed(String text) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('Embedding API key is required.');
    }

    final uri = Uri.parse(endpoint);
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.write(jsonEncode({'model': model, 'input': text}));

    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Embedding request failed: ${response.statusCode} $responseText',
        uri: uri,
      );
    }

    final decoded = jsonDecode(responseText) as Map<String, Object?>;
    final data = decoded['data'];
    if (data is! List<Object?> || data.isEmpty) {
      throw const FormatException('Embedding response data is empty.');
    }

    final first = data.first;
    if (first is! Map<String, Object?>) {
      throw const FormatException('Embedding response item must be an object.');
    }

    final embedding = first['embedding'];
    if (embedding is! List<Object?>) {
      throw const FormatException('Embedding response missing embedding list.');
    }

    return embedding.map((value) => (value as num).toDouble()).toList();
  }

  static String _endpointFromBaseUrl(String baseUrl) {
    final normalizedBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$normalizedBaseUrl/v1/embeddings';
  }
}

class DeterministicSearchEmbeddingService implements SearchEmbeddingService {
  const DeterministicSearchEmbeddingService({this.dimension = 32});

  @override
  final int dimension;

  @override
  Future<List<double>> embed(String text) async {
    final vector = List<double>.filled(dimension, 0);
    final normalizedText = text.trim().toLowerCase();

    for (var index = 0; index < normalizedText.length; index++) {
      final codeUnit = normalizedText.codeUnitAt(index);
      final bucket = (codeUnit + index * 17) % dimension;
      vector[bucket] += 1 + (codeUnit % 13) / 13;
    }

    final length = math.sqrt(
      vector.fold<double>(0, (sum, value) => sum + value * value),
    );
    if (length == 0) {
      return vector;
    }

    return vector.map((value) => value / length).toList(growable: false);
  }
}
