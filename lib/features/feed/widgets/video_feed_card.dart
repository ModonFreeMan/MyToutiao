import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/video_feed_item.dart';
import '../../player/controllers/player_controller.dart';
import '../../player/widgets/player_progress_bar.dart';
import '../../player/widgets/quality_switch_button.dart';
import '../../player/widgets/video_player_view.dart';
import 'feed_content_info.dart';
import 'related_search_entry.dart';
import 'right_action_bar.dart';

class VideoFeedCard extends ConsumerWidget {
  const VideoFeedCard({required this.item, required this.isActive, super.key});

  final VideoFeedItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final isCurrentVideo = playerState.videoId == item.id;
    final isLoadingVideo =
        isCurrentVideo &&
        (playerState.isInitializing ||
            (playerState.isInitialized && playerState.isBuffering)) &&
        playerState.error == null;
    final showPlayButton =
        !isLoadingVideo &&
        (!isCurrentVideo ||
            !playerState.isInitialized ||
            !playerState.isPlaying);

    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final playerController = ref.read(
                  playerControllerProvider.notifier,
                );
                if (isLoadingVideo) {
                  return;
                }

                if (!isCurrentVideo || !playerState.isInitialized) {
                  playerController.playVideo(item, forceRestart: true);
                  return;
                }

                playerController.togglePlayPause();
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayerView(item: item),
                  const _BottomScrim(),
                  if (isLoadingVideo) const Center(child: _VideoLoadingView()),
                  if (isCurrentVideo && playerState.error != null)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.52),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Text(
                              '视频加载失败，点击重试',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (showPlayButton)
                    Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.34),
                          shape: BoxShape.circle,
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(18),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 58,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 16,
                    left: 16,
                    child: _TypeBadge(
                      label: '视频 ${_formatDuration(item.duration)}',
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 16,
                    right: 16,
                    child: QualitySwitchButton(item: item),
                  ),
                  Positioned(
                    left: 16,
                    right: 88,
                    bottom: 40,
                    child: FeedContentInfo(item: item),
                  ),
                  Positioned(
                    right: 14,
                    bottom: 46,
                    child: RightActionBar(statistics: item.statistics),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: PlayerProgressBar(videoId: item.id),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: RelatedSearchEntry(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.10),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.74),
          ],
          stops: const [0, 0.48, 1],
        ),
      ),
    );
  }
}

class _VideoLoadingView extends StatelessWidget {
  const _VideoLoadingView();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
