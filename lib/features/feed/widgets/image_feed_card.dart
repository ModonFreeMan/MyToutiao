import 'package:flutter/material.dart';

import '../../../data/models/image_feed_item.dart';
import 'feed_content_info.dart';
import 'related_search_entry.dart';
import 'right_action_bar.dart';

class ImageFeedCard extends StatelessWidget {
  const ImageFeedCard({required this.item, super.key});

  final ImageFeedItem item;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  item.imageUrl,
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
                        child: Icon(Icons.broken_image, color: Colors.white54),
                      ),
                    );
                  },
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0, 0.48, 1],
                    ),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 16,
                  left: 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '图片',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 88,
                  bottom: 28,
                  child: FeedContentInfo(item: item),
                ),
                Positioned(
                  right: 14,
                  bottom: 34,
                  child: RightActionBar(statistics: item.statistics),
                ),
              ],
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
