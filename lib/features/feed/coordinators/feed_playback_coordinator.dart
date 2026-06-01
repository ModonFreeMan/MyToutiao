import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/feed_item.dart';
import '../../../data/models/video_feed_item.dart';
import '../../observability/providers/observability_provider.dart';
import '../../player/controllers/player_controller.dart';
import '../providers/feed_preload_config_provider.dart';
import '../view_models/feed_view_model.dart';

final feedPlaybackCoordinatorProvider = Provider<FeedPlaybackCoordinator>(
  FeedPlaybackCoordinator.new,
);

enum FeedScrollDirection { unknown, forward, backward }

class FeedPlaybackCoordinator {
  FeedPlaybackCoordinator(this._ref) {
    _ref.onDispose(dispose);
  }

  static const Duration _autoplayGracePeriod = Duration(milliseconds: 180);
  static const Duration _autoplaySettleProtection = Duration(seconds: 2);
  static const Duration _preloadScheduleDelay = Duration(milliseconds: 120);

  final Ref _ref;
  bool _shouldResumeWhenFeedVisible = false;
  String? _suppressedAutoplayVideoId;
  String? _settlingAutoplayVideoId;
  DateTime? _settlingAutoplayExpiresAt;
  int _feedPlaybackToken = 0;
  int? _lastCurrentIndex;
  FeedScrollDirection _lastScrollDirection = FeedScrollDirection.unknown;
  List<String> _lastFeedItemIds = const <String>[];
  Timer? _pendingPreloadTimer;
  int _preloadScheduleToken = 0;
  bool _isDisposed = false;

  void _resetScrollDirection() {
    _lastCurrentIndex = null;
    _lastScrollDirection = FeedScrollDirection.unknown;
  }

  Future<void> handleFeedCurrentChanged(int index) async {
    final token = ++_feedPlaybackToken;
    var didRequestDisposePreload = false;
    final feedState = _ref.read(feedViewModelProvider);
    final didReplaceFeedItems = _resetScrollDirectionIfFeedItemsReplaced(
      feedState.items,
    );
    if (didReplaceFeedItems) {
      _cancelPendingPreloadSchedule();
      unawaited(_ref.read(playerControllerProvider.notifier).disposePreload());
      didRequestDisposePreload = true;
    }
    final direction = _updateScrollDirection(index);
    final item = _itemAt(feedState.items, index);
    final preloadEnabled = _ref.read(feedPreloadEnabledProvider);
    final preloadCandidate = preloadEnabled
        ? _preloadCandidate(feedState.items, index, direction: direction)
        : null;
    final playerController = _ref.read(playerControllerProvider.notifier);
    _cancelPendingPreloadSchedule();
    if (preloadCandidate == null && !didRequestDisposePreload) {
      unawaited(playerController.disposePreload());
      didRequestDisposePreload = true;
    }
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
        if (preloadCandidate != null) {
          _schedulePreload(preloadCandidate);
        }
        return;
      }

      _suppressedAutoplayVideoId = null;
      await playerController.playVideo(
        videoItem,
        startupSession: startupSession,
      );
      if (preloadCandidate != null) {
        _schedulePreload(preloadCandidate);
      }
    } else {
      startupMetrics.closeActiveSession();
      _settlingAutoplayVideoId = null;
      _settlingAutoplayExpiresAt = null;
      _suppressedAutoplayVideoId = null;
      await playerController.stop();
      if (preloadCandidate != null) {
        _schedulePreload(preloadCandidate);
      }
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

  bool _resetScrollDirectionIfFeedItemsReplaced(List<FeedItem> items) {
    final itemIds = items.map((item) => item.id).toList(growable: false);
    if (_isSameFeedItemPrefix(_lastFeedItemIds, itemIds)) {
      _lastFeedItemIds = itemIds;
      return false;
    }

    _lastFeedItemIds = itemIds;
    _resetScrollDirection();
    return true;
  }

  bool _isSameFeedItemPrefix(List<String> previous, List<String> next) {
    if (previous.isEmpty) {
      return true;
    }

    if (next.length < previous.length) {
      return false;
    }

    for (var index = 0; index < previous.length; index++) {
      if (previous[index] != next[index]) {
        return false;
      }
    }

    return true;
  }

  FeedScrollDirection _updateScrollDirection(int currentIndex) {
    final lastCurrentIndex = _lastCurrentIndex;
    _lastCurrentIndex = currentIndex;

    if (lastCurrentIndex == null) {
      _lastScrollDirection = FeedScrollDirection.unknown;
      return _lastScrollDirection;
    }

    if (currentIndex > lastCurrentIndex) {
      _lastScrollDirection = FeedScrollDirection.forward;
    } else if (currentIndex < lastCurrentIndex) {
      _lastScrollDirection = FeedScrollDirection.backward;
    }

    return _lastScrollDirection;
  }

  VideoFeedItem? _preloadCandidate(
    List<FeedItem> items,
    int currentIndex, {
    required FeedScrollDirection direction,
  }) {
    return switch (direction) {
      FeedScrollDirection.forward =>
        _nextVideoAfter(items, currentIndex) ??
            _nextVideoBefore(items, currentIndex),
      FeedScrollDirection.backward =>
        _nextVideoBefore(items, currentIndex) ??
            _nextVideoAfter(items, currentIndex),
      FeedScrollDirection.unknown => _nextVideoAfter(items, currentIndex),
    };
  }

  VideoFeedItem? _nextVideoAfter(List<FeedItem> items, int currentIndex) {
    final startIndex = currentIndex < -1 ? 0 : currentIndex + 1;
    for (var index = startIndex; index < items.length; index++) {
      final item = items[index];
      if (item case final VideoFeedItem videoItem) {
        return videoItem;
      }
    }

    return null;
  }

  VideoFeedItem? _nextVideoBefore(List<FeedItem> items, int currentIndex) {
    final startIndex = currentIndex > items.length
        ? items.length - 1
        : currentIndex - 1;
    for (var index = startIndex; index >= 0; index--) {
      final item = items[index];
      if (item case final VideoFeedItem videoItem) {
        return videoItem;
      }
    }

    return null;
  }

  void _schedulePreload(VideoFeedItem candidate) {
    if (_isDisposed) {
      return;
    }

    final playerController = _ref.read(playerControllerProvider.notifier);
    _cancelPendingPreloadSchedule();
    final token = _preloadScheduleToken;
    late final Timer timer;
    timer = Timer(_preloadScheduleDelay, () {
      if (identical(_pendingPreloadTimer, timer)) {
        _pendingPreloadTimer = null;
      }

      if (_isDisposed || token != _preloadScheduleToken) {
        return;
      }

      unawaited(playerController.preloadVideo(candidate));
    });
    _pendingPreloadTimer = timer;
  }

  void _cancelPendingPreloadSchedule() {
    _preloadScheduleToken++;
    _pendingPreloadTimer?.cancel();
    _pendingPreloadTimer = null;
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

  void dispose() {
    _isDisposed = true;
    _cancelPendingPreloadSchedule();
  }
}
