import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../debug/playback_startup_debug_report.dart';
import '../metrics/playback_startup_metrics.dart';

typedef PlaybackStartupDebugReportBuilder = Map<String, Object?>? Function();

final playbackStartupMetricsProvider = Provider<PlaybackStartupMetrics>(
  (_) => PlaybackStartupMetrics(),
);

final playbackStartupDebugReportProvider =
    Provider<PlaybackStartupDebugReportBuilder>(
      (ref) =>
          () => buildPlaybackStartupDebugReportJson(
            ref.read(playbackStartupMetricsProvider),
          ),
    );
