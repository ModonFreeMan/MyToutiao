import '../../../data/models/feed_item.dart';

class FeedState {
  const FeedState({
    required this.items,
    required this.currentIndex,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.currentPage,
    required this.error,
  });

  const FeedState.initial()
    : items = const <FeedItem>[],
      currentIndex = 0,
      isLoading = false,
      isLoadingMore = false,
      hasMore = true,
      currentPage = 0,
      error = null;

  final List<FeedItem> items;
  final int currentIndex;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? error;

  FeedState copyWith({
    List<FeedItem>? items,
    int? currentIndex,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? error,
    bool clearError = false,
  }) {
    return FeedState(
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: clearError ? null : error ?? this.error,
    );
  }
}
