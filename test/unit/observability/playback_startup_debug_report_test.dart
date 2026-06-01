import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/features/observability/debug/playback_startup_debug_report.dart';
import 'package:video_player_mvp/features/observability/metrics/playback_startup_metrics.dart';
import 'package:video_player_mvp/features/observability/providers/observability_provider.dart';

void main() {
  group('playback startup debug report', () {
    test('exports metrics json in debug mode', () {
      final metrics = PlaybackStartupMetrics(
        now: () => DateTime.utc(2026, 5, 31, 12),
      );
      final session = metrics.markFeedItemVisible(
        videoId: 'video_001',
        feedIndex: 0,
      );
      metrics.markPreloadMiss(session);

      final json = buildPlaybackStartupDebugReportJson(metrics);

      expect(json, isNotNull);
      expect(json!['preload_enabled'], isTrue);
      expect(json['preload_misses'], 1);
      expect(json['preload_hit_rate_label'], '0.0%');
    });

    test('provider exposes a fresh debug report builder', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final metrics = container.read(playbackStartupMetricsProvider);
      final buildReport = container.read(playbackStartupDebugReportProvider);

      final session = metrics.markFeedItemVisible(
        videoId: 'video_001',
        feedIndex: 0,
      );
      metrics.markPreloadHit(session);

      final json = buildReport();

      expect(json, isNotNull);
      expect(json!['preload_hits'], 1);
      expect(json['preload_hit_rate_label'], '100.0%');

      final miss = metrics.markFeedItemVisible(
        videoId: 'video_002',
        feedIndex: 1,
      );
      metrics.markPreloadMiss(miss);

      final updatedJson = buildReport();

      expect(updatedJson, isNotNull);
      expect(updatedJson!['preload_hits'], 1);
      expect(updatedJson['preload_misses'], 1);
      expect(updatedJson['preload_hit_rate_label'], '50.0%');
    });
  });
}
