import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/player_controller.dart';

class PlayerProgressBar extends ConsumerWidget {
  const PlayerProgressBar({required this.videoId, super.key});

  final String videoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final playerController = ref.read(playerControllerProvider.notifier);
    final isCurrentVideo = playerState.videoId == videoId;
    final duration = playerState.duration;
    final progress = !isCurrentVideo || duration == Duration.zero
        ? 0.0
        : playerState.currentPosition.inMilliseconds / duration.inMilliseconds;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white30,
        thumbColor: Colors.white,
        overlayColor: Colors.white24,
      ),
      child: Slider(
        min: 0,
        max: 1,
        value: progress.clamp(0, 1),
        onChanged: isCurrentVideo && playerState.isInitialized
            ? playerController.seekToProgress
            : null,
      ),
    );
  }
}
