class SearchState {
  const SearchState({
    required this.keyword,
    required this.histories,
    required this.isLoading,
    required this.isSearching,
    required this.error,
  });

  const SearchState.initial()
    : keyword = '',
      histories = const <String>[],
      isLoading = false,
      isSearching = false,
      error = null;

  final String keyword;
  final List<String> histories;
  final bool isLoading;
  final bool isSearching;
  final String? error;

  SearchState copyWith({
    String? keyword,
    List<String>? histories,
    bool? isLoading,
    bool? isSearching,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      keyword: keyword ?? this.keyword,
      histories: histories ?? this.histories,
      isLoading: isLoading ?? this.isLoading,
      isSearching: isSearching ?? this.isSearching,
      error: clearError ? null : error ?? this.error,
    );
  }
}
