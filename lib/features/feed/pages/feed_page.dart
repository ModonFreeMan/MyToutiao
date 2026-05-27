import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/route_constants.dart';
import '../../../data/models/feed_item.dart';
import '../../../data/models/image_feed_item.dart';
import '../../../data/models/video_feed_item.dart';
import '../coordinators/feed_playback_coordinator.dart';
import '../states/feed_state.dart';
import '../view_models/feed_view_model.dart';
import '../widgets/image_feed_card.dart';
import '../widgets/video_feed_card.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedViewModelProvider);
    final feedViewModel = ref.read(feedViewModelProvider.notifier);

    ref.listen(feedViewModelProvider, (previous, next) {
      if (previous?.currentIndex != next.currentIndex) {
        _syncPageControllerToIndex(next.currentIndex);
      }

      if (_isSameCurrentItem(previous, next)) {
        return;
      }

      ref
          .read(feedPlaybackCoordinatorProvider)
          .handleFeedCurrentChanged(next.currentIndex);
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: Builder(
        builder: (context) {
          if (feedState.isLoading && feedState.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (feedState.error != null && feedState.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    feedState.error!,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: feedViewModel.loadInitial,
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          if (feedState.items.isEmpty) {
            return const Center(
              child: Text('暂无内容', style: TextStyle(color: Colors.white)),
            );
          }

          _syncPageControllerToIndex(feedState.currentIndex);

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: feedViewModel.loadInitial,
                child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  itemCount:
                      feedState.items.length +
                      (feedState.isLoadingMore ? 1 : 0),
                  onPageChanged: feedViewModel.setCurrentIndex,
                  itemBuilder: (context, index) {
                    if (index >= feedState.items.length) {
                      return const ColoredBox(
                        color: Colors.black,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    return _FeedPageItem(
                      item: feedState.items[index],
                      isActive: index == feedState.currentIndex,
                    );
                  },
                ),
              ),
              const _FeedSearchEntry(),
            ],
          );
        },
      ),
    );
  }

  void _syncPageControllerToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        return;
      }

      final page = _pageController.page?.round();
      if (page == index) {
        return;
      }

      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _FeedSearchEntry extends ConsumerWidget {
  const _FeedSearchEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(112, 8, 112, 0),
          child: Material(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(22),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () async {
                final playbackCoordinator = ref.read(
                  feedPlaybackCoordinatorProvider,
                );
                await playbackCoordinator.pauseForFeedCovered();

                if (!context.mounted) {
                  return;
                }

                await Navigator.of(context).pushNamed(RouteConstants.search);

                if (!context.mounted) {
                  return;
                }

                await playbackCoordinator.resumeAfterFeedUncovered();
              },
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '搜索你感兴趣的视频',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSameCurrentItem(FeedState? previous, FeedState next) {
  final previousItem = _currentItem(previous?.items, previous?.currentIndex);
  final nextItem = _currentItem(next.items, next.currentIndex);
  return previousItem?.id == nextItem?.id;
}

FeedItem? _currentItem(List<FeedItem>? items, int? index) {
  if (items == null || index == null || index < 0 || index >= items.length) {
    return null;
  }

  return items[index];
}

class _FeedPageItem extends StatelessWidget {
  const _FeedPageItem({required this.item, required this.isActive});

  final FeedItem item;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      VideoFeedItem() => VideoFeedCard(
        item: item as VideoFeedItem,
        isActive: isActive,
      ),
      ImageFeedItem() => ImageFeedCard(item: item as ImageFeedItem),
      _ => const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text('暂不支持的内容类型', style: TextStyle(color: Colors.white)),
        ),
      ),
    };
  }
}
