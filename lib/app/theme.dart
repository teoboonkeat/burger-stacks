import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFFFFF4E2);
  static const text = Color(0xFF3B2A1E);
  static const text2 = Color(0xFF7A6450);
  static const panel = Color(0xFFF3E2C7);
  static const border = Color(0xFFE6D2B2);
  static const primary = Color(0xFFE8483B);
  static const primaryShadow = Color(0xFFA8301F);
  static const reward = Color(0xFF3F9A30);
  static const rewardText = Color(0xFF2F7A23);
  static const adBadge = Color(0xFFB83224);
}

ThemeData buildTheme() => ThemeData(
      scaffoldBackgroundColor: C.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: C.primary, surface: C.bg),
      textTheme: const TextTheme().apply(bodyColor: C.text, displayColor: C.text),
      useMaterial3: true,
    );
