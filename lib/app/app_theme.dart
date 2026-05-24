import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE53935),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
    );
  }

  static ThemeData get dark {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE53935),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: Colors.black,
      useMaterial3: true,
    );
  }
}
