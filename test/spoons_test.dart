import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_beans/app/app_state.dart';
import 'package:jelly_beans/app/rewards.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('P10 Master spoons', () {
    test('only a replay at par with no help earns a spoon', () {
      expect(Spoons.earns(best: 0, stars: 3, helped: false), isFalse);
      expect(Spoons.earns(best: 2, stars: 3, helped: false), isTrue);
      expect(Spoons.earns(best: 3, stars: 3, helped: false), isTrue);
      expect(Spoons.earns(best: 3, stars: 3, helped: true), isFalse);
      expect(Spoons.earns(best: 3, stars: 2, helped: false), isFalse);
    });

    test('result note says why there is no spoon', () {
      String? n(int best, int stars, bool helped, bool earned, bool had) =>
          Spoons.note(
              best: best, stars: stars, helped: helped, earned: earned, had: had);
      expect(n(2, 3, false, true, false), 'Gold spoon · +10 sweets');
      expect(n(0, 3, false, false, false),
          'Replay at par with no help for a gold spoon');
      expect(n(3, 3, true, false, false),
          'A gold spoon needs no Undo, Peek or Extra tube');
      expect(n(3, 3, false, false, true), isNull);
      expect(n(3, 2, false, false, false), isNull);
    });

    test('a spoon pays once, adds XP; all 10 in a jar pay 50 more', () async {
      SharedPreferences.setMockInitialValues({
        'stars': [for (var l = 1; l <= 10; l++) '$l:3'],
        'currentLevel': 11,
        'jarsSealed': ['1'],
      });
      final s = AppState();
      await s.load();
      final xp0 = s.xp;
      final r = s.completeLevel(1, 3, 200, helped: false);
      expect(r.spoon, isTrue);
      expect(r.spoonPay, Spoons.pay);
      expect(r.xp, 10);
      expect(s.xp, xp0 + 10);
      expect(s.completeLevel(1, 3, 200, helped: false).spoon, isFalse);
      expect(s.completeLevel(2, 3, 200).spoon, isFalse); // helped by default
      for (var l = 2; l <= 9; l++) {
        s.completeLevel(l, 3, 200, helped: false);
      }
      expect(s.allSpooned(1), isFalse);
      final last = s.completeLevel(10, 3, 200, helped: false);
      expect(last.spoonJar, 1);
      expect(last.spoonPay, Spoons.pay + Spoons.jarPay);
      expect(s.allSpooned(1), isTrue);
      await s.save();
      final t = AppState();
      await t.load();
      expect(t.spoonsIn(1), 10);
    });
  });
}
