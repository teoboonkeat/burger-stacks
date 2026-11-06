import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_beans/app/app_state.dart';
import 'package:jelly_beans/app/chapters.dart';
import 'package:jelly_beans/app/shop.dart';
import 'package:jelly_beans/logic/board.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('P1a Bean Jars', () {
    test('10 scoops per jar, the 10th is the Lid scoop', () {
      expect(Jars.count(200), 20);
      expect(Jars.of(1), 1);
      expect(Jars.of(10), 1);
      expect(Jars.of(11), 2);
      expect(Jars.of(200), 20);
      expect(Jars.first(6), 51);
      expect(Jars.lid(6), 60);
      expect(Jars.isLid(60), isTrue);
      expect(Jars.isLid(59), isFalse);
    });

    test('names follow the flavour order', () {
      expect(Jars.flavour(1), Ingredient.berry);
      expect(Jars.name(6), 'Jar 6 · Cola');
      expect(Jars.name(7), 'Jar 7 · Berry');
    });

    test('seal pay: 50, gold jars 200', () {
      expect(Jars.payFor(1), 50);
      expect(Jars.payFor(5), 200);
      expect(Jars.payFor(20), 200);
      final total = [for (var j = 1; j <= 20; j++) Jars.payFor(j)].reduce((a, b) => a + b);
      // Plus the Lid bonus on 20 Lid scoops: about 1,800 over the game.
      expect(total + 20 * Jars.lidBonus, 1800);
    });

    test('filled counts won scoops of the jar only', () {
      expect(Jars.filled(1, {1: 3, 2: 1, 11: 2}), 2);
      expect(Jars.filled(2, {1: 3, 2: 1, 11: 2}), 1);
    });

    test('winning the Lid scoop seals the jar once', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      for (var l = 1; l < 10; l++) {
        expect(s.completeLevel(l, 3, 200).sealed, isNull);
      }
      final before = s.coins;
      final r = s.completeLevel(10, 3, 200);
      expect(r.sealed, 1);
      expect(r.lidBonus, Jars.lidBonus);
      expect(r.pay, 25 + 10);
      expect(r.sealPay, 50);
      expect(s.coins - before, 25 + 10 + 50);
      expect(s.stock(Booster.extra), 1);
      final again = s.completeLevel(10, 3, 200);
      expect(again.sealed, isNull);
      expect(again.total, 0);
      expect(s.stock(Booster.extra), 1);
    });

    test('free Extra tube stock is used before paying and saved', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      expect(s.useStock(Booster.extra), isFalse);
      s.addStock(Booster.extra, 2);
      expect(s.useStock(Booster.extra), isTrue);
      await s.save();
      final t = AppState();
      await t.load();
      expect(t.stock(Booster.extra), 1);
    });

    test('a save from before jars seals passed jars without back-pay', () async {
      SharedPreferences.setMockInitialValues({
        'currentLevel': 25,
        'coins': 100,
        'stars': [for (var l = 1; l <= 24; l++) '$l:2'],
      });
      final s = AppState();
      await s.load();
      expect(s.jarsSealed, {1, 2});
      expect(s.coins, 100);
      expect(s.stock(Booster.extra), 0);
    });
  });
}
