import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/video_feed_item.dart';
import '../../../data/models/video_source.dart';
import '../controllers/player_controller.dart';

class QualitySwitchButton extends ConsumerWidget {
  const QualitySwitchButton({required this.item, super.key});

  final VideoFeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final playerController = ref.read(playerControllerProvider.notifier);
    final isCurrentVideo = playerState.videoId == item.id;
    final selectedQuality = isCurrentVideo
        ? playerState.selectedQuality
        : VideoQuality.p720;
    final selectedLabel = item.sourceForQuality(selectedQuality).qualityLabel;
    final sources = item.videoSources;

    return PopupMenuButton<VideoQuality>(
      tooltip: '切换清晰度',
      enabled: isCurrentVideo && !playerState.isInitializing,
      color: const Color(0xFF202124),
      elevation: 8,
      position: PopupMenuPosition.under,
      onSelected: (quality) => playerController.switchQuality(item, quality),
      itemBuilder: (context) {
        return sources.map((source) {
          final isSelected = source.quality == selectedQuality;

          return PopupMenuItem<VideoQuality>(
            value: source.quality,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.check_rounded : Icons.hd_outlined,
                  color: isSelected ? Colors.white : Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  source.qualityLabel,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.36),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hd_rounded, color: Colors.white, size: 17),
              const SizedBox(width: 5),
              Text(
                selectedLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
