import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../data/models/video_feed_item.dart';
import '../../../data/models/video_source.dart';
import '../../observability/metrics/playback_startup_metrics.dart';
import '../../observability/metrics/playback_startup_session.dart';
import '../../observability/providers/observability_provider.dart';
import '../states/player_state.dart';

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);

class PlayerController extends Notifier<PlayerState> {
  static const Duration _initializeTimeout = Duration(seconds: 12);

  VideoPlayerController? _controller;
  String? _controllerVideoId;
  PlaybackStartupSessionRef? _controllerStartupSession;
  PlaybackStartupMetrics? _startupMetrics;
  int _initToken = 0;
  bool _lastControllerIsPlaying = false;
  bool _lastControllerIsBuffering = false;
  String? _preloadVideoId;

  VideoPlayerController? get videoController => _controller;
  PlaybackStartupSessionRef? get startupSession => _controllerStartupSession;
  String? get preloadVideoId => _preloadVideoId;

  @override
  PlayerState build() {
    _startupMetrics = ref.read(playbackStartupMetricsProvider);
    ref.onDispose(() {
      _closeCurrentStartupSession();
      unawaited(_disposeCurrent());
    });
    return const PlayerState.initial();
  }

  Future<void> playVideo(
    VideoFeedItem item, {
    bool forceRestart = false,
    PlaybackStartupSessionRef? startupSession,
  }) async {
    final startupMetrics = _metrics;

    if (!forceRestart && state.videoId == item.id && state.isInitializing) {
      return;
    }

    if (!forceRestart && _controllerVideoId == item.id && state.isInitialized) {
      if (startupSession != null) {
        _controllerStartupSession = startupSession;
      }
      _markPlayRequestedIfBound(PlaybackPlayRequestSource.playVideo);
      state = state.copyWith(wantsToPlay: true);
      await _controller?.play();
      _syncFromController();
      return;
    }

    final token = ++_initToken;
    await _disposeCurrent();
    _controllerStartupSession = startupSession;

    const selectedQuality = VideoQuality.p720;
    state = PlayerState(
      videoId: item.id,
      selectedQuality: selectedQuality,
      isInitializing: true,
      isInitialized: false,
      isPlaying: false,
      wantsToPlay: true,
      isBuffering: false,
      currentPosition: Duration.zero,
      duration: item.duration,
      error: null,
      isLandscapeRendering: state.isLandscapeRendering,
    );

    final source = item.sourceForQuality(selectedQuality);
    if (startupSession != null) {
      startupMetrics
        ..markPlayRequested(
          startupSession,
          source: PlaybackPlayRequestSource.playVideo,
        )
        ..markControllerInitializeStart(startupSession);
    }
    final nextController = VideoPlayerController.networkUrl(
      Uri.parse(source.url),
    );

    try {
      await nextController.initialize().timeout(_initializeTimeout);
      if (startupSession != null) {
        startupMetrics.markControllerInitializeEnd(startupSession);
      }
      if (token != _initToken) {
        await nextController.dispose();
        return;
      }

      nextController
        ..setLooping(true)
        ..addListener(_syncFromController);

      _controller = nextController;
      _controllerVideoId = item.id;
      _controllerStartupSession = startupSession;

      state = state.copyWith(
        isInitializing: false,
        isInitialized: true,
        duration: nextController.value.duration,
        clearError: true,
      );

      await nextController.play();
      _syncFromController();
    } catch (error) {
      if (startupSession != null) {
        startupMetrics.markControllerInitializeFailed(startupSession, error);
      }
      if (token == _initToken) {
        _controllerStartupSession = null;
      }
      await nextController.dispose();
      if (token != _initToken) {
        return;
      }

      state = state.copyWith(
        isInitializing: false,
        isInitialized: false,
        isPlaying: false,
        error: error.toString(),
      );
    }
  }

  Future<void> switchQuality(VideoFeedItem item, VideoQuality quality) async {
    if (state.videoId != item.id || state.selectedQuality == quality) {
      return;
    }

    final currentController = _controller;
    final shouldContinuePlaying = state.wantsToPlay;
    final previousPosition =
        currentController?.value.position ?? state.currentPosition;
    final token = ++_initToken;
    final startupMetrics = _metrics;
    final startupSession = _controllerStartupSession;

    state = state.copyWith(
      videoId: item.id,
      selectedQuality: quality,
      isInitializing: true,
      isInitialized: false,
      isPlaying: false,
      wantsToPlay: shouldContinuePlaying,
      isBuffering: false,
      currentPosition: previousPosition,
      duration: item.duration,
      clearError: true,
    );

    await _disposeCurrent(waitForDispose: false);

    final source = item.sourceForQuality(quality);
    if (startupSession != null) {
      startupMetrics.markControllerInitializeStart(startupSession);
    }
    final nextController = VideoPlayerController.networkUrl(
      Uri.parse(source.url),
    );

    try {
      await nextController.initialize().timeout(_initializeTimeout);
      if (startupSession != null) {
        startupMetrics.markControllerInitializeEnd(startupSession);
      }
      if (token != _initToken) {
        await nextController.dispose();
        return;
      }

      nextController
        ..setLooping(true)
        ..addListener(_syncFromController);

      _controller = nextController;
      _controllerVideoId = item.id;
      _controllerStartupSession = startupSession;

      final duration = nextController.value.duration;
      final seekPosition = _clampPosition(previousPosition, duration);
      if (seekPosition > Duration.zero) {
        await nextController.seekTo(seekPosition);
      }

      state = state.copyWith(
        selectedQuality: quality,
        isInitializing: false,
        isInitialized: true,
        currentPosition: seekPosition,
        duration: duration,
        clearError: true,
      );

      if (shouldContinuePlaying) {
        if (startupSession != null) {
          startupMetrics.markPlayRequested(
            startupSession,
            source: PlaybackPlayRequestSource.switchQuality,
          );
        }
        await nextController.play();
      }
      _syncFromController();
    } catch (error) {
      if (startupSession != null) {
        startupMetrics.markControllerInitializeFailed(startupSession, error);
      }
      await nextController.dispose();
      if (token != _initToken) {
        return;
      }

      state = state.copyWith(
        isInitializing: false,
        isInitialized: false,
        isPlaying: false,
        wantsToPlay: false,
        error: error.toString(),
      );
    }
  }

  Future<void> togglePlayPause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      final position = await controller.position ?? controller.value.position;
      state = state.copyWith(wantsToPlay: false);
      await controller.pause();
      _syncFromController(currentPosition: position);
      return;
    }

    _markPlayRequestedIfBound(PlaybackPlayRequestSource.togglePlayPause);
    await _playPreservingProgress(controller);
  }

  Future<void> pause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final position = await controller.position ?? controller.value.position;
    state = state.copyWith(wantsToPlay: false);
    await controller.pause();
    _syncFromController(currentPosition: position);
  }

  Future<void> resume({
    PlaybackPlayRequestSource source = PlaybackPlayRequestSource.resume,
  }) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    _markPlayRequestedIfBound(source);
    await _playPreservingProgress(controller);
  }

  Future<void> ensurePlaybackIntent(String videoId) async {
    if (state.videoId != videoId ||
        !state.isInitialized ||
        state.isPlaying ||
        !state.wantsToPlay) {
      return;
    }

    await resume(source: PlaybackPlayRequestSource.ensurePlaybackIntent);
  }

  Future<void> preloadVideo(VideoFeedItem item) async {
    if (state.videoId == item.id) {
      return;
    }

    _preloadVideoId = item.id;
  }

  Future<void> disposePreload() async {
    _preloadVideoId = null;
  }

  Future<void> seekToProgress(double progress) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final duration = controller.value.duration;
    if (duration == Duration.zero) {
      return;
    }

    final nextPosition = duration * progress.clamp(0, 1);
    await controller.seekTo(nextPosition);
    _syncFromController();
  }

  Future<void> stopIfCurrent(String videoId) async {
    if (_controllerVideoId != videoId && state.videoId != videoId) {
      return;
    }

    ++_initToken;
    _closeCurrentStartupSession();
    state = const PlayerState.initial();
    await _disposeCurrent();
  }

  void setLandscapeRendering(bool isLandscapeRendering) {
    if (state.isLandscapeRendering == isLandscapeRendering) {
      return;
    }

    state = state.copyWith(isLandscapeRendering: isLandscapeRendering);
  }

  Future<void> stop() async {
    ++_initToken;
    _closeCurrentStartupSession();
    state = const PlayerState.initial();
    await _disposeCurrent();
  }

  void _syncFromController({Duration? currentPosition}) {
    final controller = _controller;
    if (controller == null || _controllerVideoId == null) {
      return;
    }

    final value = controller.value;
    final duration = value.duration;
    final startupMetrics = _metrics;
    final startupSession = _controllerStartupSession;
    if (!_lastControllerIsPlaying && value.isPlaying) {
      if (startupSession != null) {
        startupMetrics.markActualPlaying(startupSession);
      }
    }
    if (!_lastControllerIsBuffering && value.isBuffering) {
      if (startupSession != null) {
        startupMetrics.markBufferingStart(startupSession);
      }
    } else if (_lastControllerIsBuffering && !value.isBuffering) {
      if (startupSession != null) {
        startupMetrics.markBufferingEnd(startupSession);
      }
    }
    _lastControllerIsPlaying = value.isPlaying;
    _lastControllerIsBuffering = value.isBuffering;

    state = state.copyWith(
      videoId: _controllerVideoId,
      selectedQuality: state.selectedQuality,
      isInitializing: false,
      isInitialized: value.isInitialized,
      isPlaying: value.isPlaying,
      isBuffering: value.isBuffering,
      currentPosition: _clampPosition(
        currentPosition ?? value.position,
        duration,
      ),
      duration: duration,
    );
  }

  Future<void> _playPreservingProgress(VideoPlayerController controller) async {
    state = state.copyWith(wantsToPlay: true);
    final currentPosition = state.currentPosition;
    final cachedPosition = controller.value.position;

    if (cachedPosition < currentPosition) {
      await controller.seekTo(currentPosition);
    }

    await controller.play();

    final nextCachedPosition = controller.value.position;
    _syncFromController(
      currentPosition: nextCachedPosition < currentPosition
          ? currentPosition
          : nextCachedPosition,
    );
  }

  Future<void> _disposeCurrent({bool waitForDispose = true}) async {
    final controller = _controller;
    if (controller == null) {
      _controllerVideoId = null;
      _controllerStartupSession = null;
      _lastControllerIsPlaying = false;
      _lastControllerIsBuffering = false;
      return;
    }

    controller.removeListener(_syncFromController);
    _controller = null;
    _controllerVideoId = null;
    _controllerStartupSession = null;
    _lastControllerIsPlaying = false;
    _lastControllerIsBuffering = false;
    final dispose = controller.dispose();
    if (waitForDispose) {
      await dispose;
    } else {
      unawaited(dispose);
    }
  }

  Duration _clampPosition(Duration position, Duration duration) {
    if (duration == Duration.zero || position <= duration) {
      return position;
    }

    return duration;
  }

  PlaybackStartupSessionRef? _activeStartupSessionForCurrentVideo() {
    return _controllerStartupSession;
  }

  void _closeCurrentStartupSession() {
    final startupSession = _controllerStartupSession;
    if (startupSession == null) {
      return;
    }
    _startupMetrics?.markSessionClosed(startupSession);
  }

  void _markPlayRequestedIfBound(PlaybackPlayRequestSource source) {
    final startupSession = _activeStartupSessionForCurrentVideo();
    if (startupSession == null) {
      return;
    }
    _metrics.markPlayRequested(startupSession, source: source);
  }

  PlaybackStartupMetrics get _metrics {
    final startupMetrics = _startupMetrics;
    if (startupMetrics != null) {
      return startupMetrics;
    }
    final initializedMetrics = ref.read(playbackStartupMetricsProvider);
    _startupMetrics = initializedMetrics;
    return initializedMetrics;
  }
}
