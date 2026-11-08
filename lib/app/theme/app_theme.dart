import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const seedColor = Color(0xFF287A58);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(seedColor: seedColor);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7FAF7),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF7FAF7),
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }
}
