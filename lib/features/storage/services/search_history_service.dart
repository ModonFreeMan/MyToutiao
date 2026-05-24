import 'storage_service.dart';

class SearchHistoryService {
  const SearchHistoryService({required this.storageService});

  static const String _storageKey = 'search_history_keywords';
  static const int _maxHistoryCount = 20;

  final StorageService storageService;

  Future<List<String>> getHistories() {
    return storageService.getStringList(_storageKey);
  }

  Future<List<String>> saveKeyword(String keyword) async {
    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) {
      return getHistories();
    }

    final histories = await getHistories();
    final nextHistories = <String>[
      trimmedKeyword,
      ...histories.where((history) => history != trimmedKeyword),
    ];

    final limitedHistories = nextHistories.take(_maxHistoryCount).toList();
    await storageService.setStringList(_storageKey, limitedHistories);

    return limitedHistories;
  }

  Future<void> clearHistories() {
    return storageService.remove(_storageKey);
  }
}
