enum VideoQuality {
  p360,
  p720,
  p1080,
}

class VideoSource {
  const VideoSource({
    required this.quality,
    required this.url,
    required this.width,
    required this.height,
    required this.bitrate,
  });

  final VideoQuality quality;
  final String url;
  final int width;
  final int height;
  final int bitrate;

  String get qualityLabel {
    switch (quality) {
      case VideoQuality.p360:
        return '360P';
      case VideoQuality.p720:
        return '720P';
      case VideoQuality.p1080:
        return '1080P';
    }
  }
}
