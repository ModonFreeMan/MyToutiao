import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_mvp/data/datasources/feed_data_source.dart';
import 'package:video_player_mvp/data/models/feed_item.dart';
import 'package:video_player_mvp/data/repositories/feed_repository.dart';
import 'package:video_player_mvp/features/feed/view_models/feed_view_model.dart';
import 'package:video_player_mvp/mock/mock_feed_items.dart';

void main() {
  group('FeedViewModel', () {
    test('loads first page initially', () async {
      final dataSource = _FakeFeedDataSource([mockFeedItems.take(4).toList()]);
      final container = _createContainer(dataSource);
      addTearDown(container.dispose);

      await _settleMicrotasks();

      final state = container.read(feedViewModelProvider);
      expect(state.items.map((item) => item.id), [
        'video_001',
        'image_001',
        'video_002',
        'video_003',
      ]);
      expect(state.currentPage, 1);
      expect(state.currentIndex, 0);
      expect(state.hasMore, isTrue);
      expect(state.isLoading, isFalse);
      expect(dataSource.calls, [(page: 1, pageSize: 4)]);
    });

    test('stores error when initial load fails', () async {
      final dataSource = _FakeFeedDataSource(
        const [],
        failures: {1: StateError('load failed')},
      );
      final container = _createContainer(dataSource);
      addTearDown(container.dispose);

      await _settleMicrotasks();

      final state = container.read(feedViewModelProvider);
      expect(state.items, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, contains('load failed'));
    });

    test('appends next page when loading more', () async {
      final dataSource = _FakeFeedDataSource([
        mockFeedItems.take(4).toList(),
        mockFeedItems.skip(4).take(2).toList(),
      ]);
      final container = _createContainer(dataSource);
      addTearDown(container.dispose);

      await _settleMicrotasks();
      await container.read(feedViewModelProvider.notifier).loadMore();

      final state = container.read(feedViewModelProvider);
      expect(state.items, hasLength(6));
      expect(state.currentPage, 2);
      expect(state.hasMore, isFalse);
      expect(state.isLoadingMore, isFalse);
      expect(dataSource.calls, [
        (page: 1, pageSize: 4),
        (page: 2, pageSize: 4),
      ]);
    });

    test('does not load more when there is no more data', () async {
      final dataSource = _FakeFeedDataSource([mockFeedItems.take(2).toList()]);
      final container = _createContainer(dataSource);
      addTearDown(container.dispose);

      await _settleMicrotasks();
      await container.read(feedViewModelProvider.notifier).loadMore();

      expect(dataSource.calls, [(page: 1, pageSize: 4)]);
    });

    test('ignores out-of-range current index', () async {
      final dataSource = _FakeFeedDataSource([mockFeedItems.take(4).toList()]);
      final container = _createContainer(dataSource);
      addTearDown(container.dispose);

      await _settleMicrotasks();
      final viewModel = container.read(feedViewModelProvider.notifier);

      viewModel.setCurrentIndex(-1);
      expect(container.read(feedViewModelProvider).currentIndex, 0);

      viewModel.setCurrentIndex(99);
      expect(container.read(feedViewModelProvider).currentIndex, 0);
    });

    test('focuses item across pages', () async {
      final dataSource = _FakeFeedDataSource([
        mockFeedItems.take(4).toList(),
        mockFeedItems.skip(4).take(4).toList(),
      ]);
      final container = _createContainer(dataSource);
      addTearDown(container.dispose);

      await _settleMicrotasks();

      final didFocus = await container
          .read(feedViewModelProvider.notifier)
          .focusItemById('video_005');

      final state = container.read(feedViewModelProvider);
      expect(didFocus, isTrue);
      expect(state.currentIndex, 6);
      expect(state.items[state.currentIndex].id, 'video_005');
    });

    test('focuses distant item across multiple pages', () async {
      final dataSource = _FakeFeedDataSource([
        mockFeedItems.take(4).toList(),
        mockFeedItems.skip(4).take(4).toList(),
        mockFeedItems.skip(8).take(4).toList(),
        mockFeedItems.skip(12).take(3).toList(),
      ]);
      final container = _createContainer(dataSource);
      addTearDown(container.dispose);

      await _settleMicrotasks();

      final didFocus = await container
          .read(feedViewModelProvider.notifier)
          .focusItemById('video_009');

      final state = container.read(feedViewModelProvider);
      expect(didFocus, isTrue);
      expect(state.currentIndex, 12);
      expect(state.items[state.currentIndex].id, 'video_009');
      expect(state.pendingFocusedIndex, 12);
      expect(dataSource.calls, [
        (page: 1, pageSize: 4),
        (page: 2, pageSize: 4),
        (page: 3, pageSize: 4),
        (page: 4, pageSize: 4),
      ]);
    });

    test(
      'keeps distant focus when an intermediate page change is reported',
      () async {
        final dataSource = _FakeFeedDataSource([
          mockFeedItems.take(4).toList(),
          mockFeedItems.skip(4).take(4).toList(),
          mockFeedItems.skip(8).take(4).toList(),
          mockFeedItems.skip(12).take(3).toList(),
        ]);
        final container = _createContainer(dataSource);
        addTearDown(container.dispose);

        await _settleMicrotasks();

        final viewModel = container.read(feedViewModelProvider.notifier);
        final didFocus = await viewModel.focusItemById('video_009');
        expect(didFocus, isTrue);

        viewModel.setCurrentIndex(3);

        final state = container.read(feedViewModelProvider);
        expect(state.currentIndex, 12);
        expect(state.items[state.currentIndex].id, 'video_009');
        expect(state.pendingFocusedIndex, 12);

        viewModel.setCurrentIndex(12);

        final settledState = container.read(feedViewModelProvider);
        expect(settledState.currentIndex, 12);
        expect(settledState.pendingFocusedIndex, isNull);
      },
    );

    test('returns false when focus target cannot be loaded', () async {
      final dataSource = _FakeFeedDataSource([
        mockFeedItems.take(4).toList(),
        const <FeedItem>[],
      ]);
      final container = _createContainer(dataSource);
      addTearDown(container.dispose);

      await _settleMicrotasks();

      final didFocus = await container
          .read(feedViewModelProvider.notifier)
          .focusItemById('missing');

      expect(didFocus, isFalse);
      expect(container.read(feedViewModelProvider).currentIndex, 0);
    });
  });
}

ProviderContainer _createContainer(_FakeFeedDataSource dataSource) {
  return ProviderContainer.test(
    overrides: [
      feedRepositoryProvider.overrideWithValue(
        FeedRepository(dataSource: dataSource),
      ),
    ],
  )..read(feedViewModelProvider);
}

Future<void> _settleMicrotasks() async {
  await Future<void>.delayed(Duration.zero);
}

class _FakeFeedDataSource implements FeedDataSource {
  _FakeFeedDataSource(this.pages, {this.failures = const {}});

  final List<List<FeedItem>> pages;
  final Map<int, Object> failures;
  final calls = <({int page, int pageSize})>[];

  @override
  Future<List<FeedItem>> fetchFeedItems({
    required int page,
    required int pageSize,
  }) async {
    calls.add((page: page, pageSize: pageSize));
    final failure = failures[page];
    if (failure != null) {
      throw failure;
    }

    return pages.elementAtOrNull(page - 1) ?? const <FeedItem>[];
  }
}
