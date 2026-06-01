import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/data/datasources/feed_data_source.dart';
import 'package:video_player_mvp/data/models/feed_item.dart';
import 'package:video_player_mvp/data/repositories/feed_repository.dart';
import 'package:video_player_mvp/features/feed/coordinators/feed_playback_coordinator.dart';
import 'package:video_player_mvp/features/feed/view_models/feed_view_model.dart';
import 'package:video_player_mvp/features/player/controllers/player_controller.dart';
import 'package:video_player_mvp/mock/mock_feed_items.dart';
import 'package:video_player_mvp/mock/mock_videos.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedPlaybackCoordinator', () {
    late _FakeVideoPlayerPlatform fakePlatform;

    setUp(() {
      fakePlatform = _FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakePlatform;
    });

    test('starts playback when a non-current video card is tapped', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);
      final item = mockVideoFeedItems.first;

      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();

      final state = container.read(playerControllerProvider);
      expect(state.videoId, item.id);
      expect(state.isInitialized, isTrue);
      expect(state.isPlaying, isTrue);
      expect(fakePlatform.createdUris, hasLength(1));
      expect(fakePlatform.playCount, 1);
    });

    test('toggles current video playback when video card is tapped', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);
      final item = mockVideoFeedItems.first;

      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();
      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();

      var state = container.read(playerControllerProvider);
      expect(state.isPlaying, isFalse);
      expect(fakePlatform.pauseCount, greaterThanOrEqualTo(1));

      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();

      state = container.read(playerControllerProvider);
      expect(state.isPlaying, isTrue);
      expect(fakePlatform.playCount, greaterThanOrEqualTo(2));
      expect(fakePlatform.createdUris, hasLength(1));
    });

    test(
      'pauses the current video when tapped during initial buffering',
      () async {
        fakePlatform.stayBufferingAfterPlay = true;
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);
        final item = mockVideoFeedItems.first;

        await coordinator.handleVideoCardTapped(item);
        await _settleMicrotasks();

        var state = container.read(playerControllerProvider);
        expect(state.videoId, item.id);
        expect(state.isInitialized, isTrue);
        expect(state.isPlaying, isTrue);
        expect(state.isBuffering, isTrue);

        final pauseCountBeforeTap = fakePlatform.pauseCount;

        await coordinator.handleVideoCardTapped(item);
        await _settleMicrotasks();

        state = container.read(playerControllerProvider);
        expect(state.isPlaying, isFalse);
        expect(fakePlatform.pauseCount, pauseCountBeforeTap + 1);
      },
    );

    test(
      'cancels pending autoplay when current initializing video is tapped',
      () async {
        fakePlatform.holdInitialization = true;
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);
        final item = mockVideoFeedItems.first;

        final playFuture = coordinator.handleVideoCardTapped(item);
        await _settleMicrotasks();

        var state = container.read(playerControllerProvider);
        expect(state.videoId, item.id);
        expect(state.isInitializing, isTrue);
        expect(state.isInitialized, isFalse);

        await coordinator.handleVideoCardTapped(item);
        await _settleMicrotasks();

        state = container.read(playerControllerProvider);
        expect(state.videoId, isNull);
        expect(state.isPlaying, isFalse);

        fakePlatform.releaseInitialization();
        await playFuture;
        await _settleMicrotasks();

        state = container.read(playerControllerProvider);
        expect(state.videoId, isNull);
        expect(state.isPlaying, isFalse);
        expect(fakePlatform.playCount, 0);
      },
    );

    test(
      'suppresses autoplay when newly visible video is tapped before playback switches',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            feedDataSourceProvider.overrideWithValue(
              _FakeFeedDataSource(mockVideoFeedItems.take(2).toList()),
            ),
          ],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);
        final firstItem = mockVideoFeedItems.first;
        final secondItem = mockVideoFeedItems[1];

        await container.read(feedViewModelProvider.notifier).loadInitial();
        container.read(feedViewModelProvider.notifier).setCurrentIndex(1);

        await coordinator.handleVideoCardTapped(firstItem);
        await _settleMicrotasks();
        expect(container.read(playerControllerProvider).videoId, firstItem.id);
        expect(container.read(playerControllerProvider).isPlaying, isTrue);

        await coordinator.handleVideoCardTapped(secondItem);
        await _settleMicrotasks();

        var state = container.read(playerControllerProvider);
        expect(state.videoId, isNull);
        expect(state.isPlaying, isFalse);

        await coordinator.handleFeedCurrentChanged(1);
        await _settleMicrotasks();

        state = container.read(playerControllerProvider);
        expect(state.videoId, isNull);
        expect(state.isPlaying, isFalse);
        expect(fakePlatform.playCount, 1);
      },
    );

    test('preloads current plus one video candidate', () async {
      final container = ProviderContainer.test(
        overrides: [
          feedDataSourceProvider.overrideWithValue(
            _FakeFeedDataSource(mockFeedItems),
          ),
        ],
      );
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);

      await container.read(feedViewModelProvider.notifier).loadInitial();
      await coordinator.handleFeedCurrentChanged(0);
      await _settlePreload();

      final controller = container.read(playerControllerProvider.notifier);
      expect(controller.preloadVideoId, 'video_002');
      expect(controller.hasPreloadController, isTrue);
      expect(controller.isPreloadInitialized, isTrue);
      expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
    });

    test(
      'current change promotes preloaded next video and schedules following preload',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            feedDataSourceProvider.overrideWithValue(
              _FakeFeedDataSource(mockVideoFeedItems.take(3).toList()),
            ),
          ],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);

        await container.read(feedViewModelProvider.notifier).loadInitial();
        await coordinator.handleFeedCurrentChanged(0);
        await _settlePreload();

        final playerController = container.read(
          playerControllerProvider.notifier,
        );
        expect(container.read(playerControllerProvider).videoId, 'video_001');
        expect(playerController.preloadVideoId, 'video_002');
        expect(fakePlatform.createdUris, hasLength(2));

        await coordinator.handleFeedCurrentChanged(1);
        await _settlePreload();

        final state = container.read(playerControllerProvider);
        expect(state.videoId, 'video_002');
        expect(state.isInitialized, isTrue);
        expect(state.isPlaying, isTrue);
        expect(playerController.preloadVideoId, 'video_003');
        expect(
          playerController.preloadStatus,
          PreloadControllerStatus.preloaded,
        );
        expect(fakePlatform.createdUris, hasLength(3));
      },
    );

    test(
      'rapid current changes only schedule latest preload after delay',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            feedDataSourceProvider.overrideWithValue(
              _FakeFeedDataSource(mockVideoFeedItems.take(4).toList()),
            ),
          ],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);

        await container.read(feedViewModelProvider.notifier).loadInitial();
        await coordinator.handleFeedCurrentChanged(0);
        await _settleMicrotasks();

        expect(fakePlatform.createdUris, hasLength(1));

        await coordinator.handleFeedCurrentChanged(1);
        await _settleMicrotasks();
        await coordinator.handleFeedCurrentChanged(2);
        await _settleMicrotasks();

        expect(fakePlatform.createdUris, hasLength(3));

        await _passPreloadScheduleDelay();

        final controller = container.read(playerControllerProvider.notifier);
        expect(controller.preloadVideoId, mockVideoFeedItems[3].id);
        expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
        expect(fakePlatform.createdUris, hasLength(4));
      },
    );

    test(
      'candidate null cancels pending preload and disposes preload immediately',
      () async {
        final dataSource = _FakeFeedDataSource(
          mockVideoFeedItems.take(2).toList(),
        );
        final container = ProviderContainer.test(
          overrides: [feedDataSourceProvider.overrideWithValue(dataSource)],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);
        final feedViewModel = container.read(feedViewModelProvider.notifier);

        await feedViewModel.loadInitial();
        await coordinator.handleFeedCurrentChanged(0);
        await _settleMicrotasks();

        expect(fakePlatform.createdUris, hasLength(1));

        dataSource.pages = [
          <FeedItem>[mockVideoFeedItems[2]],
        ];
        await feedViewModel.loadInitial();
        await coordinator.handleFeedCurrentChanged(0);
        await _settleMicrotasks();
        await _passPreloadScheduleDelay();

        final controller = container.read(playerControllerProvider.notifier);
        expect(controller.preloadVideoId, isNull);
        expect(controller.hasPreloadController, isFalse);
        expect(fakePlatform.createdUris, hasLength(2));
      },
    );

    test(
      'feed replacement cleanup does not block latest preload debounce registration',
      () async {
        final dataSource = _FakeFeedDataSource(
          mockVideoFeedItems.take(3).toList(),
        );
        final container = ProviderContainer.test(
          overrides: [feedDataSourceProvider.overrideWithValue(dataSource)],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);
        final feedViewModel = container.read(feedViewModelProvider.notifier);

        await feedViewModel.loadInitial();
        await coordinator.handleFeedCurrentChanged(0);
        await _settlePreload();

        final controller = container.read(playerControllerProvider.notifier);
        expect(controller.preloadVideoId, mockVideoFeedItems[1].id);

        dataSource.pages = [
          <FeedItem>[
            mockVideoFeedItems[3],
            mockFeedItems[1],
            mockVideoFeedItems[4],
          ],
        ];
        await feedViewModel.loadInitial();
        await coordinator.handleFeedCurrentChanged(0);
        await _settleMicrotasks();

        expect(controller.preloadVideoId, isNull);

        await _passPreloadScheduleDelay();

        expect(controller.preloadVideoId, mockVideoFeedItems[4].id);
        expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
      },
    );

    test('container dispose cancels pending preload timer', () async {
      final container = ProviderContainer.test(
        overrides: [
          feedDataSourceProvider.overrideWithValue(
            _FakeFeedDataSource(mockVideoFeedItems.take(2).toList()),
          ),
        ],
      );
      final coordinator = container.read(feedPlaybackCoordinatorProvider);

      await container.read(feedViewModelProvider.notifier).loadInitial();
      await coordinator.handleFeedCurrentChanged(0);
      await _settleMicrotasks();

      expect(fakePlatform.createdUris, hasLength(1));

      container.dispose();
      await _passPreloadScheduleDelay();

      expect(fakePlatform.createdUris, hasLength(1));
    });

    test('skips non-video items when selecting preload candidate', () async {
      final container = ProviderContainer.test(
        overrides: [
          feedDataSourceProvider.overrideWithValue(
            _FakeFeedDataSource(mockFeedItems),
          ),
        ],
      );
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);

      await container.read(feedViewModelProvider.notifier).loadInitial();
      await coordinator.handleFeedCurrentChanged(1);
      await _settlePreload();

      final state = container.read(playerControllerProvider);
      final controller = container.read(playerControllerProvider.notifier);
      expect(state.videoId, isNull);
      expect(controller.preloadVideoId, 'video_002');
      expect(controller.hasPreloadController, isTrue);
      expect(controller.isPreloadInitialized, isTrue);
      expect(fakePlatform.playCount, 0);
    });

    test(
      'forward direction falls back to previous video when no later video exists',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            feedDataSourceProvider.overrideWithValue(
              _FakeFeedDataSource(mockFeedItems),
            ),
          ],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);

        await container.read(feedViewModelProvider.notifier).loadInitial();
        await coordinator.handleFeedCurrentChanged(13);
        await _settlePreload();
        expect(
          container.read(playerControllerProvider.notifier).preloadVideoId,
          'video_010',
        );

        await coordinator.handleFeedCurrentChanged(14);
        await _settlePreload();

        expect(
          container.read(playerControllerProvider.notifier).preloadVideoId,
          'video_009',
        );
        expect(
          container
              .read(playerControllerProvider.notifier)
              .hasPreloadController,
          isTrue,
        );
      },
    );

    test(
      'unknown direction does not fallback to previous video when no later video exists',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            feedDataSourceProvider.overrideWithValue(
              _FakeFeedDataSource(mockFeedItems),
            ),
          ],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);

        await container.read(feedViewModelProvider.notifier).loadInitial();
        await coordinator.handleFeedCurrentChanged(14);
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        final controller = container.read(playerControllerProvider.notifier);
        expect(state.videoId, 'video_010');
        expect(controller.preloadVideoId, isNull);
        expect(controller.hasPreloadController, isFalse);
      },
    );

    test('backward direction selects previous video candidate', () async {
      final container = ProviderContainer.test(
        overrides: [
          feedDataSourceProvider.overrideWithValue(
            _FakeFeedDataSource(mockFeedItems),
          ),
        ],
      );
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);

      await container.read(feedViewModelProvider.notifier).loadInitial();
      await coordinator.handleFeedCurrentChanged(3);
      await _settlePreload();

      await coordinator.handleFeedCurrentChanged(2);
      await _settlePreload();

      expect(
        container.read(playerControllerProvider.notifier).preloadVideoId,
        'video_001',
      );
    });

    test(
      'backward direction falls back to next video when no previous video exists',
      () async {
        final container = ProviderContainer.test(
          overrides: [
            feedDataSourceProvider.overrideWithValue(
              _FakeFeedDataSource(mockFeedItems),
            ),
          ],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);

        await container.read(feedViewModelProvider.notifier).loadInitial();
        await coordinator.handleFeedCurrentChanged(1);
        await _settlePreload();

        await coordinator.handleFeedCurrentChanged(0);
        await _settlePreload();

        expect(
          container.read(playerControllerProvider.notifier).preloadVideoId,
          'video_002',
        );
      },
    );

    test('out of range index does not throw', () async {
      final container = ProviderContainer.test(
        overrides: [
          feedDataSourceProvider.overrideWithValue(
            _FakeFeedDataSource(mockFeedItems),
          ),
        ],
      );
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);

      await container.read(feedViewModelProvider.notifier).loadInitial();

      await expectLater(coordinator.handleFeedCurrentChanged(99), completes);
      await _settleMicrotasks();

      expect(
        container.read(playerControllerProvider.notifier).preloadVideoId,
        isNull,
      );
    });

    test('feed items reset clears last scroll direction', () async {
      final dataSource = _FakeFeedDataSource(mockFeedItems);
      final container = ProviderContainer.test(
        overrides: [feedDataSourceProvider.overrideWithValue(dataSource)],
      );
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);
      final feedViewModel = container.read(feedViewModelProvider.notifier);

      await feedViewModel.loadInitial();
      await coordinator.handleFeedCurrentChanged(14);
      await _settleMicrotasks();

      dataSource.pages = [
        <FeedItem>[
          mockVideoFeedItems[0],
          mockFeedItems[1],
          mockVideoFeedItems[1],
        ],
      ];
      await feedViewModel.loadInitial();
      feedViewModel.setCurrentIndex(1);
      await coordinator.handleFeedCurrentChanged(1);
      await _settlePreload();

      expect(
        container.read(playerControllerProvider.notifier).preloadVideoId,
        mockVideoFeedItems[1].id,
      );
    });

    test('non-append feed replacement clears last scroll direction', () async {
      final dataSource = _FakeFeedDataSource(mockFeedItems);
      final container = ProviderContainer.test(
        overrides: [feedDataSourceProvider.overrideWithValue(dataSource)],
      );
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);
      final feedViewModel = container.read(feedViewModelProvider.notifier);

      await feedViewModel.loadInitial();
      await coordinator.handleFeedCurrentChanged(14);
      await _settleMicrotasks();

      dataSource.pages = [
        <FeedItem>[
          mockVideoFeedItems[1],
          mockFeedItems[1],
          mockVideoFeedItems[2],
        ],
      ];
      await feedViewModel.loadInitial();
      await coordinator.handleFeedCurrentChanged(0);
      await _settlePreload();

      expect(
        container.read(playerControllerProvider.notifier).preloadVideoId,
        mockVideoFeedItems[2].id,
      );
    });

    test(
      'feed pagination append does not clear last scroll direction',
      () async {
        final dataSource = _FakeFeedDataSource.pages([
          mockFeedItems.take(4).toList(),
          mockFeedItems.skip(4).take(4).toList(),
        ]);
        final container = ProviderContainer.test(
          overrides: [feedDataSourceProvider.overrideWithValue(dataSource)],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);
        final feedViewModel = container.read(feedViewModelProvider.notifier);

        await feedViewModel.loadInitial();
        await coordinator.handleFeedCurrentChanged(3);
        await _settlePreload();

        await coordinator.handleFeedCurrentChanged(2);
        await _settlePreload();
        expect(
          container.read(playerControllerProvider.notifier).preloadVideoId,
          'video_001',
        );

        await feedViewModel.loadMore();
        feedViewModel.setCurrentIndex(1);
        await coordinator.handleFeedCurrentChanged(1);
        await _settlePreload();

        expect(
          container.read(playerControllerProvider.notifier).preloadVideoId,
          'video_001',
        );
      },
    );

    test(
      'no direction-aware candidate clears preload without clearing active video state',
      () async {
        final dataSource = _FakeFeedDataSource(mockFeedItems);
        final container = ProviderContainer.test(
          overrides: [feedDataSourceProvider.overrideWithValue(dataSource)],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);
        final feedViewModel = container.read(feedViewModelProvider.notifier);

        await feedViewModel.loadInitial();
        await coordinator.handleFeedCurrentChanged(0);
        await _settlePreload();

        dataSource.pages = [
          <FeedItem>[
            mockVideoFeedItems[0],
            mockFeedItems[1],
            mockVideoFeedItems[1],
          ],
        ];
        await feedViewModel.loadInitial();
        feedViewModel.setCurrentIndex(2);
        await coordinator.handleFeedCurrentChanged(2);
        await _settleMicrotasks();

        final state = container.read(playerControllerProvider);
        final controller = container.read(playerControllerProvider.notifier);
        expect(state.videoId, mockVideoFeedItems[1].id);
        expect(state.wantsToPlay, isTrue);
        expect(controller.preloadVideoId, isNull);
      },
    );

    test(
      'slow preload initialization does not block current feed change',
      () async {
        fakePlatform.holdInitialization = true;
        final container = ProviderContainer.test(
          overrides: [
            feedDataSourceProvider.overrideWithValue(
              _FakeFeedDataSource(mockFeedItems),
            ),
          ],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);

        await container.read(feedViewModelProvider.notifier).loadInitial();
        final currentChangedFuture = coordinator.handleFeedCurrentChanged(0);
        await _passAutoplayGrace();

        expect(
          container.read(playerControllerProvider).videoId,
          mockVideoFeedItems.first.id,
        );
        expect(container.read(playerControllerProvider).isInitializing, isTrue);

        fakePlatform.releaseInitializationForCreation(0);
        await currentChangedFuture;
        await _settlePreload();

        final state = container.read(playerControllerProvider);
        final controller = container.read(playerControllerProvider.notifier);
        expect(state.videoId, mockVideoFeedItems.first.id);
        expect(state.isPlaying, isTrue);
        expect(controller.preloadVideoId, 'video_002');
        expect(controller.preloadStatus, PreloadControllerStatus.initializing);
      },
    );

    test(
      'rapid current changes keep only latest preload candidate visible',
      () async {
        fakePlatform.holdInitialization = true;
        final container = ProviderContainer.test(
          overrides: [
            feedDataSourceProvider.overrideWithValue(
              _FakeFeedDataSource(mockVideoFeedItems.take(4).toList()),
            ),
          ],
        );
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);

        await container.read(feedViewModelProvider.notifier).loadInitial();
        final firstChangeFuture = coordinator.handleFeedCurrentChanged(0);
        await _passAutoplayGrace();
        fakePlatform.releaseInitializationForCreation(0);
        await firstChangeFuture;
        await _passPreloadScheduleDelay();
        await _waitForCreatedUris(fakePlatform, 2);

        final secondChangeFuture = coordinator.handleFeedCurrentChanged(1);
        await _passAutoplayGrace();
        fakePlatform.releaseInitializationForCreation(2);
        await secondChangeFuture;
        await _passPreloadScheduleDelay();
        await _waitForCreatedUris(fakePlatform, 4);

        final controller = container.read(playerControllerProvider.notifier);
        expect(controller.preloadVideoId, mockVideoFeedItems[2].id);
        expect(controller.preloadStatus, PreloadControllerStatus.initializing);

        fakePlatform.releaseInitializationForCreation(1);
        await _settlePreload();

        expect(controller.preloadVideoId, mockVideoFeedItems[2].id);
        expect(controller.preloadStatus, PreloadControllerStatus.initializing);

        fakePlatform.releaseInitializationForCreation(3);
        await _settlePreload();

        expect(controller.preloadVideoId, mockVideoFeedItems[2].id);
        expect(controller.preloadStatus, PreloadControllerStatus.preloaded);
      },
    );

    test('keeps paused current video paused for landscape rendering', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);
      final item = mockVideoFeedItems.first;

      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();
      await coordinator.handleVideoCardTapped(item);
      await _settleMicrotasks();

      expect(container.read(playerControllerProvider).isPlaying, isFalse);
      expect(container.read(playerControllerProvider).wantsToPlay, isFalse);
      final playCountBeforeLandscape = fakePlatform.playCount;

      await coordinator.handleLandscapeRequested(item);
      await _settleMicrotasks();

      var state = container.read(playerControllerProvider);
      expect(state.videoId, item.id);
      expect(state.isPlaying, isFalse);
      expect(state.wantsToPlay, isFalse);
      expect(state.isLandscapeRendering, isTrue);
      expect(fakePlatform.playCount, playCountBeforeLandscape);
      expect(fakePlatform.createdUris, hasLength(1));

      await coordinator.handleLandscapeClosed();

      state = container.read(playerControllerProvider);
      expect(state.isLandscapeRendering, isFalse);
    });

    test(
      'landscape request resumes only when playback intent is active',
      () async {
        final container = ProviderContainer.test();
        addTearDown(container.dispose);
        final coordinator = container.read(feedPlaybackCoordinatorProvider);
        final item = mockVideoFeedItems.first;

        await coordinator.handleVideoCardTapped(item);
        await _settleMicrotasks();

        fakePlatform.emitIsPlayingState(false);
        await _settleMicrotasks();

        var state = container.read(playerControllerProvider);
        expect(state.isPlaying, isFalse);
        expect(state.wantsToPlay, isTrue);

        final playCountBeforeLandscape = fakePlatform.playCount;

        await coordinator.handleLandscapeRequested(item);
        await _settleMicrotasks();

        state = container.read(playerControllerProvider);
        expect(state.videoId, item.id);
        expect(state.isPlaying, isTrue);
        expect(state.wantsToPlay, isTrue);
        expect(state.isLandscapeRendering, isTrue);
        expect(fakePlatform.playCount, playCountBeforeLandscape + 1);
      },
    );

    test('landscape request initializes target video when needed', () async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final coordinator = container.read(feedPlaybackCoordinatorProvider);
      final item = mockVideoFeedItems[1];

      await coordinator.handleLandscapeRequested(item);
      await _settleMicrotasks();

      final state = container.read(playerControllerProvider);
      expect(state.videoId, item.id);
      expect(state.isInitialized, isTrue);
      expect(state.isPlaying, isTrue);
      expect(state.isLandscapeRendering, isTrue);
      expect(fakePlatform.createdUris, hasLength(1));
    });
  });
}

class _FakeFeedDataSource implements FeedDataSource {
  _FakeFeedDataSource(List<FeedItem> items) : pages = [items];

  _FakeFeedDataSource.pages(this.pages);

  List<List<FeedItem>> pages;

  @override
  Future<List<FeedItem>> fetchFeedItems({
    required int page,
    required int pageSize,
  }) async {
    return pages.elementAtOrNull(page - 1) ?? const <FeedItem>[];
  }
}

Future<void> _settleMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

Future<void> _settlePreload() async {
  await _passPreloadScheduleDelay();
  for (var i = 0; i < 5; i++) {
    await _settleMicrotasks();
  }
}

Future<void> _passPreloadScheduleDelay() async {
  await Future<void>.delayed(const Duration(milliseconds: 150));
  await _settleMicrotasks();
}

Future<void> _passAutoplayGrace() async {
  await Future<void>.delayed(const Duration(milliseconds: 200));
  await _settleMicrotasks();
}

Future<void> _waitForCreatedUris(
  _FakeVideoPlayerPlatform fakePlatform,
  int count,
) async {
  for (var i = 0; i < 10; i++) {
    if (fakePlatform.createdUris.length >= count) {
      return;
    }

    await _settleMicrotasks();
  }
}

class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final _eventControllers = <int, StreamController<VideoEvent>>{};
  final createdUris = <String>[];
  final _createdPlayerIds = <int>[];
  final _initializedPlayerIds = <int>{};
  final _positions = <int, Duration>{};
  int _nextPlayerId = 0;
  int pauseCount = 0;
  int playCount = 0;
  bool stayBufferingAfterPlay = false;
  bool holdInitialization = false;

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

      if (holdInitialization) {
        return;
      }

      _emitInitializationEvent(playerId, controller);
    });
    return controller.stream;
  }

  void releaseInitialization() {
    holdInitialization = false;
    for (final entry in _eventControllers.entries) {
      _emitInitializationEvent(entry.key, entry.value);
    }
  }

  void releaseInitializationForCreation(int creationIndex) {
    final playerId = _createdPlayerIds[creationIndex];
    final controller = _eventControllers[playerId];
    if (controller == null || controller.isClosed) {
      return;
    }

    _emitInitializationEvent(playerId, controller);
  }

  void _emitInitializationEvent(
    int playerId,
    StreamController<VideoEvent> controller,
  ) {
    if (controller.isClosed || !_initializedPlayerIds.add(playerId)) {
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
    await _eventControllers.remove(playerId)?.close();
    _positions.remove(playerId);
    _initializedPlayerIds.remove(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    playCount += 1;
    _eventControllers[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
    if (stayBufferingAfterPlay) {
      _eventControllers[playerId]?.add(
        VideoEvent(eventType: VideoEventType.bufferingStart),
      );
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
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    _positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async {
    return _positions[playerId] ?? Duration.zero;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
