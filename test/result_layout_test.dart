import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_beans/ads/ad_service.dart';
import 'package:jelly_beans/app/app_state.dart';
import 'package:jelly_beans/app/rewards.dart';
import 'package:jelly_beans/app/theme.dart';
import 'package:jelly_beans/logic/board.dart';
import 'package:jelly_beans/ui/game_screen.dart';
import 'package:jelly_beans/ui/screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real Roboto from the Flutter SDK, so text is measured as on a phone
/// (the test font draws every letter as a wide square).
Future<void> _loadRoboto() async {
  final dir = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final w in ['regular', 'medium', 'bold', 'black']) {
    final f = File('$dir/roboto-$w.ttf');
    if (f.existsSync()) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await loader.load();
}

void main() {
  setUpAll(_loadRoboto);

  // The busiest result card: a Lid scoop that seals a jar and ranks up,
  // on a 360x640 phone. A layout overflow fails the test.
  testWidgets('result card fits a small phone with every reward', (t) async {
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
    expect(t.takeException(), isNull);
    // Let the celebration timers run out.
    await t.pump(S.sealShown * 2);
  });
}
