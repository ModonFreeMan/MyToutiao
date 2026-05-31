import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../data/models/video_feed_item.dart';
import '../../observability/providers/observability_provider.dart';
import '../controllers/player_controller.dart';
import '../states/player_state.dart';

class VideoPlayerView extends ConsumerStatefulWidget {
  const VideoPlayerView({required this.item, super.key});

  final VideoFeedItem item;

  @override
  ConsumerState<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends ConsumerState<VideoPlayerView> {
  bool _isPlaybackIntentResumeScheduled = false;
  int? _scheduledFirstFrameSessionId;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerControllerProvider);
    final playerController = ref.read(playerControllerProvider.notifier);
    ref.listen<PlayerState>(playerControllerProvider, (_, next) {
      _resumeIfPlaybackIntentRequiresIt(next);
    });
    _resumeIfPlaybackIntentRequiresIt(playerState);

    final controller = playerState.videoId == widget.item.id
        ? playerController.videoController
        : null;
    final shouldHideTexture =
        playerState.isLandscapeRendering &&
        playerState.videoId == widget.item.id;

    if (controller == null || !playerState.isInitialized || shouldHideTexture) {
      return Image.network(
        widget.item.coverUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }

          return const Center(child: CircularProgressIndicator());
        },
        errorBuilder: (context, error, stackTrace) {
          return const ColoredBox(
            color: Color(0xFF202124),
            child: Center(
              child: Icon(Icons.image_not_supported, color: Colors.white54),
            ),
          );
        },
      );
    }

    final startupSession = playerController.startupSession;
    if (playerState.videoId == widget.item.id &&
        playerState.isInitialized &&
        !playerState.isLandscapeRendering &&
        startupSession != null &&
        _scheduledFirstFrameSessionId != startupSession.sessionId) {
      _scheduledFirstFrameSessionId = startupSession.sessionId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref
            .read(playbackStartupMetricsProvider)
            .markFirstFrameRendered(startupSession);
      });
    }

    final size = controller.value.size;

    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }

  void _resumeIfPlaybackIntentRequiresIt(PlayerState playerState) {
    if (_isPlaybackIntentResumeScheduled ||
        playerState.videoId != widget.item.id ||
        playerState.isLandscapeRendering ||
        !playerState.isInitialized ||
        playerState.isPlaying ||
        !playerState.wantsToPlay) {
      return;
    }

    _isPlaybackIntentResumeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _isPlaybackIntentResumeScheduled = false;
      if (!mounted) {
        return;
      }

      await ref
          .read(playerControllerProvider.notifier)
          .ensurePlaybackIntent(widget.item.id);
    });
  }
}
