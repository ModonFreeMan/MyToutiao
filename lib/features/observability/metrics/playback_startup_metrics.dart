import 'dart:math' as math;

import 'playback_startup_report.dart';
import 'playback_startup_session.dart';

class PlaybackStartupMetrics {
  PlaybackStartupMetrics({
    DateTime Function()? now,
    this.bufferingWindow = const Duration(seconds: 5),
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Duration bufferingWindow;
  final Map<int, PlaybackStartupSession> _sessions =
      <int, PlaybackStartupSession>{};

  int _nextSessionId = 0;
  int _ignoredLateEvents = 0;
  PlaybackStartupSessionRef? _activeSessionRef;

  PlaybackStartupSessionRef markFeedItemVisible({
    required String videoId,
    required int feedIndex,
  }) {
    var ref = PlaybackStartupSessionRef(sessionId: -1, videoId: videoId);
    _safeRecord(() {
      final activeSessionRef = _activeSessionRef;
      final activeSession = activeSessionRef == null
          ? null
          : _sessionFor(activeSessionRef);
      if (activeSession != null &&
          activeSession.status != PlaybackStartupSessionStatus.failed &&
          activeSession.status != PlaybackStartupSessionStatus.closed) {
        activeSession.status = PlaybackStartupSessionStatus.expired;
      }

      final session = PlaybackStartupSession(
        sessionId: ++_nextSessionId,
        videoId: videoId,
        feedIndex: feedIndex,
        createdAt: _now(),
      );
      _sessions[session.sessionId] = session;
      _activeSessionRef = session.ref;
      ref = session.ref;
    });
    return ref;
  }

  void markPlayRequested(
    PlaybackStartupSessionRef session, {
    PlaybackPlayRequestSource source = PlaybackPlayRequestSource.playVideo,
  }) {
    _safeRecord(() {
      final target = _sessionFor(session);
      if (!_canReceiveGeneralEvent(target, session)) {
        return;
      }
      final validTarget = target!;
      _recordPlayRequestSource(validTarget, source);
      _setOnce(validTarget, validTarget.playRequestedAt, () {
        validTarget.playRequestedAt = _now();
      });
    });
  }

  void markControllerInitializeStart(PlaybackStartupSessionRef session) {
    _safeRecord(() {
      final target = _sessionFor(session);
      if (!_canReceiveGeneralEvent(target, session)) {
        return;
      }
      _setOnce(target!, target.controllerInitializeStart, () {
        target.controllerInitializeStart = _now();
      });
    });
  }

  void markControllerInitializeEnd(PlaybackStartupSessionRef session) {
    _safeRecord(() {
      final target = _sessionFor(session);
      if (!_matchesRef(target, session) ||
          target!.status == PlaybackStartupSessionStatus.failed ||
          target.status == PlaybackStartupSessionStatus.closed) {
        _ignoredLateEvents += 1;
        return;
      }
      _setOnce(target, target.controllerInitializeEnd, () {
        target.controllerInitializeEnd = _now();
      });
    });
  }

  void markControllerInitializeFailed(
    PlaybackStartupSessionRef session,
    Object error,
  ) {
    _safeRecord(() {
      final target = _sessionFor(session);
      if (!_matchesRef(target, session) ||
          target!.status == PlaybackStartupSessionStatus.closed) {
        _ignoredLateEvents += 1;
        return;
      }
      target
        ..status = PlaybackStartupSessionStatus.failed
        ..error = error;
    });
  }

  void markPreloadHit(PlaybackStartupSessionRef session) {
    _safeRecord(() {
      final target = _activeSessionFor(session);
      if (target == null) {
        _ignoredLateEvents += 1;
        return;
      }
      target.preloadHit = true;
    });
  }

  void markPreloadMiss(PlaybackStartupSessionRef session) {
    _safeRecord(() {
      final target = _activeSessionFor(session);
      if (target == null) {
        _ignoredLateEvents += 1;
        return;
      }
      target.preloadMiss = true;
    });
  }

  void markPreloadPromotedToActive(PlaybackStartupSessionRef session) {
    _safeRecord(() {
      final target = _activeSessionFor(session);
      if (target == null) {
        _ignoredLateEvents += 1;
        return;
      }
      target.preloadPromotedToActive = true;
    });
  }

  void markFirstFrameRendered(PlaybackStartupSessionRef session) {
    _safeRecord(() {
      final target = _activeSessionFor(session);
      if (target == null) {
        _ignoredLateEvents += 1;
        return;
      }
      _setOnce(target, target.firstFrameRenderedAt, () {
        target.firstFrameRenderedAt = _now();
        _completeIfReady(target);
      });
    });
  }

  void markActualPlaying(PlaybackStartupSessionRef session) {
    _safeRecord(() {
      final target = _activeSessionFor(session);
      if (target == null) {
        _ignoredLateEvents += 1;
        return;
      }
      _setOnce(target, target.actualPlayingAt, () {
        target.actualPlayingAt = _now();
        _completeIfReady(target);
      });
    });
  }

  void markBufferingStart(PlaybackStartupSessionRef session) {
    _safeRecord(() {
      final target = _activeSessionFor(session);
      if (target == null) {
        _ignoredLateEvents += 1;
        return;
      }
      final hasOpenSpan = target.bufferingSpans.any((span) => span.end == null);
      if (hasOpenSpan) {
        _ignoredLateEvents += 1;
        return;
      }
      target.bufferingSpans.add(PlaybackBufferingSpan(start: _now()));
    });
  }

  void markBufferingEnd(PlaybackStartupSessionRef session) {
    _safeRecord(() {
      final target = _activeSessionFor(session);
      if (target == null) {
        _ignoredLateEvents += 1;
        return;
      }
      PlaybackBufferingSpan? openSpan;
      for (final span in target.bufferingSpans) {
        if (span.end == null) {
          openSpan = span;
        }
      }
      if (openSpan == null) {
        _ignoredLateEvents += 1;
        return;
      }
      openSpan.end = _now();
    });
  }

  void markSessionExpired(PlaybackStartupSessionRef session) {
    _safeRecord(() {
      final target = _sessionFor(session);
      if (!_matchesRef(target, session) ||
          target!.status == PlaybackStartupSessionStatus.closed ||
          target.status == PlaybackStartupSessionStatus.failed) {
        return;
      }
      target.status = PlaybackStartupSessionStatus.expired;
      if (_matchesRef(target, _activeSessionRef)) {
        _activeSessionRef = null;
      }
    });
  }

  void markSessionClosed(PlaybackStartupSessionRef session) {
    _safeRecord(() {
      final target = _sessionFor(session);
      if (!_matchesRef(target, session) ||
          target!.status == PlaybackStartupSessionStatus.failed) {
        return;
      }
      target.status = PlaybackStartupSessionStatus.closed;
      if (_matchesRef(target, _activeSessionRef)) {
        _activeSessionRef = null;
      }
    });
  }

  void closeActiveSession() {
    final activeSessionRef = _activeSessionRef;
    if (activeSessionRef == null) {
      return;
    }
    markSessionClosed(activeSessionRef);
  }

  PlaybackStartupBaselineReport buildReport() {
    final reportAt = _now();
    final firstFrameSamples = <int>[];
    final startupSamples = <int>[];
    final initializeSamples = <int>[];
    final bufferingCounts = <int>[];
    final bufferingTotals = <int>[];
    final playRequestSources = <PlaybackPlayRequestSource, int>{
      for (final source in PlaybackPlayRequestSource.values) source: 0,
    };

    var expiredSessions = 0;
    var incompleteSessions = 0;
    var initializeFailedSessions = 0;
    var preloadVisibleItems = 0;
    var preloadHits = 0;
    var preloadMisses = 0;
    var preloadPromotedToActive = 0;

    for (final session in _sessions.values) {
      if (session.status == PlaybackStartupSessionStatus.expired) {
        expiredSessions += 1;
      }
      if (session.status == PlaybackStartupSessionStatus.failed) {
        initializeFailedSessions += 1;
      }
      for (final entry in session.playRequestSourceCounts.entries) {
        playRequestSources[entry.key] =
            (playRequestSources[entry.key] ?? 0) + entry.value;
      }
      if (session.preloadHit || session.preloadMiss) {
        preloadVisibleItems += 1;
      }
      if (session.preloadHit) {
        preloadHits += 1;
      }
      if (session.preloadMiss) {
        preloadMisses += 1;
      }
      if (session.preloadPromotedToActive) {
        preloadPromotedToActive += 1;
      }

      final isUnsuccessful =
          session.status == PlaybackStartupSessionStatus.failed ||
          session.status == PlaybackStartupSessionStatus.closed;
      final hasKeyStartupFields =
          session.firstFrameRenderedAt != null &&
          session.actualPlayingAt != null;
      if (!isUnsuccessful && !hasKeyStartupFields) {
        incompleteSessions += 1;
      }

      final firstFrame = session.firstFrameRenderedAt;
      final visible = session.feedItemVisibleAt;
      if (!isUnsuccessful &&
          firstFrame != null &&
          visible != null &&
          !firstFrame.isBefore(visible)) {
        firstFrameSamples.add(firstFrame.difference(visible).inMilliseconds);
      }

      final actualPlaying = session.actualPlayingAt;
      final playRequested = session.playRequestedAt;
      if (!isUnsuccessful &&
          actualPlaying != null &&
          playRequested != null &&
          !actualPlaying.isBefore(playRequested)) {
        startupSamples.add(
          actualPlaying.difference(playRequested).inMilliseconds,
        );
      }

      final initializeStart = session.controllerInitializeStart;
      final initializeEnd = session.controllerInitializeEnd;
      if (session.status != PlaybackStartupSessionStatus.failed &&
          initializeStart != null &&
          initializeEnd != null &&
          !initializeEnd.isBefore(initializeStart)) {
        initializeSamples.add(
          initializeEnd.difference(initializeStart).inMilliseconds,
        );
      }

      if (actualPlaying != null) {
        final buffering = _bufferingStats(session, reportAt);
        bufferingCounts.add(buffering.count);
        bufferingTotals.add(buffering.total.inMilliseconds);
      }
    }

    return PlaybackStartupBaselineReport(
      reportAt: reportAt,
      bufferingWindow: bufferingWindow,
      visibleItems: _sessions.length,
      validFirstFrameSamples: firstFrameSamples.length,
      validStartupSamples: startupSamples.length,
      validInitializeSamples: initializeSamples.length,
      expiredSessions: expiredSessions,
      incompleteSessions: incompleteSessions,
      initializeFailedSessions: initializeFailedSessions,
      ignoredLateEvents: _ignoredLateEvents,
      preloadVisibleItems: preloadVisibleItems,
      preloadHits: preloadHits,
      preloadMisses: preloadMisses,
      preloadPromotedToActive: preloadPromotedToActive,
      firstFrameMs: _percentiles(firstFrameSamples),
      startupMs: _percentiles(startupSamples),
      initializeMs: _percentiles(initializeSamples),
      startupBufferingCount: _percentiles(bufferingCounts),
      startupBufferingTotalMs: _percentiles(bufferingTotals),
      playRequestSources: <String, int>{
        for (final entry in playRequestSources.entries)
          entry.key.name: entry.value,
      },
    );
  }

  PlaybackStartupSession? _sessionFor(PlaybackStartupSessionRef ref) {
    return _sessions[ref.sessionId];
  }

  PlaybackStartupSession? _activeSessionFor(PlaybackStartupSessionRef ref) {
    final target = _sessionFor(ref);
    if (!_matchesRef(target, ref) || !_matchesRef(target, _activeSessionRef)) {
      return null;
    }
    if (target!.status == PlaybackStartupSessionStatus.failed ||
        target.status == PlaybackStartupSessionStatus.closed ||
        target.status == PlaybackStartupSessionStatus.expired) {
      return null;
    }
    return target;
  }

  bool _canReceiveGeneralEvent(
    PlaybackStartupSession? target,
    PlaybackStartupSessionRef ref,
  ) {
    if (!_matchesRef(target, ref) ||
        target!.status == PlaybackStartupSessionStatus.failed ||
        target.status == PlaybackStartupSessionStatus.closed) {
      _ignoredLateEvents += 1;
      return false;
    }
    return true;
  }

  bool _matchesRef(
    PlaybackStartupSession? session,
    PlaybackStartupSessionRef? ref,
  ) {
    return session != null &&
        ref != null &&
        session.sessionId == ref.sessionId &&
        session.videoId == ref.videoId;
  }

  void _setOnce(
    PlaybackStartupSession session,
    DateTime? currentValue,
    void Function() setValue,
  ) {
    if (currentValue != null) {
      _ignoredLateEvents += 1;
      return;
    }
    setValue();
  }

  void _recordPlayRequestSource(
    PlaybackStartupSession session,
    PlaybackPlayRequestSource source,
  ) {
    session.playRequestSourceCounts[source] =
        (session.playRequestSourceCounts[source] ?? 0) + 1;
  }

  void _completeIfReady(PlaybackStartupSession session) {
    if (session.firstFrameRenderedAt != null &&
        session.actualPlayingAt != null &&
        session.status == PlaybackStartupSessionStatus.active) {
      session.status = PlaybackStartupSessionStatus.completed;
    }
  }

  _BufferingStats _bufferingStats(
    PlaybackStartupSession session,
    DateTime reportAt,
  ) {
    final actualPlayingAt = session.actualPlayingAt!;
    final windowEnd = actualPlayingAt.add(bufferingWindow);
    var count = 0;
    var total = Duration.zero;

    for (final span in session.bufferingSpans) {
      final effectiveStart = _maxDate(span.start, actualPlayingAt);
      final effectiveEnd = _minDate(span.end ?? reportAt, reportAt, windowEnd);
      if (effectiveEnd.isAfter(effectiveStart)) {
        count += 1;
        total += effectiveEnd.difference(effectiveStart);
      }
    }

    return _BufferingStats(count: count, total: total);
  }

  DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  DateTime _minDate(DateTime a, DateTime b, DateTime c) {
    var result = a.isBefore(b) ? a : b;
    result = result.isBefore(c) ? result : c;
    return result;
  }

  PlaybackStartupPercentiles _percentiles(List<int> samples) {
    if (samples.isEmpty) {
      return const PlaybackStartupPercentiles(p50: null, p90: null, p95: null);
    }
    samples.sort();
    return PlaybackStartupPercentiles(
      p50: _nearestRank(samples, 0.50),
      p90: _nearestRank(samples, 0.90),
      p95: _nearestRank(samples, 0.95),
    );
  }

  int _nearestRank(List<int> sortedSamples, double percentile) {
    final index = math.max(0, (sortedSamples.length * percentile).ceil() - 1);
    return sortedSamples[index];
  }

  void _safeRecord(void Function() action) {
    try {
      action();
    } catch (_) {
      // Metrics must never affect playback.
    }
  }
}

class _BufferingStats {
  const _BufferingStats({required this.count, required this.total});

  final int count;
  final Duration total;
}
