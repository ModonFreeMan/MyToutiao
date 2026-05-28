import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../data/models/video_feed_item.dart';
import '../controllers/player_controller.dart';

class VideoPlayerView extends ConsumerWidget {
  const VideoPlayerView({required this.item, super.key});

  final VideoFeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final playerController = ref.read(playerControllerProvider.notifier);
    final controller = playerState.videoId == item.id
        ? playerController.videoController
        : null;
    final shouldHideTexture =
        playerState.isLandscapeRendering && playerState.videoId == item.id;

    if (controller == null || !playerState.isInitialized || shouldHideTexture) {
      return Image.network(
        item.coverUrl,
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
}
