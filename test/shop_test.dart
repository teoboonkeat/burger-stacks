import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_beans/app/app_state.dart';
import 'package:jelly_beans/app/shop.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeWallet implements Wallet {
  @override
  int coins;
  FakeWallet(this.coins);
  @override
  void spendCoins(int n) => coins -= n;
}

void main() {
  test('prices live in one place', () {
    expect(Prices.of(Booster.undo), 20);
    expect(Prices.of(Booster.peek), 30);
    expect(Prices.of(Booster.extra), 40);
  });

  test('canAfford', () {
    expect(Shop.canAfford(39, Booster.extra), isFalse);
    expect(Shop.canAfford(40, Booster.extra), isTrue);
    expect(Shop.canAfford(20, Booster.undo), isTrue);
    expect(Shop.canAfford(0, Booster.peek), isFalse);
  });

  test('sweets are charged once the booster takes effect', () {
    final w = FakeWallet(100);
    var applied = 0;
    expect(Shop.redeem(w, Booster.extra, Pay.sweets, () => ++applied > 0), isTrue);
    expect(applied, 1);
    expect(w.coins, 60);
  });

  test('nothing is charged when the booster does not take effect', () {
    // E.g. undo while beans are in the air, or after the win.
    final w = FakeWallet(100);
    expect(Shop.redeem(w, Booster.undo, Pay.sweets, () => false), isFalse);
    expect(w.coins, 100);
  });

  test('not enough sweets: no effect, no charge', () {
    final w = FakeWallet(25);
    var applied = false;
    expect(
        Shop.redeem(w, Booster.peek, Pay.sweets, () => applied = true), isFalse);
    expect(applied, isFalse);
    expect(w.coins, 25);
  });

  test('paid by ad: effect applies, sweets untouched', () {
    final w = FakeWallet(5);
    expect(Shop.redeem(w, Booster.extra, Pay.ad, () => true), isTrue);
    expect(w.coins, 5);
  });

  test('AppState spends from the saved coins key', () async {
    SharedPreferences.setMockInitialValues({'flutter.coins': 50});
    final st = AppState();
    await st.load();
    expect(Shop.redeem(st, Booster.undo, Pay.sweets, () => true), isTrue);
    expect(st.coins, 30);
    await st.save();
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('coins'), 30);
  });
}
