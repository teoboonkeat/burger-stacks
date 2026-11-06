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

  const WinReport({
    required this.pay,
    this.lidBonus = 0,
    this.sealed,
    this.sealPay = 0,
    this.xp = 0,
    this.rankUp,
    this.rankPay = 0,
  });

  /// All sweets this win added.
  int get total => pay + sealPay + rankPay;
}
