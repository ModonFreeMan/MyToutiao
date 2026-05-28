import 'package:flutter/material.dart';

import '../core/constants/route_constants.dart';
import '../features/feed/pages/feed_page.dart';
import '../features/player/pages/landscape_player_page.dart';
import '../features/search/pages/search_middle_page.dart';
import '../features/search/pages/search_result_page.dart';

class AppRouter {
  const AppRouter._();

  static Map<String, WidgetBuilder> get routes {
    return <String, WidgetBuilder>{
      RouteConstants.feed: (_) => const FeedPage(),
      RouteConstants.search: (_) => const SearchMiddlePage(),
      RouteConstants.searchResult: (_) => const SearchResultPage(),
      RouteConstants.landscapePlayer: (_) => const LandscapePlayerPage(),
    };
  }

  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      builder: (_) => const FeedPage(),
      settings: const RouteSettings(name: RouteConstants.feed),
    );
  }
}
