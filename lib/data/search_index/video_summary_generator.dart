import 'offline_video_input.dart';

class GeneratedVideoSummary {
  const GeneratedVideoSummary({required this.summary, required this.keywords});

  final String summary;
  final List<String> keywords;
}

abstract interface class VideoSummaryGenerator {
  Future<GeneratedVideoSummary> generate(OfflineVideoInput input);
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
      keywords: _deduplicate(keywords).take(10).toList(),
    );
  }

  List<String> _splitTitle(String title) {
    return title
        .split(RegExp(r'[\s:：,，、]+'))
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList();
  }

  List<String> _deduplicate(List<String> words) {
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
