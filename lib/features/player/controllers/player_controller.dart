import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../data/models/video_feed_item.dart';
import '../../../data/models/video_source.dart';
import '../states/player_state.dart';

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);

class PlayerController extends Notifier<PlayerState> {
  static const Duration _initializeTimeout = Duration(seconds: 12);

  VideoPlayerController? _controller;
  String? _controllerVideoId;
  int _initToken = 0;

  VideoPlayerController? get videoController => _controller;

  @override
  PlayerState build() {
    ref.onDispose(_disposeCurrent);
    return const PlayerState.initial();
  }

  Future<void> playVideo(
    VideoFeedItem item, {
    bool forceRestart = false,
  }) async {
    if (!forceRestart && state.videoId == item.id && state.isInitializing) {
      return;
    }

    if (!forceRestart && _controllerVideoId == item.id && state.isInitialized) {
      state = state.copyWith(wantsToPlay: true);
      await _controller?.play();
      _syncFromController();
      return;
    }

    final token = ++_initToken;
    await _disposeCurrent();

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
    final nextController = VideoPlayerController.networkUrl(
      Uri.parse(source.url),
    );

    try {
      await nextController.initialize().timeout(_initializeTimeout);
      if (token != _initToken) {
        await nextController.dispose();
        return;
      }

      nextController
        ..setLooping(true)
        ..addListener(_syncFromController);

      _controller = nextController;
      _controllerVideoId = item.id;

      state = state.copyWith(
        isInitializing: false,
        isInitialized: true,
        duration: nextController.value.duration,
        clearError: true,
      );

      await nextController.play();
      _syncFromController();
    } catch (error) {
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
    final nextController = VideoPlayerController.networkUrl(
      Uri.parse(source.url),
    );

    try {
      await nextController.initialize().timeout(_initializeTimeout);
      if (token != _initToken) {
        await nextController.dispose();
        return;
      }

      nextController
        ..setLooping(true)
        ..addListener(_syncFromController);

      _controller = nextController;
      _controllerVideoId = item.id;

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
        await nextController.play();
      }
      _syncFromController();
    } catch (error) {
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

  Future<void> resume() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    await _playPreservingProgress(controller);
  }

  Future<void> ensurePlaybackIntent(String videoId) async {
    if (state.videoId != videoId ||
        !state.isInitialized ||
        state.isPlaying ||
        !state.wantsToPlay) {
      return;
    }

    await resume();
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
      return;
    }

    controller.removeListener(_syncFromController);
    _controller = null;
    _controllerVideoId = null;
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
}
