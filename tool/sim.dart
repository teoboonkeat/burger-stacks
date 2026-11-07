// A simulated casual player, for checking difficulty when level data
// changes. It sees only open beans (no lookahead, no undo) and prefers
// moves that seal a tube or stack on a matching bean, with some slips.
import 'dart:math';

import 'package:jelly_beans/levels/level.dart';
import 'package:jelly_beans/logic/board.dart';

class SimPlayer {
  /// Chance of picking a random valid move instead of the best-looking one.
  final double slip;
  const SimPlayer({this.slip = .25});

  /// Moves to win, or null when the run got stuck or went on too long.
  int? play(Board start, Random r, int par) {
    final b = start.copy()..clearUndo();
    var moves = 0;
    (int, int)? last;
    while (!b.isWon) {
      if (moves > par * 3) return null;
      final options = <(int, int, double)>[];
      for (var a = 0; a < b.tubes.length; a++) {
        final g = b.groupSize(a);
        if (g == 0) continue;
        final src = b.tubes[a].stack;
        final pure = g == src.length;
        for (var c = 0; c < b.tubes.length; c++) {
          final n = b.movable(a, c);
          if (n == 0) continue;
          final dst = b.tubes[c].stack;
          if (pure && dst.isEmpty) continue;
          var score = 0.0;
          if (dst.isNotEmpty) score += 4;
          if (dst.isEmpty) score -= 1;
          if (dst.length + n == b.capacity &&
              dst.every((x) => x.type == src.last.type)) {
            score += 10;
          }
          if (n == g) score += 1.5;
          if (n == g && g < src.length) score += 1; // uncovers something
          if (last == (c, a)) score -= 8;
          options.add((a, c, score + r.nextDouble()));
        }
      }
      if (options.isEmpty) return null;
      final pick = r.nextDouble() < slip
          ? options[r.nextInt(options.length)]
          : options.reduce((x, y) => x.$3 >= y.$3 ? x : y);
      b.drop(pick.$1, pick.$2);
      last = (pick.$1, pick.$2);
      moves++;
    }
    return moves;
  }

  /// Share of [runs] runs won on [l].
  double winRate(Level l, {int runs = 100, int seed = 1}) {
    final r = Random(seed);
    final b = l.toBoard();
    var won = 0;
    for (var i = 0; i < runs; i++) {
      if (play(b, r, l.par) != null) won++;
    }
    return won / runs;
  }
}
