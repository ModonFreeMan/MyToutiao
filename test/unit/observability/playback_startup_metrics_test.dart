import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/features/observability/metrics/playback_startup_metrics.dart';
import 'package:video_player_mvp/features/observability/metrics/playback_startup_session.dart';

void main() {
  group('PlaybackStartupMetrics', () {
    late _FakeClock clock;
    late PlaybackStartupMetrics metrics;

    setUp(() {
      clock = _FakeClock(DateTime.utc(2026, 5, 31, 12));
      metrics = PlaybackStartupMetrics(now: clock.now);
    });

    test(
      'complete session reports first frame, startup, and initialize ms',
      () {
        final session = metrics.markFeedItemVisible(
          videoId: 'video_001',
          feedIndex: 0,
        );
        clock.elapse(const Duration(milliseconds: 10));
        metrics.markPlayRequested(session);
        clock.elapse(const Duration(milliseconds: 20));
        metrics.markControllerInitializeStart(session);
        clock.elapse(const Duration(milliseconds: 300));
        metrics.markControllerInitializeEnd(session);
        clock.elapse(const Duration(milliseconds: 70));
        metrics.markFirstFrameRendered(session);
        clock.elapse(const Duration(milliseconds: 30));
        metrics.markActualPlaying(session);

        final json = metrics.buildReport().toJson();

        expect(json['valid_first_frame_samples'], 1);
        expect(json['valid_startup_samples'], 1);
        expect(json['valid_initialize_samples'], 1);
        expect(json['first_frame_ms'], {'p50': 400, 'p90': 400, 'p95': 400});
        expect(json['startup_ms'], {'p50': 420, 'p90': 420, 'p95': 420});
        expect(json['initialize_ms'], {'p50': 300, 'p90': 300, 'p95': 300});
      },
    );

    test('ignores active-only events from expired sessions', () {
      final expired = metrics.markFeedItemVisible(
        videoId: 'video_001',
        feedIndex: 0,
      );
      clock.elapse(const Duration(milliseconds: 10));
      metrics.markControllerInitializeStart(expired);

      metrics.markFeedItemVisible(videoId: 'video_002', feedIndex: 1);
      clock.elapse(const Duration(milliseconds: 200));
      metrics.markControllerInitializeEnd(expired);
      metrics.markFirstFrameRendered(expired);
      metrics.markActualPlaying(expired);
      metrics.markBufferingStart(expired);

      final json = metrics.buildReport().toJson();

      expect(json['expired_sessions'], 1);
      expect(json['valid_initialize_samples'], 1);
      expect(json['initialize_ms'], {'p50': 200, 'p90': 200, 'p95': 200});
      expect(json['valid_first_frame_samples'], 0);
      expect(json['valid_startup_samples'], 0);
      expect(json['ignored_late_events'], 3);
    });

    test(
      'failed initialize is counted and excluded from initialize samples',
      () {
        final session = metrics.markFeedItemVisible(
          videoId: 'video_001',
          feedIndex: 0,
        );
        metrics.markControllerInitializeStart(session);
        clock.elapse(const Duration(milliseconds: 120));
        metrics.markControllerInitializeFailed(session, StateError('failed'));
        metrics.markControllerInitializeEnd(session);

        final json = metrics.buildReport().toJson();

        expect(json['initialize_failed_sessions'], 1);
        expect(json['valid_initialize_samples'], 0);
        expect(json['initialize_ms'], {'p50': null, 'p90': null, 'p95': null});
      },
    );

    test('duplicate events do not overwrite first timestamps', () {
      final session = metrics.markFeedItemVisible(
        videoId: 'video_001',
        feedIndex: 0,
      );
      clock.elapse(const Duration(milliseconds: 10));
      metrics.markPlayRequested(session);
      clock.elapse(const Duration(milliseconds: 90));
      metrics.markPlayRequested(
        session,
        source: PlaybackPlayRequestSource.resume,
      );
      clock.elapse(const Duration(milliseconds: 10));
      metrics.markActualPlaying(session);

      final json = metrics.buildReport().toJson();

      expect(json['startup_ms'], {'p50': 100, 'p90': 100, 'p95': 100});
      expect(json['play_request_sources'], {
        'playVideo': 1,
        'resume': 1,
        'togglePlayPause': 0,
        'ensurePlaybackIntent': 0,
        'switchQuality': 0,
      });
      expect(json['ignored_late_events'], 1);
    });

    test('open buffering span is truncated by report time and window', () {
      final session = metrics.markFeedItemVisible(
        videoId: 'video_001',
        feedIndex: 0,
      );
      metrics.markPlayRequested(session);
      metrics.markActualPlaying(session);
      clock.elapse(const Duration(seconds: 1));
      metrics.markBufferingStart(session);
      clock.elapse(const Duration(seconds: 8));

      final json = metrics.buildReport().toJson();

      expect(json['startup_buffering_count'], {'p50': 1, 'p90': 1, 'p95': 1});
      expect(json['startup_buffering_total_ms'], {
        'p50': 4000,
        'p90': 4000,
        'p95': 4000,
      });
    });

    test('empty preload samples report N/A', () {
      final json = metrics.buildReport().toJson();

      expect(json['preload_enabled'], isFalse);
      expect(json['preload_visible_items'], 0);
      expect(json['preload_hits'], 0);
      expect(json['preload_misses'], 0);
      expect(json['preload_promoted_to_active'], 0);
      expect(json['preload_hit_rate'], isNull);
      expect(json['preload_hit_rate_label'], 'N/A');
    });

    test('preload hit contributes to hit rate', () {
      final hit = metrics.markFeedItemVisible(
        videoId: 'video_001',
        feedIndex: 0,
      );
      metrics.markPreloadHit(hit);
      metrics.markPreloadPromotedToActive(hit);

      final json = metrics.buildReport().toJson();

      expect(json['preload_enabled'], isTrue);
      expect(json['preload_visible_items'], 1);
      expect(json['preload_hits'], 1);
      expect(json['preload_misses'], 0);
      expect(json['preload_promoted_to_active'], 1);
      expect(json['preload_hit_rate'], 1);
      expect(json['preload_hit_rate_label'], '100.0%');
    });

    test('preload miss contributes to visible preload sample', () {
      final miss = metrics.markFeedItemVisible(
        videoId: 'video_001',
        feedIndex: 0,
      );
      metrics.markPreloadMiss(miss);

      final json = metrics.buildReport().toJson();

      expect(json['preload_enabled'], isTrue);
      expect(json['preload_visible_items'], 1);
      expect(json['preload_hits'], 0);
      expect(json['preload_misses'], 1);
      expect(json['preload_hit_rate'], 0);
      expect(json['preload_hit_rate_label'], '0.0%');
    });

    test('late preload hit event is ignored', () {
      final expired = metrics.markFeedItemVisible(
        videoId: 'video_001',
        feedIndex: 0,
      );
      metrics.markFeedItemVisible(videoId: 'video_002', feedIndex: 1);

      metrics.markPreloadHit(expired);
      metrics.markPreloadMiss(expired);
      metrics.markPreloadPromotedToActive(expired);

      final json = metrics.buildReport().toJson();

      expect(json['preload_visible_items'], 0);
      expect(json['preload_hits'], 0);
      expect(json['preload_misses'], 0);
      expect(json['preload_promoted_to_active'], 0);
      expect(json['ignored_late_events'], 3);
    });

    test('empty samples report null percentiles', () {
      final json = metrics.buildReport().toJson();

      expect(json['visible_items'], 0);
      expect(json['first_frame_ms'], {'p50': null, 'p90': null, 'p95': null});
      expect(json['startup_ms'], {'p50': null, 'p90': null, 'p95': null});
      expect(json['initialize_ms'], {'p50': null, 'p90': null, 'p95': null});
    });

    test('invalid refs and repeated closes never throw', () {
      const invalid = PlaybackStartupSessionRef(
        sessionId: 99,
        videoId: 'missing',
      );

      expect(() {
        metrics
          ..markPlayRequested(invalid)
          ..markControllerInitializeStart(invalid)
          ..markControllerInitializeEnd(invalid)
          ..markControllerInitializeFailed(invalid, Object())
          ..markPreloadHit(invalid)
          ..markPreloadMiss(invalid)
          ..markPreloadPromotedToActive(invalid)
          ..markFirstFrameRendered(invalid)
          ..markActualPlaying(invalid)
          ..markBufferingStart(invalid)
          ..markBufferingEnd(invalid)
          ..markSessionExpired(invalid)
          ..markSessionClosed(invalid);
      }, returnsNormally);
    });
  });
}

class _FakeClock {
  _FakeClock(this._now);

  DateTime _now;

  DateTime now() => _now;

  void elapse(Duration duration) {
    _now = _now.add(duration);
  }
}
