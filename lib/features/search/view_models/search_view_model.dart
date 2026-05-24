import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../storage/providers/storage_provider.dart';
import '../../storage/services/search_history_service.dart';
import '../states/search_state.dart';

final searchViewModelProvider = NotifierProvider<SearchViewModel, SearchState>(
  SearchViewModel.new,
);

class SearchViewModel extends Notifier<SearchState> {
  late final SearchHistoryService _historyService = ref.watch(
    searchHistoryServiceProvider,
  );

  @override
  SearchState build() {
    Future<void>.microtask(loadHistories);
    return const SearchState.initial();
  }

  Future<void> loadHistories() async {
    if (state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final histories = await _historyService.getHistories();
      state = state.copyWith(
        histories: histories,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  void updateKeyword(String keyword) {
    state = state.copyWith(keyword: keyword, clearError: true);
  }

  Future<void> submitSearch(String keyword) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty || state.isSearching) {
      return;
    }

    state = state.copyWith(
      keyword: trimmedKeyword,
      isSearching: true,
      clearError: true,
    );

    try {
      final histories = await _historyService.saveKeyword(trimmedKeyword);
      state = state.copyWith(
        histories: histories,
        isSearching: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isSearching: false, error: error.toString());
    }
  }

  Future<void> clearHistories() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _historyService.clearHistories();
      state = state.copyWith(
        histories: const <String>[],
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }
}
