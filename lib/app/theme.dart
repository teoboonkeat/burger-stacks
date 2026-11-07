import 'package:flutter/material.dart';

/// Palette. See the style guide in the UI proposal; every colour used by
/// screens and overlays lives here.
class C {
  static const bg = Color(0xFFFFF7EC);
  static const text = Color(0xFF4A2E2A);
  static const text2 = Color(0xFF7E625C);
  static const panel = Color(0xFFFFFFFF);
  static const border = Color(0xFFF0DCCB);
  static const accent = Color(0xFFE0306E);
  /// Raspberry for text under 18 sp (5.0:1 on cream; [accent] is 4.1:1).
  static const accentText = Color(0xFFC8285F);
  static const primary = accent;
  static const primaryShadow = Color(0xFFB21F54);
  static const adBadge = accent;
  static const star = Color(0xFFF2C230);
  /// Edge of gold things: signposts, gold jar lids, the gold-jar star.
  static const starEdge = Color(0xFFC99A12);
  /// "New" tag on a booster that was just introduced (white text, 5.3:1).
  static const newBadge = Color(0xFF2F7A1F);
  /// Locked level tile.
  static const lockedTile = Color(0xFFF4ECE3);
  /// Refusal bubble.
  static const bubble = Color(0xE6453044);
  /// Tutorial dim around the spotlight.
  static const coachDim = Color(0x8C4A2E2A);
  /// Scrim behind the result card.
  static const resultScrim = Color(0xCC4A2E2A);
  /// Lighter scrim behind the Sticky jam sheet, so the board stays readable.
  static const sheetScrim = Color(0x4D4A2E2A);
  /// Glass outline of tubes and the jar.
  static const glass = Color(0xFFD7E3EE);
}

/// Sizes and timings shared by screens (dp / ms).
class S {
  /// Home buttons: fixed width, never closer than [screenMargin] to the edge.
  static const homeButtonW = 300.0;
  static const screenMargin = 24.0;
  /// Booster bar height is fixed so the board (and bean size) is the same
  /// whether the bar shows 0, 2 or 3 boosters.
  static const boosterH = 66.0;
  static const boosterW = 100.0;
  static const boosterBarPad = 10.0;
  static const minTouch = 48.0;
  /// Smallest text drawn on the board (lock label), whatever the scale.
  static const minBoardText = 12.0;
  /// Win: confetti plays this long before the result card slides up.
  static const resultDelay = Duration(milliseconds: 1200);
  /// Tutorial goal chip stays this long, then fades.
  static const goalChip = Duration(seconds: 3);
  static const refusalShown = Duration(milliseconds: 1800);
  /// Jar-sealed celebration over the result card (tap skips it).
  static const sealShown = Duration(milliseconds: 1800);

  /// Taps are ignored this long after the last celebration card.
  static const cardGrace = Duration(milliseconds: 600);
  static const fade = Duration(milliseconds: 180);
  /// Candy Road: the stop Jump to scoop lands on pulses this long.
  static const pulse = Duration(milliseconds: 900);
  /// Jar sealed card: the full jar pours in this fast (the card shows for
  /// [sealShown]).
  static const sealPour = Duration(milliseconds: 900);
}

const _titleStyle =
    TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.text);

ThemeData buildTheme() => ThemeData(
      // Screens sit on the app-wide dotted backdrop (see main.dart).
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(seedColor: C.accent, surface: C.bg)
          .copyWith(primary: C.accent, surfaceTint: Colors.transparent),
      textTheme: const TextTheme().apply(bodyColor: C.text, displayColor: C.text),
      appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: C.text,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: _titleStyle),
      dialogTheme: DialogThemeData(
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: C.border, width: 3)),
        titleTextStyle: _titleStyle,
        contentTextStyle: const TextStyle(
            fontSize: 15, height: 1.35, fontWeight: FontWeight.w500, color: C.text),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: C.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(96, S.minTouch),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: C.primaryShadow, width: 2)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: C.text2,
          minimumSize: const Size(64, S.minTouch),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? C.accent : null),
      ),
      useMaterial3: true,
    );
