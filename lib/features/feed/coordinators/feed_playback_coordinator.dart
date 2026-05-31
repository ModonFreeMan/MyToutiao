import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/feed_item.dart';
import '../../../data/models/video_feed_item.dart';
import '../../observability/providers/observability_provider.dart';
import '../../player/controllers/player_controller.dart';
import '../view_models/feed_view_model.dart';

final feedPlaybackCoordinatorProvider = Provider<FeedPlaybackCoordinator>(
  FeedPlaybackCoordinator.new,
);

class FeedPlaybackCoordinator {
  FeedPlaybackCoordinator(this._ref);

  static const Duration _autoplayGracePeriod = Duration(milliseconds: 180);
  static const Duration _autoplaySettleProtection = Duration(seconds: 2);

  final Ref _ref;
  bool _shouldResumeWhenFeedVisible = false;
  String? _suppressedAutoplayVideoId;
  String? _settlingAutoplayVideoId;
  DateTime? _settlingAutoplayExpiresAt;
  int _feedPlaybackToken = 0;

  Future<void> handleFeedCurrentChanged(int index) async {
    final token = ++_feedPlaybackToken;
    final feedState = _ref.read(feedViewModelProvider);
    final item = _itemAt(feedState.items, index);
    final playerController = _ref.read(playerControllerProvider.notifier);
    final startupMetrics = _ref.read(playbackStartupMetricsProvider);

    if (item case final VideoFeedItem videoItem) {
      final startupSession = startupMetrics.markFeedItemVisible(
        videoId: videoItem.id,
        feedIndex: index,
      );
      final shouldProtectSettlingAutoplay = index != 0;
      if (shouldProtectSettlingAutoplay) {
        _settlingAutoplayVideoId = videoItem.id;
        _settlingAutoplayExpiresAt = DateTime.now().add(
          _autoplayGracePeriod + _autoplaySettleProtection,
        );
      }
      await Future<void>.delayed(_autoplayGracePeriod);
      if (token != _feedPlaybackToken) {
        return;
      }

      if (_suppressedAutoplayVideoId == videoItem.id) {
        _settlingAutoplayVideoId = null;
        _settlingAutoplayExpiresAt = null;
        startupMetrics.markSessionClosed(startupSession);
        await playerController.stopIfCurrent(videoItem.id);
        return;
      }

      _suppressedAutoplayVideoId = null;
      await playerController.playVideo(
        videoItem,
        startupSession: startupSession,
      );
    } else {
      startupMetrics.closeActiveSession();
      _settlingAutoplayVideoId = null;
      _settlingAutoplayExpiresAt = null;
      _suppressedAutoplayVideoId = null;
      await playerController.stop();
    }
  }

  Future<bool> handleSearchResultSelected(VideoFeedItem item) async {
    final didFocus = await _ref
        .read(feedViewModelProvider.notifier)
        .focusItemById(item.id);

    if (didFocus) {
      _suppressedAutoplayVideoId = null;
      unawaited(_ref.read(playerControllerProvider.notifier).playVideo(item));
    }

    return didFocus;
  }

  Future<void> handleVideoCardTapped(
    VideoFeedItem item, {
    bool isActive = false,
  }) async {
    final playerState = _ref.read(playerControllerProvider);
    final playerController = _ref.read(playerControllerProvider.notifier);
    final isCurrentVideo = playerState.videoId == item.id;
    final isVisibleCurrentItem = isActive || _isVisibleCurrentItem(item);
    final isLoadingVideo =
        isCurrentVideo &&
        (playerState.isInitializing ||
            (playerState.isInitialized && playerState.isBuffering)) &&
        playerState.error == null;

    if (isCurrentVideo && playerState.isInitialized && playerState.isPlaying) {
      ++_feedPlaybackToken;
      _suppressedAutoplayVideoId = item.id;
      _settlingAutoplayVideoId = null;
      _settlingAutoplayExpiresAt = null;
      await playerController.togglePlayPause();
      return;
    }

    if (isCurrentVideo && playerState.isInitializing) {
      ++_feedPlaybackToken;
      _suppressedAutoplayVideoId = item.id;
      _settlingAutoplayVideoId = null;
      _settlingAutoplayExpiresAt = null;
      await playerController.stopIfCurrent(item.id);
      return;
    }

    if (isCurrentVideo &&
        !playerState.isPlaying &&
        _isSettlingAutoplay(item.id)) {
      ++_feedPlaybackToken;
      _suppressedAutoplayVideoId = item.id;
      _settlingAutoplayVideoId = null;
      _settlingAutoplayExpiresAt = null;
      await playerController.stopIfCurrent(item.id);
      return;
    }

    if (isVisibleCurrentItem && !isCurrentVideo) {
      if (_suppressedAutoplayVideoId == item.id) {
        _suppressedAutoplayVideoId = null;
        await playerController.playVideo(item, forceRestart: true);
        return;
      }

      ++_feedPlaybackToken;
      _suppressedAutoplayVideoId = item.id;
      _settlingAutoplayVideoId = null;
      _settlingAutoplayExpiresAt = null;
      await playerController.stop();
      return;
    }

    if (isLoadingVideo) {
      return;
    }

    if (!isCurrentVideo || !playerState.isInitialized) {
      ++_feedPlaybackToken;
      _suppressedAutoplayVideoId = null;
      await playerController.playVideo(item, forceRestart: true);
      return;
    }

    ++_feedPlaybackToken;
    _suppressedAutoplayVideoId = null;
    await playerController.togglePlayPause();
  }

  Future<void> handleLandscapeRequested(VideoFeedItem item) async {
    ++_feedPlaybackToken;
    _suppressedAutoplayVideoId = null;
    final playerState = _ref.read(playerControllerProvider);
    final playerController = _ref.read(playerControllerProvider.notifier);
    final isCurrentVideo = playerState.videoId == item.id;

    if (!isCurrentVideo || !playerState.isInitialized) {
      await playerController.playVideo(item, forceRestart: true);
    } else {
      await playerController.ensurePlaybackIntent(item.id);
    }

    playerController.setLandscapeRendering(true);
  }

  Future<void> handleLandscapeClosed() async {
    final playerState = _ref.read(playerControllerProvider);
    final playerController = _ref.read(playerControllerProvider.notifier);

    playerController.setLandscapeRendering(false);

    final videoId = playerState.videoId;
    if (videoId != null) {
      await playerController.ensurePlaybackIntent(videoId);
    }
  }

  Future<void> handleFeedCovered() async {
    final playerState = _ref.read(playerControllerProvider);
    _shouldResumeWhenFeedVisible = playerState.isPlaying;
    await _ref.read(playerControllerProvider.notifier).pause();
  }

  Future<void> handleFeedUncovered() async {
    if (!_shouldResumeWhenFeedVisible) {
      return;
    }

    _shouldResumeWhenFeedVisible = false;
    await _ref.read(playerControllerProvider.notifier).resume();
  }

  FeedItem? _itemAt(List<FeedItem> items, int index) {
    if (index < 0 || index >= items.length) {
      return null;
    }

    return items[index];
  }

  bool _isVisibleCurrentItem(VideoFeedItem item) {
    final feedState = _ref.read(feedViewModelProvider);
    return _itemAt(feedState.items, feedState.currentIndex)?.id == item.id;
  }

  bool _isSettlingAutoplay(String videoId) {
    if (_settlingAutoplayVideoId != videoId) {
      return false;
    }

    final expiresAt = _settlingAutoplayExpiresAt;
    if (expiresAt == null || DateTime.now().isBefore(expiresAt)) {
      return true;
    }

    _settlingAutoplayVideoId = null;
    _settlingAutoplayExpiresAt = null;
    return false;
  }
}
