import 'dart:convert';
import 'dart:io';

class SearchVectorResult {
  const SearchVectorResult({required this.videoId, required this.score});

  final String videoId;
  final double score;
}

abstract interface class SearchVectorStore {
  Future<void> upsertSummaryEmbedding({
    required String videoId,
    required List<double> summaryEmbedding,
  });

  Future<List<SearchVectorResult>> searchSummaryEmbedding({
    required List<double> queryEmbedding,
    int limit = 10,
  });
}

class MilvusSearchVectorStore implements SearchVectorStore {
  MilvusSearchVectorStore({
    this.host = '192.168.1.13',
    this.port = 19530,
    this.collectionName = 'video_summary_search_flat',
    this.vectorFieldName = 'summaryEmbedding',
    this.primaryFieldName = 'videoId',
    this.indexName = 'summaryEmbedding_flat',
    this.indexType = 'FLAT',
    this.metricType = 'COSINE',
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final String host;
  final int port;
  final String collectionName;
  final String vectorFieldName;
  final String primaryFieldName;
  final String indexName;
  final String indexType;
  final String metricType;
  final HttpClient _httpClient;

  @override
  Future<void> upsertSummaryEmbedding({
    required String videoId,
    required List<double> summaryEmbedding,
  }) async {
    await _ensureCollection(dimension: summaryEmbedding.length);
    await _post('/v2/vectordb/entities/upsert', {
      'collectionName': collectionName,
      'data': [
        {primaryFieldName: videoId, vectorFieldName: summaryEmbedding},
      ],
    });
  }

  @override
  Future<List<SearchVectorResult>> searchSummaryEmbedding({
    required List<double> queryEmbedding,
    int limit = 10,
  }) async {
    final response = await _post('/v2/vectordb/entities/search', {
      'collectionName': collectionName,
      'data': [queryEmbedding],
      'annsField': vectorFieldName,
      'limit': limit,
      'outputFields': [primaryFieldName],
    });

    final data = response['data'];
    if (data is! List<Object?>) {
      throw const FormatException(
        'Milvus search response data must be a list.',
      );
    }

    return data
        .map((item) => _searchResultFromJson(item))
        .whereType<SearchVectorResult>()
        .toList(growable: false);
  }

  Future<void> _ensureCollection({required int dimension}) async {
    final hasCollection = await _post('/v2/vectordb/collections/has', {
      'collectionName': collectionName,
    });

    if (hasCollection['data'] == true) {
      return;
    }

    await _post('/v2/vectordb/collections/create', {
      'collectionName': collectionName,
      'schema': {
        'autoId': false,
        'enabledDynamicField': false,
        'fields': [
          {
            'fieldName': primaryFieldName,
            'dataType': 'VarChar',
            'isPrimary': true,
            'elementTypeParams': {'max_length': '128'},
          },
          {
            'fieldName': vectorFieldName,
            'dataType': 'FloatVector',
            'elementTypeParams': {'dim': dimension.toString()},
          },
        ],
      },
      'indexParams': [
        {
          'metricType': metricType,
          'fieldName': vectorFieldName,
          'indexName': indexName,
          'params': {'index_type': indexType},
        },
      ],
    });
  }

  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body,
  ) async {
    final request = await _httpClient.post(host, port, path);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));

    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Milvus request failed: ${response.statusCode} $responseText',
        uri: Uri.http('$host:$port', path),
      );
    }

    final decoded = jsonDecode(responseText);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Milvus response must be a JSON object.');
    }

    final code = decoded['code'];
    if (code != null && code != 0 && code != 200) {
      throw StateError('Milvus request failed: $decoded');
    }

    return decoded;
  }

  SearchVectorResult? _searchResultFromJson(Object? value) {
    if (value is! Map<String, Object?>) {
      return null;
    }

    final videoId = _readVideoId(value);
    if (videoId == null || videoId.isEmpty) {
      return null;
    }

    return SearchVectorResult(videoId: videoId, score: _readScore(value));
  }

  String? _readVideoId(Map<String, Object?> item) {
    final directValue = item[primaryFieldName];
    if (directValue is String) {
      return directValue;
    }

    final idValue = item['id'];
    if (idValue is String) {
      return idValue;
    }

    final entity = item['entity'];
    if (entity is Map<String, Object?>) {
      final entityVideoId = entity[primaryFieldName];
      if (entityVideoId is String) {
        return entityVideoId;
      }
    }

    return null;
  }

  double _readScore(Map<String, Object?> item) {
    final scoreValue = item['score'] ?? item['distance'];
    if (scoreValue is num) {
      return scoreValue.toDouble();
    }

    return 0;
  }
}
