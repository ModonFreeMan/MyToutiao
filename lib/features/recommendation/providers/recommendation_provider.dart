import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/feed_item.dart';
import '../../../data/repositories/recommendation_repository.dart';
import '../services/recommendation_service.dart';

final recommendationServiceProvider = Provider<RecommendationService>((ref) {
  return RecommendationService(
    repository: ref.watch(recommendationRepositoryProvider),
  );
});

final recommendationWordsProvider =
    FutureProvider.family<List<String>, FeedItem>((ref, item) {
      return ref.watch(recommendationServiceProvider).matchWords(item);
    });
