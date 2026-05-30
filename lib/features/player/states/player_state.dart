import '../../../data/models/video_source.dart';

class PlayerState {
  const PlayerState({
    required this.videoId,
    required this.selectedQuality,
    required this.isInitializing,
    required this.isInitialized,
    required this.isPlaying,
    required this.wantsToPlay,
    required this.isBuffering,
    required this.currentPosition,
    required this.duration,
    required this.error,
    required this.isLandscapeRendering,
  });

  const PlayerState.initial()
    : videoId = null,
      selectedQuality = VideoQuality.p720,
      isInitializing = false,
      isInitialized = false,
      isPlaying = false,
      wantsToPlay = false,
      isBuffering = false,
      currentPosition = Duration.zero,
      duration = Duration.zero,
      error = null,
      isLandscapeRendering = false;

  final String? videoId;
  final VideoQuality selectedQuality;
  final bool isInitializing;
  final bool isInitialized;
  final bool isPlaying;
  final bool wantsToPlay;
  final bool isBuffering;
  final Duration currentPosition;
  final Duration duration;
  final String? error;
  final bool isLandscapeRendering;

  PlayerState copyWith({
    String? videoId,
    VideoQuality? selectedQuality,
    bool? isInitializing,
    bool? isInitialized,
    bool? isPlaying,
    bool? wantsToPlay,
    bool? isBuffering,
    Duration? currentPosition,
    Duration? duration,
    String? error,
    bool? isLandscapeRendering,
    bool clearError = false,
  }) {
    return PlayerState(
      videoId: videoId ?? this.videoId,
      selectedQuality: selectedQuality ?? this.selectedQuality,
      isInitializing: isInitializing ?? this.isInitializing,
      isInitialized: isInitialized ?? this.isInitialized,
      isPlaying: isPlaying ?? this.isPlaying,
      wantsToPlay: wantsToPlay ?? this.wantsToPlay,
      isBuffering: isBuffering ?? this.isBuffering,
      currentPosition: currentPosition ?? this.currentPosition,
      duration: duration ?? this.duration,
      error: clearError ? null : error ?? this.error,
      isLandscapeRendering: isLandscapeRendering ?? this.isLandscapeRendering,
    );
  }
}
