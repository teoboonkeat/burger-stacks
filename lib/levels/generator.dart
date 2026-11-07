import 'dart:math';

import '../logic/board.dart';
import '../logic/solver.dart';
import 'level.dart';

class Tier {
  final int ingredients, spare, minPouch, maxPouch, locked;
  /// Sealed tubes a locked spare needs before it opens (2 = double lock).
  final int lockNeed;
  const Tier(this.ingredients, this.spare, this.minPouch, this.maxPouch,
      this.locked, {this.lockNeed = 1});
}

/// Difficulty curve from the spec's progression table.
Tier tierFor(int id, Random r) {
  int pick(int a, int b) => a + r.nextInt(b - a + 1);
  if (id <= 3) return Tier(pick(2, 3), 2, 0, 0, 0);
  if (id <= 10) return Tier(pick(3, 4), 2, 0, 0, 0);
  if (id <= 20) return Tier(4, 2, id == 11 ? 1 : 1, 3, 0);
  if (id <= 30) return Tier(pick(4, 5), id == 21 ? 2 : pick(1, 2), 2, 4, 1);
  if (id <= 100) {
    final rush = id % 10 == 0;
    return Tier(rush ? 6 : pick(5, 6), rush ? 1 : 2, 3, 6, rush ? 0 : r.nextInt(2));
  }
  return const Tier(6, 2, 4, 8, 1);
}

String? hintFor(int id) => switch (id) {
      1 => 'Tap a tube to lift its top bean, then tap another tube to drop it.',
      4 => 'Matching beans on top lift together as one group.',
      11 => 'Paper pouches hide a bean until it reaches the top.',
      21 => 'A locked tube opens once you fill one tube.',
      _ => null,
    };

/// A board for scoop [id]; [tier] overrides the curve ([tierFor]), e.g.
/// for the twist boards made by tool/twists.dart.
Level? generateLevel(int id, int seed, {int capacity = 4, Tier? tier}) {
  final r = Random(seed);
  final t = tier ?? tierFor(id, r);
  final kinds = Ingredient.values.toList()..shuffle(r);
  final used = kinds.take(t.ingredients).toList();
  final pieces = [for (final k in used) for (var i = 0; i < capacity; i++) k]
    ..shuffle(r);
  final filled = <List<Ingredient>>[
    for (var p = 0; p < t.ingredients; p++)
      pieces.sublist(p * capacity, (p + 1) * capacity)
  ];
  // Reject boards with a pre-solved tube.
  if (filled.any((s) => s.every((x) => x == s.first))) return null;

  final pouchs = t.maxPouch == 0
      ? 0
      : t.minPouch + r.nextInt(t.maxPouch - t.minPouch + 1);
  // Pouchs go in lower slots (never the top).
  final slots = [
    for (var p = 0; p < filled.length; p++)
      for (var i = 0; i < capacity - 1; i++) (p, i)
  ]..sort((a, b) => a.$2.compareTo(b.$2));
  final low = slots.take(max(pouchs * 2, pouchs)).toList()..shuffle(r);
  final hidden = low.take(pouchs).toSet();

  final tubes = <TubeSpec>[
    for (var p = 0; p < filled.length; p++)
      TubeSpec([
        for (var i = 0; i < capacity; i++)
          '${hidden.contains((p, i)) ? '?' : ''}${filled[p][i].name}'
      ]),
    for (var s = 0; s < t.spare; s++)
      TubeSpec(const [], unlockAt: s < t.locked ? t.lockNeed : null),
  ];
  final draft =
      Level(id: id, capacity: capacity, par: 0, seed: seed, tubes: tubes);
  // Par is the true optimum under the game's own rules (pouches block
  // groups until uncovered), so ★★★ is always reachable.
  final par = Solver().solve(draft.toBoard());
  if (par == null || par > 60) return null;
  return Level(
      id: id,
      capacity: capacity,
      par: par,
      seed: seed,
      hint: hintFor(id),
      tubes: tubes);
}

List<Level> generateAll(int count) {
  final out = <Level>[];
  for (var id = 1; id <= count; id++) {
    for (var attempt = 0;; attempt++) {
      final l = generateLevel(id, id * 1000 + attempt);
      if (l != null) {
        out.add(l);
        break;
      }
    }
  }
  return out;
}
