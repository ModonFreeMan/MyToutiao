import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../data/models/video_feed_item.dart';

class SearchVideoResultItem extends StatelessWidget {
  const SearchVideoResultItem({
    super.key,
    required this.item,
    required this.onTap,
  });

  final VideoFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.coverUrl,
                width: 124,
                height: 76,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: colorScheme.surfaceContainerHighest,
                    child: const SizedBox(
                      width: 124,
                      height: 76,
                      child: Icon(Icons.play_circle_outline),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 76,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '@${item.author.name} · ${FormatUtils.compactCount(item.statistics.likeCount)}赞',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
