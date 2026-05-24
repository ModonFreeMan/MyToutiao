import 'package:flutter/material.dart';

import '../../../data/models/feed_item.dart';
import '../../../data/models/image_feed_item.dart';
import '../../../data/models/video_feed_item.dart';

class FeedContentInfo extends StatelessWidget {
  const FeedContentInfo({required this.item, this.footer, super.key});

  final FeedItem item;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final description = switch (item) {
      VideoFeedItem(:final description) => description,
      ImageFeedItem(:final description) => description,
      _ => '',
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 310),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AuthorAvatar(url: item.author.avatarUrl),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '@${item.author.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    shadows: [Shadow(blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.25,
              shadows: [Shadow(blurRadius: 10)],
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
                shadows: [Shadow(blurRadius: 8)],
              ),
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.network(
        url,
        width: 32,
        height: 32,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const ColoredBox(
            color: Colors.white24,
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(Icons.person, color: Colors.white70, size: 18),
            ),
          );
        },
      ),
    );
  }
}
