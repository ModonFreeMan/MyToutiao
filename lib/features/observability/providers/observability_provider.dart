import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../metrics/playback_startup_metrics.dart';

final playbackStartupMetricsProvider = Provider<PlaybackStartupMetrics>(
  (_) => PlaybackStartupMetrics(),
);
