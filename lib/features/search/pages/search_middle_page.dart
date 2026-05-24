import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/route_constants.dart';
import '../view_models/search_view_model.dart';
import '../widgets/search_history_list.dart';
import '../widgets/search_input_bar.dart';

class SearchMiddlePage extends ConsumerStatefulWidget {
  const SearchMiddlePage({super.key});

  @override
  ConsumerState<SearchMiddlePage> createState() => _SearchMiddlePageState();
}

class _SearchMiddlePageState extends ConsumerState<SearchMiddlePage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
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

    _controller.text = trimmedKeyword;
    _controller.selection = TextSelection.collapsed(
      offset: trimmedKeyword.length,
    );

    await ref
        .read(searchViewModelProvider.notifier)
        .submitSearch(trimmedKeyword);

    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).pushNamed(RouteConstants.searchResult, arguments: trimmedKeyword);
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchViewModelProvider);
    final searchViewModel = ref.read(searchViewModelProvider.notifier);

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
          autofocus: true,
          isSearching: searchState.isSearching,
          onChanged: searchViewModel.updateKeyword,
          onSubmitted: _submitSearch,
        ),
        actions: const [SizedBox(width: 12)],
      ),
      body: Builder(
        builder: (context) {
          if (searchState.isLoading && searchState.histories.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (searchState.error != null && searchState.histories.isEmpty) {
            return Center(child: Text(searchState.error!));
          }

          return SearchHistoryList(
            histories: searchState.histories,
            onHistoryTap: _submitSearch,
            onClear: searchViewModel.clearHistories,
          );
        },
      ),
    );
  }
}
