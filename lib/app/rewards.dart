/// What a win pays. Pure Dart (unit-tested).
library;

/// Sweets for a first win: 10 plus 5 per star (15 / 20 / 25).
int sweetsFor(int stars) => 10 + stars * 5;

/// Sweets for winning a scoop with [stars] when its best so far is [best]
/// (0 = never won). The first win pays [sweetsFor]; a replay pays only the
/// stars it adds, +5 each, so replays can't be farmed.
int winPay(int stars, int best) {
  if (best == 0) return sweetsFor(stars);
  return stars > best ? (stars - best) * 5 : 0;
}

/// Master spoons (P10): a gold spoon for winning a scoop you have already
/// cleared at par with no help at all (no Undo, not even the free one, no
/// Peek, no Extra tube). Only on a replay, so the pouches are known, as
/// the solver that sets par knows them.
class Spoons {
  /// First gold spoon on a scoop.
  static const pay = 10;

  /// All 10 spoons of a jar: its jar gets a gold rim on the shelf.
  static const jarPay = 50;

  static bool earns({required int best, required int stars, required bool helped}) =>
      best > 0 && stars == 3 && !helped;

  /// Result-card line about the spoon, or null when there is nothing to say.
  static String? note(
      {required int best,
      required int stars,
      required bool helped,
      required bool earned,
      required bool had}) {
    if (earned) return 'Gold spoon · +$pay sweets';
    if (stars < 3 || had) return null;
    if (best == 0) return 'Next time, win ★★★ with no help to earn a gold spoon';
    return helped ? 'A gold spoon needs no Undo, Peek or Extra tube' : null;
  }
}

/// Everything one win paid, for the result card.
class WinReport {
  /// The win itself ([winPay]) plus the Lid bonus: what the ×2 ad doubles.
  final int pay;

  /// Part of [pay] that is the Lid scoop bonus.
  final int lidBonus;

  /// Jar sealed by this win, if any, and what sealing it paid.
  final int? sealed;
  final int sealPay;

  /// Rank XP this win added.
  final int xp;

  /// New rank reached by this win, if any, and its gift.
  final int? rankUp;
  final int rankPay;

  /// A gold spoon won by this win, what it paid, and the jar whose 10th
  /// spoon it was, if any.
  final bool spoon;
  final int spoonPay;
  final int? spoonJar;

  const WinReport({
    required this.pay,
    this.lidBonus = 0,
    this.sealed,
    this.sealPay = 0,
    this.xp = 0,
    this.rankUp,
    this.rankPay = 0,
    this.spoon = false,
    this.spoonPay = 0,
    this.spoonJar,
  });

  /// All sweets this win added.
  int get total => pay + sealPay + rankPay + spoonPay;
}
