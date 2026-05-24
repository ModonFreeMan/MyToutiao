import 'package:flutter/material.dart';

class SearchHistoryList extends StatelessWidget {
  const SearchHistoryList({
    super.key,
    required this.histories,
    required this.onHistoryTap,
    required this.onClear,
  });

  final List<String> histories;
  final ValueChanged<String> onHistoryTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (histories.isEmpty) {
      return Center(
        child: Text(
          '暂无搜索历史',
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Text('搜索历史', style: textTheme.titleMedium),
            const Spacer(),
            IconButton(
              tooltip: '清空历史',
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final history in histories)
              ActionChip(
                label: Text(history),
                avatar: const Icon(Icons.history, size: 18),
                onPressed: () => onHistoryTap(history),
              ),
          ],
        ),
      ],
    );
  }
}
