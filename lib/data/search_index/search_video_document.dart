class SearchVideoDocument {
  const SearchVideoDocument({
    required this.videoId,
    required this.title,
    required this.summary,
    required this.keywords,
  });

  final String videoId;
  final String title;
  final String summary;
  final List<String> keywords;

  Map<String, Object?> toJson() {
    return {
      'videoId': videoId,
      'title': title,
      'summary': summary,
      'keywords': keywords,
    };
  }

  factory SearchVideoDocument.fromJson(Map<String, Object?> json) {
    return SearchVideoDocument(
      videoId: json['videoId']! as String,
      title: json['title']! as String,
      summary: json['summary']! as String,
      keywords: (json['keywords']! as List<Object?>).cast<String>(),
    );
  }
}
