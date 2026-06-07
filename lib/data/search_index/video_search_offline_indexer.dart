import 'offline_video_input.dart';
import 'search_business_store.dart';
import 'search_embedding_service.dart';
import 'search_vector_store.dart';
import 'search_video_document.dart';
import 'video_summary_generator.dart';

class VideoSearchOfflineIndexer {
  const VideoSearchOfflineIndexer({
    required this.summaryGenerator,
    required this.embeddingService,
    required this.businessStore,
    required this.vectorStore,
  });

  final VideoSummaryGenerator summaryGenerator;
  final SearchEmbeddingService embeddingService;
  final SearchBusinessStore businessStore;
  final SearchVectorStore vectorStore;

  Future<SearchVideoDocument> index(OfflineVideoInput input) async {
    // Keep the content assembly in the offline path so an AI generator can
    // consume the same input later without changing the indexer contract.
    input.toContentText();

    final generated = await summaryGenerator.generate(input);
    final document = SearchVideoDocument(
      videoId: input.videoId,
      title: input.title,
      summary: generated.summary,
      keywords: generated.keywords,
    );
    final embedding = await embeddingService.embed(generated.summary);

    await businessStore.upsert(document);
    await vectorStore.upsertSummaryEmbedding(
      videoId: input.videoId,
      summaryEmbedding: embedding,
    );

    return document;
  }
}
