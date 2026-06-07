import 'dart:convert';
import 'dart:io';

import 'offline_video_input.dart';

class GeneratedVideoSummary {
  const GeneratedVideoSummary({required this.summary, required this.keywords});

  final String summary;
  final List<String> keywords;
}

abstract interface class VideoSummaryGenerator {
  Future<GeneratedVideoSummary> generate(OfflineVideoInput input);
}

class ChatCompletionKeywordVideoSummaryGenerator
    implements VideoSummaryGenerator {
  ChatCompletionKeywordVideoSummaryGenerator({
    required this.apiKey,
    required this.endpoint,
    this.model = 'gpt-4o-mini-2024-07-18',
    this.temperature = 0.2,
    this.localGenerator = const LocalVideoSummaryGenerator(),
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  final String apiKey;
  final String endpoint;
  final String model;
  final double temperature;
  final LocalVideoSummaryGenerator localGenerator;
  final HttpClient _httpClient;

  @override
  Future<GeneratedVideoSummary> generate(OfflineVideoInput input) async {
    if (apiKey.trim().isEmpty) {
      throw StateError('Chat completion API key is required.');
    }

    final localGenerated = await localGenerator.generate(input);
    final modelKeywords = await _generateKeywords(input);
    final keywords = deduplicateSearchKeywords([
      ...modelKeywords,
      ...localGenerated.keywords,
    ]).take(10).toList();

    return GeneratedVideoSummary(
      summary: localGenerated.summary,
      keywords: keywords,
    );
  }

  Future<List<String>> _generateKeywords(OfflineVideoInput input) async {
    final uri = Uri.parse(endpoint);
    final request = await _httpClient.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.write(
      jsonEncode({
        'model': model,
        'temperature': temperature,
        'response_format': {'type': 'json_object'},
        'messages': [
          {
            'role': 'system',
            'content': '你是视频搜索推荐词生成助手。请只根据视频信息生成中文搜索推荐词，并只输出 JSON。',
          },
          {
            'role': 'user',
            'content':
                '''
请根据下面的视频信息生成 5 到 10 个用户可能搜索的推荐词。

要求：
1. 只生成推荐词，不生成摘要。
2. 推荐词要覆盖视频主题、动作、场景、教程意图和用户常见表达。
3. 推荐词不要重复，不要超过 10 个。
4. 只返回 JSON，格式为 {"keywords":["..."]}。

视频信息：
${input.toContentText()}
''',
          },
        ],
      }),
    );

    final response = await request.close();
    final responseText = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Chat completion request failed: ${response.statusCode} $responseText',
        uri: uri,
      );
    }

    final decoded = jsonDecode(responseText) as Map<String, Object?>;
    final choices = decoded['choices'];
    if (choices is! List<Object?> || choices.isEmpty) {
      throw const FormatException('Chat completion response choices is empty.');
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map<String, Object?>) {
      throw const FormatException('Chat completion choice must be an object.');
    }

    final message = firstChoice['message'];
    if (message is! Map<String, Object?>) {
      throw const FormatException('Chat completion message must be an object.');
    }

    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const FormatException('Chat completion content is empty.');
    }

    return _parseKeywords(content);
  }

  List<String> _parseKeywords(String content) {
    final jsonText = _stripCodeFence(content.trim());
    final decoded = jsonDecode(jsonText) as Map<String, Object?>;
    final keywords = decoded['keywords'];
    if (keywords is! List<Object?>) {
      throw const FormatException('Generated keywords must be a list.');
    }

    return deduplicateSearchKeywords(
      keywords
          .whereType<String>()
          .map((keyword) => keyword.trim())
          .where((keyword) => keyword.isNotEmpty)
          .toList(),
    );
  }

  String _stripCodeFence(String content) {
    if (!content.startsWith('```')) {
      return content;
    }

    return content
        .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
        .replaceFirst(RegExp(r'\s*```$'), '')
        .trim();
  }
}

class LocalVideoSummaryGenerator implements VideoSummaryGenerator {
  const LocalVideoSummaryGenerator();

  @override
  Future<GeneratedVideoSummary> generate(OfflineVideoInput input) async {
    final keywords = <String>[
      ...input.recommendationWords,
      ...input.tags,
      ..._splitTitle(input.title),
    ];

    return GeneratedVideoSummary(
      summary: input.toContentText(),
      keywords: deduplicateSearchKeywords(keywords).take(10).toList(),
    );
  }

  List<String> _splitTitle(String title) {
    return title
        .split(RegExp(r'[\s:：,，、]+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
  }
}

class FixedVideoSummaryGenerator extends LocalVideoSummaryGenerator {
  const FixedVideoSummaryGenerator({
    this.summary = '这个视频主要介绍 Flutter 视频播放器的横屏播放和清晰度切换。',
  });

  final String summary;

  @override
  Future<GeneratedVideoSummary> generate(OfflineVideoInput input) async {
    final generated = await super.generate(input);
    return GeneratedVideoSummary(
      summary: summary,
      keywords: generated.keywords,
    );
  }
}

List<String> deduplicateSearchKeywords(List<String> words) {
  final seen = <String>{};
  final result = <String>[];

  for (final word in words) {
    final normalized = word.trim();
    if (normalized.isEmpty || seen.contains(normalized)) {
      continue;
    }

    seen.add(normalized);
    result.add(normalized);
  }

  return result;
}
