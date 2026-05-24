import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../data/models/statistics.dart';

class RightActionBar extends StatelessWidget {
  const RightActionBar({required this.statistics, super.key});

  final Statistics statistics;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.favorite,
          label: FormatUtils.compactCount(statistics.likeCount),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.mode_comment,
          label: FormatUtils.compactCount(statistics.commentCount),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.star,
          label: FormatUtils.compactCount(statistics.favoriteCount),
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.share,
          label: FormatUtils.compactCount(statistics.shareCount),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 32,
            shadows: const [Shadow(blurRadius: 8)],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(blurRadius: 8)],
            ),
          ),
        ],
      ),
    );
  }
}
