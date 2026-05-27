import 'package:flutter/material.dart';

import '../../../data/models/image_feed_item.dart';
import 'feed_content_info.dart';
import 'related_search_entry.dart';
import 'right_action_bar.dart';

class ImageFeedCard extends StatefulWidget {
  const ImageFeedCard({required this.item, super.key});

  final ImageFeedItem item;

  @override
  State<ImageFeedCard> createState() => _ImageFeedCardState();
}

class _ImageFeedCardState extends State<ImageFeedCard> {
  late final PageController _pageController;
  int _currentImageIndex = 0;

  ImageFeedItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didUpdateWidget(covariant ImageFeedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _currentImageIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = item.imageUrls;
    final hasMultipleImages = imageUrls.length > 1;

    return ColoredBox(
      color: Colors.black,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  key: const ValueKey('image-feed-carousel'),
                  controller: _pageController,
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return _FeedImageView(imageUrl: imageUrls[index]);
                  },
                ),
                IgnorePointer(
                  child: DecoratedBox(
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
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 16,
                  left: 16,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.36),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        hasMultipleImages
                            ? '图文 ${_currentImageIndex + 1}/${imageUrls.length}'
                            : '图片',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                if (hasMultipleImages)
                  Positioned(
                    left: 40,
                    right: 112,
                    bottom: 148,
                    child: _ImagePageIndicator(
                      currentIndex: _currentImageIndex,
                      count: imageUrls.length,
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

class _FeedImageView extends StatelessWidget {
  const _FeedImageView({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
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
          child: Center(child: Icon(Icons.broken_image, color: Colors.white54)),
        );
      },
    );
  }
}

class _ImagePageIndicator extends StatelessWidget {
  const _ImagePageIndicator({required this.currentIndex, required this.count});

  final int currentIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;

        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 3,
            margin: EdgeInsets.only(right: index == count - 1 ? 0 : 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isActive ? 0.95 : 0.32),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}
