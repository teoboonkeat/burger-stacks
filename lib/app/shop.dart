/// Boosters bought with sweets (the currency; saved as `coins`) instead of
/// watching an ad. Pure Dart (unit-tested).
library;

enum Booster { undo, peek, extra }

/// How a booster is paid for.
enum Pay { sweets, ad }

/// Sweets prices, all in one place.
class Prices {
  static const undo = 20, peek = 30, extra = 40;

  static int of(Booster b) => switch (b) {
        Booster.undo => undo,
        Booster.peek => peek,
        Booster.extra => extra,
      };
}

/// Anything holding the player's sweets (AppState in the game).
abstract class Wallet {
  int get coins;
  void spendCoins(int n);
}

class Shop {
  /// The player can pay for [b] with sweets.
  static bool canAfford(int coins, Booster b) => coins >= Prices.of(b);

  /// Runs [apply] (the booster's effect) and charges [Prices.of] only if it
  /// took effect and was paid with sweets. Returns whether it took effect.
  /// Nothing happens if the sweets no longer cover the price.
  static bool redeem(Wallet w, Booster b, Pay pay, bool Function() apply) {
    if (pay == Pay.sweets && !canAfford(w.coins, b)) return false;
    if (!apply()) return false;
    if (pay == Pay.sweets) w.spendCoins(Prices.of(b));
    return true;
  }
}
