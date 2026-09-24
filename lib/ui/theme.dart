import 'package:flutter/material.dart';

const erAccent = Color(0xFF2DD4BF);
const erSurface = Color(0xFF111418);
const erSurfaceAlt = Color(0xFF1A1F26);
const erInk = Color(0xFFE6EDF3);

ThemeData erTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: erSurface,
      colorScheme: const ColorScheme.dark(
        primary: erAccent,
        surface: erSurface,
        surfaceContainerHighest: erSurfaceAlt,
        onSurface: erInk,
      ),
      cardTheme: const CardThemeData(color: erSurfaceAlt),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
