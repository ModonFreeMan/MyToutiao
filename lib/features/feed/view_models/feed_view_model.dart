import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/feed_item.dart';
import '../../../data/repositories/feed_repository.dart';
import '../states/feed_state.dart';

final feedViewModelProvider = NotifierProvider<FeedViewModel, FeedState>(
  FeedViewModel.new,
);

class FeedViewModel extends Notifier<FeedState> {
  static const int _pageSize = 4;

  late final FeedRepository _repository = ref.watch(feedRepositoryProvider);

  @override
  FeedState build() {
    Future<void>.microtask(loadInitial);
    return const FeedState.initial();
  }

  Future<void> loadInitial() async {
    if (state.isLoading) {
      return;
    }

    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
    );

    try {
      final items = await _repository.fetchFeedItems(
        page: 1,
        pageSize: _pageSize,
      );
      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(
        items: items,
        currentIndex: 0,
        currentPage: 1,
        hasMore: items.length == _pageSize,
        isLoading: false,
        clearError: true,
        clearPendingFocusedIndex: true,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);

    final nextPage = state.currentPage + 1;

    try {
      final items = await _repository.fetchFeedItems(
        page: nextPage,
        pageSize: _pageSize,
      );
      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(
        items: <FeedItem>[...state.items, ...items],
        currentPage: nextPage,
        hasMore: items.length == _pageSize,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(isLoadingMore: false, error: error.toString());
    }
  }

  void setCurrentIndex(int index) {
    if (index < 0 || index >= state.items.length) {
      return;
    }

    final pendingFocusedIndex = state.pendingFocusedIndex;
    if (pendingFocusedIndex != null && index != pendingFocusedIndex) {
      return;
    }

    state = state.copyWith(
      currentIndex: index,
      clearPendingFocusedIndex: index == pendingFocusedIndex,
    );

    if (state.hasMore && index >= state.items.length - 2) {
      Future<void>.microtask(loadMore);
    }
  }

  Future<bool> focusItemById(String itemId) async {
    var index = state.items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      final pendingFocusedIndex = _pendingIndexForFocus(index);
      state = state.copyWith(
        currentIndex: index,
        pendingFocusedIndex: pendingFocusedIndex,
        clearError: true,
        clearPendingFocusedIndex: pendingFocusedIndex == null,
      );
      return true;
    }

    while (state.hasMore && !state.isLoadingMore) {
      await loadMore();
      if (!ref.mounted) {
        return false;
      }

      index = state.items.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        final pendingFocusedIndex = _pendingIndexForFocus(index);
        state = state.copyWith(
          currentIndex: index,
          pendingFocusedIndex: pendingFocusedIndex,
          clearError: true,
          clearPendingFocusedIndex: pendingFocusedIndex == null,
        );
        return true;
      }
    }

    return false;
  }

  int? _pendingIndexForFocus(int index) {
    return index == state.currentIndex ? null : index;
  }
}
