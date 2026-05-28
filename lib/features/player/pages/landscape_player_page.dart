import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../data/models/video_feed_item.dart';
import '../controllers/player_controller.dart';
import '../widgets/player_progress_bar.dart';
import '../widgets/quality_switch_button.dart';

class LandscapePlayerPage extends ConsumerStatefulWidget {
  const LandscapePlayerPage({super.key});

  @override
  ConsumerState<LandscapePlayerPage> createState() =>
      _LandscapePlayerPageState();
}

class _LandscapePlayerPageState extends ConsumerState<LandscapePlayerPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    _restorePortrait();
    ref.read(playerControllerProvider.notifier).setLandscapeRendering(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = ModalRoute.of(context)?.settings.arguments;
    if (item is! VideoFeedItem) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text('未找到视频信息', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final playerState = ref.watch(playerControllerProvider);
    final playerController = ref.read(playerControllerProvider.notifier);
    final isCurrentVideo = playerState.videoId == item.id;
    final controller = isCurrentVideo ? playerController.videoController : null;
    final showPlayButton =
        !playerState.isInitializing &&
        (!isCurrentVideo ||
            !playerState.isInitialized ||
            !playerState.isPlaying);

    return PopScope(
      onPopInvokedWithResult: (_, _) => _restorePortrait(),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (isCurrentVideo && playerState.isInitialized) {
              playerController.togglePlayPause();
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              _LandscapeVideoSurface(item: item, controller: controller),
              const _LandscapeScrim(),
              if (playerState.isInitializing)
                const Center(child: CircularProgressIndicator()),
              if (isCurrentVideo && playerState.error != null)
                const Center(
                  child: Text('视频加载失败', style: TextStyle(color: Colors.white)),
                ),
              if (showPlayButton)
                const Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 72,
                  ),
                ),
              Positioned(
                top: 14,
                left: 14,
                child: IconButton.filled(
                  tooltip: '返回',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.40),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    _restorePortrait();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: QualitySwitchButton(item: item),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PlayerProgressBar(videoId: item.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _restorePortrait() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
  }
}

class _LandscapeVideoSurface extends StatelessWidget {
  const _LandscapeVideoSurface({required this.item, required this.controller});

  final VideoFeedItem item;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    final videoController = controller;
    if (videoController == null || !videoController.value.isInitialized) {
      return Image.network(
        item.coverUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return const ColoredBox(
            color: Color(0xFF202124),
            child: Center(
              child: Icon(Icons.image_not_supported, color: Colors.white54),
            ),
          );
        },
      );
    }

    final size = videoController.value.size;
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(videoController),
        ),
      ),
    );
  }
}

class _LandscapeScrim extends StatelessWidget {
  const _LandscapeScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.36),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.58),
          ],
          stops: const [0, 0.48, 1],
        ),
      ),
    );
  }
}
