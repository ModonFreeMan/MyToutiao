import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/route_constants.dart';
import '../../../data/models/video_feed_item.dart';
import '../../../data/repositories/search_repository.dart';
import '../../feed/view_models/feed_view_model.dart';
import '../../player/controllers/player_controller.dart';
import '../view_models/search_view_model.dart';
import '../widgets/search_input_bar.dart';
import '../widgets/search_video_result_item.dart';

final searchResultsProvider = FutureProvider.autoDispose
    .family<List<VideoFeedItem>, String>((ref, keyword) {
      return ref.watch(searchRepositoryProvider).searchVideos(keyword);
    });

class SearchResultPage extends ConsumerStatefulWidget {
  const SearchResultPage({super.key});

  @override
  ConsumerState<SearchResultPage> createState() => _SearchResultPageState();
}

class _SearchResultPageState extends ConsumerState<SearchResultPage> {
  late final TextEditingController _controller;
  String? _keyword;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_keyword != null) {
      return;
    }

    final routeKeyword = ModalRoute.of(context)?.settings.arguments;
    _keyword = routeKeyword is String ? routeKeyword.trim() : '';
    _controller.text = _keyword ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitSearch(String keyword) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      return;
    }

    await ref
        .read(searchViewModelProvider.notifier)
        .submitSearch(trimmedKeyword);

    if (!mounted) {
      return;
    }

    setState(() {
      _keyword = trimmedKeyword;
      _controller.text = trimmedKeyword;
      _controller.selection = TextSelection.collapsed(
        offset: trimmedKeyword.length,
      );
    });
  }

  Future<void> _openFeedVideo(VideoFeedItem item) async {
    final didFocus = await ref
        .read(feedViewModelProvider.notifier)
        .focusItemById(item.id);
    if (didFocus) {
      unawaited(ref.read(playerControllerProvider.notifier).playVideo(item));
    }

    if (!mounted) {
      return;
    }

    Navigator.of(
      context,
    ).popUntil((route) => route.settings.name == RouteConstants.feed);
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _keyword ?? '';
    final results = ref.watch(searchResultsProvider(keyword));
    final searchState = ref.watch(searchViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '返回',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: SearchInputBar(
          controller: _controller,
          isSearching: searchState.isSearching,
          onChanged: ref.read(searchViewModelProvider.notifier).updateKeyword,
          onSubmitted: _submitSearch,
        ),
        actions: const [SizedBox(width: 12)],
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        data: (items) {
          if (keyword.isEmpty) {
            return const Center(child: Text('请输入搜索词'));
          }

          if (items.isEmpty) {
            return Center(child: Text('没有找到“$keyword”相关视频'));
          }

          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return SearchVideoResultItem(
                item: item,
                onTap: () => _openFeedVideo(item),
              );
            },
          );
        },
      ),
    );
  }
}
