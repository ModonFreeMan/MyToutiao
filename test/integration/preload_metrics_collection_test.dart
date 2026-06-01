import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:video_player_mvp/app/app.dart';
import 'package:video_player_mvp/features/feed/providers/feed_preload_config_provider.dart';
import 'package:video_player_mvp/features/feed/view_models/feed_view_model.dart';
import 'package:video_player_mvp/features/observability/providers/observability_provider.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';

import '../helpers/fake_video_player_platform.dart';
import '../helpers/test_app.dart';

const _mode = String.fromEnvironment(
  'PRELOAD_METRICS_MODE',
  defaultValue: 'preload_only',
);
const _targetVideoSamples = int.fromEnvironment(
  'PRELOAD_METRICS_TARGET_VIDEO_SAMPLES',
  defaultValue: 30,
);
const _outputPath = String.fromEnvironment(
  'PRELOAD_METRICS_OUTPUT',
  defaultValue: 'build/reports/preload_metrics_report.json',
);

void main() {
  late FakeVideoPlayerPlatform fakeVideoPlayerPlatform;

  setUp(() {
    fakeVideoPlayerPlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakeVideoPlayerPlatform;
  });

  testWidgets('collects playback startup and preload report json', (
    WidgetTester tester,
  ) async {
    final preferences = await createMockPreferences();
    final container = createTestContainer(preferences);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pump(const Duration(milliseconds: 900));

    var movingForward = true;
    for (var step = 0; step < _targetVideoSamples * 5; step += 1) {
      final report = _buildReport(container);
      final visibleItems = report['visible_items'] as int? ?? 0;
      if (visibleItems >= _targetVideoSamples) {
        break;
      }

      final state = container.read(feedViewModelProvider);
      if (state.items.length < 2) {
        await tester.pump(const Duration(milliseconds: 300));
        continue;
      }

      final currentIndex = state.currentIndex;
      if (currentIndex >= state.items.length - 1) {
        movingForward = false;
      } else if (currentIndex <= 0) {
        movingForward = true;
      }

      final nextIndex = currentIndex + (movingForward ? 1 : -1);
      container.read(feedViewModelProvider.notifier).setCurrentIndex(nextIndex);
      await tester.pump(const Duration(milliseconds: 850));
    }

    await _exerciseQuickCurrentChanges(tester, container);
    await _exercisePauseIntent(tester, container);

    final report = _buildReport(container);
    expect(report['visible_items'], greaterThanOrEqualTo(_targetVideoSamples));

    final output = <String, Object?>{
      'mode': _mode,
      'generated_at': DateTime.now().toUtc().toIso8601String(),
      'feed_preload_enabled': container.read(feedPreloadEnabledProvider),
      'target_video_samples': _targetVideoSamples,
      'fake_video_platform': true,
      'created_video_controllers': fakeVideoPlayerPlatform.createdUris.length,
      'play_count': fakeVideoPlayerPlatform.playCount,
      'pause_count': fakeVideoPlayerPlatform.pauseCount,
      'report': report,
    };

    final file = File(_outputPath);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(output));

    // Keep this easy to grep from CI or a terminal transcript.
    debugPrint('PRELOAD_METRICS_REPORT_PATH=${file.absolute.path}');

    await container.read(playerControllerProvider.notifier).pause();
    await tester.pump(const Duration(milliseconds: 250));
  });
}

Map<String, Object?> _buildReport(ProviderContainer container) {
  final buildReport = container.read(playbackStartupDebugReportProvider);
  final report = buildReport();
  if (report == null) {
    fail('Playback startup debug report is only available in debug mode.');
  }
  return report;
}

Future<void> _exerciseQuickCurrentChanges(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final feedViewModel = container.read(feedViewModelProvider.notifier);
  final itemCount = container.read(feedViewModelProvider).items.length;
  if (itemCount < 4) {
    return;
  }

  for (final index in <int>[1, 2, 3, 2, 1, 2]) {
    if (index >= itemCount) {
      continue;
    }
    feedViewModel.setCurrentIndex(index);
    await tester.pump(const Duration(milliseconds: 35));
  }
  await tester.pump(const Duration(milliseconds: 900));
}

Future<void> _exercisePauseIntent(
  WidgetTester tester,
  ProviderContainer container,
) async {
  final controller = container.read(playerControllerProvider.notifier);
  final state = container.read(playerControllerProvider);
  if (state.videoId == null || !state.isPlaying) {
    return;
  }

  await controller.pause();
  await tester.pump(const Duration(milliseconds: 250));
  await controller.resume();
  await tester.pump(const Duration(milliseconds: 250));
}
