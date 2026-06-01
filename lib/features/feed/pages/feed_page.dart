import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/route_constants.dart';
import '../../../data/models/feed_item.dart';
import '../../../data/models/image_feed_item.dart';
import '../../../data/models/video_feed_item.dart';
import '../../observability/providers/observability_provider.dart';
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
  static const double _tapMoveTolerance = 18;

  late final PageController _pageController;
  int? _pointer;
  Offset? _downPosition;

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
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  _pointer = event.pointer;
                  _downPosition = event.position;
                },
                onPointerCancel: (event) {
                  if (_pointer == event.pointer) {
                    _clearPointer();
                  }
                },
                onPointerUp: (event) {
                  if (_pointer != event.pointer) {
                    return;
                  }

                  final downPosition = _downPosition;
                  _clearPointer();
                  if (downPosition == null ||
                      (event.position - downPosition).distance >
                          _tapMoveTolerance ||
                      !_isCentralVideoTap(context, event.position)) {
                    return;
                  }

                  final item = _currentItem(
                    feedState.items,
                    feedState.currentIndex,
                  );
                  if (item case final VideoFeedItem videoItem) {
                    ref
                        .read(feedPlaybackCoordinatorProvider)
                        .handleVideoCardTapped(videoItem, isActive: true);
                  }
                },
                child: RefreshIndicator(
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
              ),
              const _FeedSearchEntry(),
              if (kDebugMode) const _FeedDebugReportEntry(),
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

  bool _isCentralVideoTap(BuildContext context, Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return false;
    }

    final localPosition = box.globalToLocal(globalPosition);
    final height = box.size.height;
    return localPosition.dy >= 96 && localPosition.dy <= height - 132;
  }

  void _clearPointer() {
    _pointer = null;
    _downPosition = null;
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
                await playbackCoordinator.handleFeedCovered();

                if (!context.mounted) {
                  return;
                }

                await Navigator.of(context).pushNamed(RouteConstants.search);

                if (!context.mounted) {
                  return;
                }

                await playbackCoordinator.handleFeedUncovered();
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

class _FeedDebugReportEntry extends ConsumerWidget {
  const _FeedDebugReportEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 12, 0),
          child: IconButton.filledTonal(
            tooltip: '复制播放指标报告',
            onPressed: () async {
              final buildReport = ref.read(playbackStartupDebugReportProvider);
              final report = buildReport();
              if (report == null) {
                return;
              }

              const encoder = JsonEncoder.withIndent('  ');
              await Clipboard.setData(
                ClipboardData(text: encoder.convert(report)),
              );
              if (!context.mounted) {
                return;
              }

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('播放指标报告已复制')));
            },
            icon: const Icon(Icons.content_copy_rounded),
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
