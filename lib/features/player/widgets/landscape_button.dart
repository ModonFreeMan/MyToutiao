import 'package:flutter/material.dart';

class LandscapeButton extends StatelessWidget {
  const LandscapeButton({
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      tooltip: '横屏播放',
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.36),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.black.withValues(alpha: 0.18),
        disabledForegroundColor: Colors.white38,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: enabled ? onPressed : null,
      icon: const Icon(Icons.screen_rotation_rounded, size: 22),
    );
  }
}
