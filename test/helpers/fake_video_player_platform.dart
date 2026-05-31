import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _eventControllers = <int, StreamController<VideoEvent>>{};
  final _positions = <int, Duration>{};
  final _initializedPlayerIds = <int>{};
  final _createdPlayerIds = <int>[];

  final createdUris = <String>[];
  final disposedPlayerIds = <int>[];
  final seekedPositions = <Duration>[];

  int _nextPlayerId = 0;
  int pauseCount = 0;
  int playCount = 0;
  int disposeCount = 0;
  bool failInitialize = false;
  bool failDispose = false;
  bool holdInitialization = false;
  bool holdPlay = false;
  bool holdDispose = false;
  Completer<void>? _pendingPlayCompleter;
  Completer<void>? _pendingDisposeCompleter;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = ++_nextPlayerId;
    _createdPlayerIds.add(playerId);
    createdUris.add(options.dataSource.uri ?? options.dataSource.asset ?? '');
    _positions[playerId] = Duration.zero;
    _eventControllers[playerId] = StreamController<VideoEvent>.broadcast();
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final controller = _eventControllers[playerId]!;
    Timer.run(() {
      if (controller.isClosed) {
        return;
      }

      _emitInitializationEvent(playerId, controller);
    });
    return controller.stream;
  }

  void releaseInitialization() {
    holdInitialization = false;
    for (final entry in _eventControllers.entries) {
      final controller = entry.value;
      if (!controller.isClosed) {
        _emitInitializationEvent(entry.key, controller, ignoreHold: true);
      }
    }
  }

  void releaseInitializationForCreation(int creationIndex) {
    final playerId = _createdPlayerIds[creationIndex];
    final controller = _eventControllers[playerId];
    if (controller == null || controller.isClosed) {
      return;
    }

    _emitInitializationEvent(playerId, controller, ignoreHold: true);
  }

  void failInitializationForCreation(int creationIndex) {
    final playerId = _createdPlayerIds[creationIndex];
    final controller = _eventControllers[playerId];
    if (controller == null || controller.isClosed) {
      return;
    }

    controller.addError(
      PlatformException(code: 'test', message: 'initialize failed'),
    );
  }

  void _emitInitializationEvent(
    int playerId,
    StreamController<VideoEvent> controller, {
    bool ignoreHold = false,
  }) {
    if (holdInitialization && !ignoreHold) {
      return;
    }

    if (failInitialize) {
      controller.addError(
        PlatformException(code: 'test', message: 'initialize failed'),
      );
      return;
    }

    if (!_initializedPlayerIds.add(playerId)) {
      return;
    }

    controller.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(minutes: 2),
        size: const Size(1280, 720),
        rotationCorrection: 0,
      ),
    );
  }

  @override
  Widget buildView(int playerId) {
    return ColoredBox(
      key: ValueKey<String>('fake-video-view-$playerId'),
      color: Colors.black,
    );
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return buildView(options.playerId);
  }

  @override
  Future<void> dispose(int playerId) async {
    disposeCount += 1;
    disposedPlayerIds.add(playerId);
    if (holdDispose) {
      _pendingDisposeCompleter = Completer<void>();
      await _pendingDisposeCompleter!.future;
    }
    final controller = _eventControllers.remove(playerId);
    if (controller != null) {
      unawaited(controller.close());
    }
    _positions.remove(playerId);
    _initializedPlayerIds.remove(playerId);
    if (failDispose) {
      throw PlatformException(code: 'test', message: 'dispose failed');
    }
  }

  void releasePendingDispose() {
    holdDispose = false;
    final completer = _pendingDisposeCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    playCount += 1;
    if (holdPlay) {
      _pendingPlayCompleter = Completer<void>();
      await _pendingPlayCompleter!.future;
    }
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  void releasePendingPlay() {
    holdPlay = false;
    final completer = _pendingPlayCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCount += 1;
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    seekedPositions.add(position);
    _positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    return _positions[playerId] ?? Duration.zero;
  }

  void setCurrentPosition(Duration position) {
    for (final playerId in _positions.keys) {
      _positions[playerId] = position;
    }
  }

  void emitIsPlayingState(bool isPlaying) {
    for (final controller in _eventControllers.values) {
      if (!controller.isClosed) {
        controller.add(
          VideoEvent(
            eventType: VideoEventType.isPlayingStateUpdate,
            isPlaying: isPlaying,
          ),
        );
      }
    }
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
