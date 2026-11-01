import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFFFFF7EC);
  static const text = Color(0xFF4A2E2A);
  static const text2 = Color(0xFF7E625C);
  static const panel = Color(0xFFFFFFFF);
  static const border = Color(0xFFF0DCCB);
  static const accent = Color(0xFFE0306E);
  static const primary = accent;
  static const primaryShadow = Color(0xFFB21F54);
  static const adBadge = accent;
  static const star = Color(0xFFF2C230);
}

ThemeData buildTheme() => ThemeData(
      // Screens sit on the app-wide dotted backdrop (see main.dart).
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(seedColor: C.accent, surface: C.bg),
      textTheme: const TextTheme().apply(bodyColor: C.text, displayColor: C.text),
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, foregroundColor: C.text),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? C.accent : null),
      ),
      useMaterial3: true,
    );
