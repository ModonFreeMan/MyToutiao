enum PlaybackStartupSessionStatus { active, completed, expired, failed, closed }

enum PlaybackPlayRequestSource {
  playVideo,
  resume,
  togglePlayPause,
  ensurePlaybackIntent,
  switchQuality,
}

class PlaybackStartupSessionRef {
  const PlaybackStartupSessionRef({
    required this.sessionId,
    required this.videoId,
  });

  final int sessionId;
  final String videoId;
}

class PlaybackBufferingSpan {
  PlaybackBufferingSpan({required this.start});

  final DateTime start;
  DateTime? end;
}

class PlaybackStartupSession {
  PlaybackStartupSession({
    required this.sessionId,
    required this.videoId,
    required this.feedIndex,
    required this.createdAt,
  }) : feedItemVisibleAt = createdAt;

  final int sessionId;
  final String videoId;
  final int feedIndex;
  final DateTime createdAt;

  PlaybackStartupSessionStatus status = PlaybackStartupSessionStatus.active;

  DateTime? feedItemVisibleAt;
  DateTime? controllerInitializeStart;
  DateTime? controllerInitializeEnd;
  DateTime? firstFrameRenderedAt;
  DateTime? playRequestedAt;
  DateTime? actualPlayingAt;

  bool preloadHit = false;
  bool preloadMiss = false;
  bool preloadPromotedToActive = false;
  Object? error;

  final List<PlaybackBufferingSpan> bufferingSpans = <PlaybackBufferingSpan>[];
  final Map<PlaybackPlayRequestSource, int> playRequestSourceCounts =
      <PlaybackPlayRequestSource, int>{};

  PlaybackStartupSessionRef get ref =>
      PlaybackStartupSessionRef(sessionId: sessionId, videoId: videoId);
}
