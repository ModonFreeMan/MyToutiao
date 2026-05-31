class PlaybackStartupPercentiles {
  const PlaybackStartupPercentiles({
    required this.p50,
    required this.p90,
    required this.p95,
  });

  final int? p50;
  final int? p90;
  final int? p95;

  Map<String, Object?> toJson() => <String, Object?>{
    'p50': p50,
    'p90': p90,
    'p95': p95,
  };
}

class PlaybackStartupBaselineReport {
  const PlaybackStartupBaselineReport({
    required this.reportAt,
    required this.bufferingWindow,
    required this.visibleItems,
    required this.validFirstFrameSamples,
    required this.validStartupSamples,
    required this.validInitializeSamples,
    required this.expiredSessions,
    required this.incompleteSessions,
    required this.initializeFailedSessions,
    required this.ignoredLateEvents,
    required this.firstFrameMs,
    required this.startupMs,
    required this.initializeMs,
    required this.startupBufferingCount,
    required this.startupBufferingTotalMs,
    required this.playRequestSources,
  });

  final DateTime reportAt;
  final Duration bufferingWindow;
  final int visibleItems;
  final int validFirstFrameSamples;
  final int validStartupSamples;
  final int validInitializeSamples;
  final int expiredSessions;
  final int incompleteSessions;
  final int initializeFailedSessions;
  final int ignoredLateEvents;
  final PlaybackStartupPercentiles firstFrameMs;
  final PlaybackStartupPercentiles startupMs;
  final PlaybackStartupPercentiles initializeMs;
  final PlaybackStartupPercentiles startupBufferingCount;
  final PlaybackStartupPercentiles startupBufferingTotalMs;
  final Map<String, int> playRequestSources;

  static const String metricSemantics = 'business_side_approximate_observation';

  Map<String, Object?> toJson() => <String, Object?>{
    'report_at': reportAt.toUtc().toIso8601String(),
    'buffering_window_ms': bufferingWindow.inMilliseconds,
    'metric_semantics': metricSemantics,
    'preload_enabled': false,
    'preload_hit_rate': null,
    'preload_hit_rate_label': 'N/A',
    'visible_items': visibleItems,
    'valid_first_frame_samples': validFirstFrameSamples,
    'valid_startup_samples': validStartupSamples,
    'valid_initialize_samples': validInitializeSamples,
    'expired_sessions': expiredSessions,
    'incomplete_sessions': incompleteSessions,
    'initialize_failed_sessions': initializeFailedSessions,
    'ignored_late_events': ignoredLateEvents,
    'first_frame_ms': firstFrameMs.toJson(),
    'startup_ms': startupMs.toJson(),
    'initialize_ms': initializeMs.toJson(),
    'startup_buffering_count': startupBufferingCount.toJson(),
    'startup_buffering_total_ms': startupBufferingTotalMs.toJson(),
    'play_request_sources': playRequestSources,
  };
}
