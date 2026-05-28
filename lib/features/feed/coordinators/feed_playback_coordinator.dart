import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/feed_item.dart';
import '../../../data/models/video_feed_item.dart';
import '../../player/controllers/player_controller.dart';
import '../view_models/feed_view_model.dart';

final feedPlaybackCoordinatorProvider = Provider<FeedPlaybackCoordinator>(
  FeedPlaybackCoordinator.new,
);

class FeedPlaybackCoordinator {
  FeedPlaybackCoordinator(this._ref);

  final Ref _ref;
  bool _shouldResumeWhenFeedVisible = false;

  Future<void> handleFeedCurrentChanged(int index) async {
    final feedState = _ref.read(feedViewModelProvider);
    final item = _itemAt(feedState.items, index);
    final playerController = _ref.read(playerControllerProvider.notifier);

    if (item case final VideoFeedItem videoItem) {
      await playerController.playVideo(videoItem);
    } else {
      await playerController.stop();
    }
  }

  Future<bool> handleSearchResultSelected(VideoFeedItem item) async {
    final didFocus = await _ref
        .read(feedViewModelProvider.notifier)
        .focusItemById(item.id);

    if (didFocus) {
      unawaited(_ref.read(playerControllerProvider.notifier).playVideo(item));
    }

    return didFocus;
  }

  Future<void> handleVideoCardTapped(VideoFeedItem item) async {
    final playerState = _ref.read(playerControllerProvider);
    final playerController = _ref.read(playerControllerProvider.notifier);
    final isCurrentVideo = playerState.videoId == item.id;
    final isLoadingVideo =
        isCurrentVideo &&
        (playerState.isInitializing ||
            (playerState.isInitialized && playerState.isBuffering)) &&
        playerState.error == null;

    if (isLoadingVideo) {
      return;
    }

    if (!isCurrentVideo || !playerState.isInitialized) {
      await playerController.playVideo(item, forceRestart: true);
      return;
    }

    await playerController.togglePlayPause();
  }

  Future<void> handleLandscapeRequested(VideoFeedItem item) async {
    final playerState = _ref.read(playerControllerProvider);
    final playerController = _ref.read(playerControllerProvider.notifier);
    final isCurrentVideo = playerState.videoId == item.id;

    if (!isCurrentVideo || !playerState.isInitialized) {
      await playerController.playVideo(item, forceRestart: true);
    } else if (!playerState.isPlaying) {
      await playerController.resume();
    }

    playerController.setLandscapeRendering(true);
  }

  void handleLandscapeClosed() {
    _ref.read(playerControllerProvider.notifier).setLandscapeRendering(false);
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
}
