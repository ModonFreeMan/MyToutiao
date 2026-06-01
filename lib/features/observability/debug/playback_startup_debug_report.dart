import 'package:flutter/foundation.dart';

import '../metrics/playback_startup_metrics.dart';

Map<String, Object?>? buildPlaybackStartupDebugReportJson(
  PlaybackStartupMetrics metrics,
) {
  if (!kDebugMode) {
    return null;
  }

  return metrics.buildReport().toJson();
}
