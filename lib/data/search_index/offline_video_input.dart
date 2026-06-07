class OfflineVideoInput {
  const OfflineVideoInput({
    required this.videoId,
    required this.title,
    required this.description,
    required this.tags,
    required this.recommendationWords,
    this.transcript = '',
  });

  final String videoId;
  final String title;
  final String description;
  final List<String> tags;
  final List<String> recommendationWords;
  final String transcript;

  String toContentText() {
    return [
      '标题：$title',
      if (description.trim().isNotEmpty) '简介：$description',
      if (tags.isNotEmpty) '标签：${tags.join('、')}',
      if (recommendationWords.isNotEmpty)
        '推荐词：${recommendationWords.join('、')}',
      if (transcript.trim().isNotEmpty) '字幕：$transcript',
    ].join('\n');
  }
}
