import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/route_constants.dart';
import '../../../data/models/feed_item.dart';
import '../../player/controllers/player_controller.dart';
import '../../recommendation/providers/recommendation_provider.dart';
import '../../search/view_models/search_view_model.dart';

class RelatedSearchEntry extends ConsumerWidget {
  const RelatedSearchEntry({required this.item, super.key});

  final FeedItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recommendationWords = ref.watch(recommendationWordsProvider(item));

    return recommendationWords.when(
      data: (words) {
        if (words.isEmpty) {
          return const SizedBox.shrink();
        }

        return _RelatedSearchView(
          words: words,
          onWordTap: (word) async {
            final wasPlaying = ref.read(playerControllerProvider).isPlaying;
            final playerController = ref.read(
              playerControllerProvider.notifier,
            );
            await playerController.pause();
            await ref.read(searchViewModelProvider.notifier).submitSearch(word);

            if (!context.mounted) {
              return;
            }

            await Navigator.of(
              context,
            ).pushNamed(RouteConstants.searchResult, arguments: word);

            if (!context.mounted) {
              return;
            }

            if (wasPlaying) {
              await playerController.resume();
            }
          },
        );
      },
      error: (error, stackTrace) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}

class _RelatedSearchView extends StatelessWidget {
  const _RelatedSearchView({required this.words, required this.onWordTap});

  final List<String> words;
  final ValueChanged<String> onWordTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.30),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white70, size: 15),
            const SizedBox(width: 5),
            const Text(
              '相关搜索',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final word in words.take(4)) ...[
                      _RelatedWordChip(
                        word: word,
                        onTap: () => onWordTap(word),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RelatedWordChip extends StatelessWidget {
  const _RelatedWordChip({required this.word, required this.onTap});

  final String word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          word,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
