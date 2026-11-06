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
