import 'package:flutter_riverpod/flutter_riverpod.dart';

final feedPreloadEnabledProvider = Provider<bool>(
  (_) => const bool.fromEnvironment('FEED_PRELOAD_ENABLED', defaultValue: true),
);
