import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/search_history_service.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return const StorageService();
});

final searchHistoryServiceProvider = Provider<SearchHistoryService>((ref) {
  return SearchHistoryService(
    storageService: ref.watch(storageServiceProvider),
  );
});
