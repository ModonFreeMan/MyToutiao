import 'package:video_player/video_player.dart';

import '../../../data/models/video_source.dart';

class PlayerState {
  const PlayerState({
    required this.videoId,
    required this.controller,
    required this.selectedQuality,
    required this.isInitializing,
    required this.isInitialized,
    required this.isPlaying,
    required this.isBuffering,
    required this.currentPosition,
    required this.duration,
    required this.error,
  });

  const PlayerState.initial()
    : videoId = null,
      controller = null,
      selectedQuality = VideoQuality.p720,
      isInitializing = false,
      isInitialized = false,
      isPlaying = false,
      isBuffering = false,
      currentPosition = Duration.zero,
      duration = Duration.zero,
      error = null;

  final String? videoId;
  final VideoPlayerController? controller;
  final VideoQuality selectedQuality;
  final bool isInitializing;
  final bool isInitialized;
  final bool isPlaying;
  final bool isBuffering;
  final Duration currentPosition;
  final Duration duration;
  final String? error;

  PlayerState copyWith({
    String? videoId,
    VideoPlayerController? controller,
    VideoQuality? selectedQuality,
    bool? isInitializing,
    bool? isInitialized,
    bool? isPlaying,
    bool? isBuffering,
    Duration? currentPosition,
    Duration? duration,
    String? error,
    bool clearController = false,
    bool clearError = false,
  }) {
    return PlayerState(
      videoId: videoId ?? this.videoId,
      controller: clearController ? null : controller ?? this.controller,
      selectedQuality: selectedQuality ?? this.selectedQuality,
      isInitializing: isInitializing ?? this.isInitializing,
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      currentPosition: currentPosition ?? this.currentPosition,
      duration: duration ?? this.duration,
      error: clearError ? null : error ?? this.error,
    );
  }
}
