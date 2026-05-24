import 'package:flutter/material.dart';

import '../core/constants/route_constants.dart';
import 'app_router.dart';
import 'app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Player MVP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: RouteConstants.feed,
      routes: AppRouter.routes,
      onUnknownRoute: AppRouter.onUnknownRoute,
    );
  }
}
