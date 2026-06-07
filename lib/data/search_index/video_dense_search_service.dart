import 'search_embedding_service.dart';
import 'search_vector_store.dart';

class VideoDenseSearchService {
  const VideoDenseSearchService({
    required this.embeddingService,
    required this.vectorStore,
  });

  final SearchEmbeddingService embeddingService;
  final SearchVectorStore vectorStore;

  Future<List<SearchVectorResult>> search(
    String query, {
    int limit = 10,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const <SearchVectorResult>[];
    }

    final queryEmbedding = await embeddingService.embed(normalizedQuery);
    return vectorStore.searchSummaryEmbedding(
      queryEmbedding: queryEmbedding,
      limit: limit,
    );
  }
}
