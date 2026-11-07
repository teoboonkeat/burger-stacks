import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_beans/ads/ad_service.dart';
import 'package:jelly_beans/app/app_state.dart';
import 'package:jelly_beans/app/rewards.dart';
import 'package:jelly_beans/app/theme.dart';
import 'package:jelly_beans/levels/level.dart';
import 'package:jelly_beans/logic/board.dart';
import 'package:jelly_beans/ui/game_screen.dart';
import 'package:jelly_beans/ui/screens.dart';
import 'package:jelly_beans/ui/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Roboto from the Flutter SDK's material fonts, found from FLUTTER_ROOT or
/// from the test runner, which lives inside the SDK's bin/cache.
List<File> _robotoFiles() {
  final roots = [
    ?Platform.environment['FLUTTER_ROOT'],
    for (final p in [Platform.resolvedExecutable, Platform.executable])
      if (p.replaceAll(r'\', '/').indexOf('/bin/cache/') case final i when i > 0)
        p.substring(0, i),
  ];
  const weights = {'regular', 'medium', 'bold', 'black'};
  for (final r in roots) {
    final dir = Directory('$r/bin/cache/artifacts/material_fonts');
    if (!dir.existsSync()) continue;
    // Matched without case: the file names differ between platforms.
    final files = [
      for (final f in dir.listSync().whereType<File>())
        if (weights.any((w) => f.path.toLowerCase().endsWith('roboto-$w.ttf'))) f
    ];
    if (files.isNotEmpty) return files;
  }
  return [];
}

/// Real Roboto, so text is measured as on a phone (the test font draws
/// every letter as a wide square and would overflow anything).
Future<bool> _loadRoboto() async {
  final files = _robotoFiles();
  if (files.isEmpty) return false;
  final loader = FontLoader('Roboto');
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  }
  await loader.load();
  return true;
}

void main() {
  var roboto = false;
  setUpAll(() async => roboto = await _loadRoboto());

  // The busiest result card: a Lid scoop that seals a jar and ranks up,
  // on a 360x640 phone. A layout overflow fails the test.
  testWidgets('result card fits a small phone with every reward', (t) async {
    if (!roboto) {
      markTestSkipped('Roboto not found in the Flutter SDK; text would not '
          'measure as on a phone');
      return;
    }
    SharedPreferences.setMockInitialValues({
      'stars': [for (var l = 1; l <= 9; l++) '$l:2'],
      'currentLevel': 10,
    });
    final st = AppState();
    await st.load();
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final tubes = [
      for (final f in Ingredient.values)
        Tube([for (var i = 0; i < 4; i++) Piece(f)])..sealed = true,
    ];
    await t.pumpWidget(MaterialApp(
      home: SweetScreen(
        s: Services(st, const []),
        level: 10,
        stars: 2,
        moves: 18,
        par: 15,
        best: 0,
        report: const WinReport(
            pay: 30, lidBonus: 10, sealed: 1, sealPay: 50, xp: 50, rankUp: 3,
            rankPay: 25),
        tubes: tubes,
        ads: AdService(st),
      ),
    ));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Jar sealed!'), findsOneWidget);
    await t.tap(find.text('Jar sealed!'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('RANK UP'), findsOneWidget);
    await t.tap(find.text('RANK UP'));
    await t.pumpAndSettle();
    expect(find.text('Next scoop'), findsOneWidget);
    expect(find.text('Retry for ★★★'), findsOneWidget);
    // Every reward as a chip, and the total of all of them.
    for (final chip in ['+10 Lid scoop', '+50 jar sealed', 'Extra tube', '+25 rank 3']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    expect(find.text('+20 sweets'), findsOneWidget);
    expect(find.text('Total +105 sweets'), findsOneWidget);
    // The chips must not squeeze the jar picture to nothing.
    expect(t.getRect(find.byType(Jar).first).height, greaterThan(60));
    expect(t.takeException(), isNull);
    // Let the celebration timers run out.
    await t.pump(S.sealShown * 2);
  });
  /// 200 placeholder scoops: Home and the Pantry only count them.
  final levels = [
    for (var i = 1; i <= 200; i++)
      Level(id: i, capacity: 4, par: 1, tubes: const [])
  ];

  Future<AppState> homeOn(WidgetTester t, Map<String, Object> save) async {
    SharedPreferences.setMockInitialValues(save);
    final st = AppState();
    await st.load();
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        theme: buildTheme(), home: HomeScreen(Services(st, levels))));
    await t.pump(const Duration(seconds: 3));
    return st;
  }

  // J2: a brand-new save shows only the logo, Play, Levels and Settings.
  testWidgets('Home on a new save has no jar chip or rank', (t) async {
    if (!roboto) return markTestSkipped('Roboto not found');
    await homeOn(t, {});
    expect(find.byType(JarChip), findsNothing);
    expect(find.byType(RankBar), findsNothing);
    expect(find.text('Play · Scoop 1'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('jar chip explains jars once, then opens the Pantry', (t) async {
    if (!roboto) return markTestSkipped('Roboto not found');
    final st = await homeOn(t, {
      'currentLevel': 58,
      'stars': [for (var l = 1; l <= 57; l++) '$l:${1 + l % 3}'],
      'jarsSealed': ['1', '2', '3', '4', '5'],
      'spoons': ['3', '7'],
    });
    expect(find.text('Win 10 scoops to fill and seal a jar'), findsOneWidget);
    // A rank badge from rank 2 (this save is well past it).
    expect(find.bySemanticsLabel(RegExp(r'^Rank \d+')), findsOneWidget);
    await t.tap(find.byType(JarChip));
    await t.pumpAndSettle();
    expect(st.jarChipSeen, isTrue);
    expect(find.text('Pantry'), findsOneWidget);
    expect(find.byType(PantryShelf), findsOneWidget);
    expect(find.text('Win Lid scoop 60 to seal it · 2 to go'), findsOneWidget);
    expect(t.takeException(), isNull);
    // Closed, the chip now shows the reward instead of the explainer.
    Navigator.of(t.element(find.text('Pantry'))).pop();
    await t.pumpAndSettle();
    expect(find.text('Seal it at Lid scoop 60 · +50'), findsOneWidget);
  });
}
