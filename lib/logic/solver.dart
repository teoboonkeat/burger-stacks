import 'dart:collection';

import 'board.dart';

/// Search over board states using the game's real rules ([Board.drop]).
///
/// The solver knows what every pouch hides (perfect information), but a
/// hidden bean still behaves exactly as in play: it cannot be lifted, it
/// stops a group, and it only opens once the bean above it leaves.
class Solver {
  final int maxStates;
  final int maxMoves;
  Solver({this.maxStates = 2000000, this.maxMoves = 80});

  /// Length of the shortest solution, or null if none was found within
  /// [maxStates] expansions / [maxMoves] moves.
  int? solve(Board start) => _search(start, greedy: false).moves;

  /// Whether the level can still be won from [start]: true if a solution
  /// exists, false if the whole reachable state space was searched without
  /// finding one, null if the search gave up at [maxStates].
  bool? winnable(Board start) {
    final r = _search(start, greedy: true);
    if (r.moves != null) return true;
    return r.exhausted ? false : null;
  }

  ({int? moves, bool exhausted}) _search(Board start, {required bool greedy}) {
    final b0 = start.copy()..clearUndo();
    if (b0.isWon) return (moves: 0, exhausted: false);
    // A* with an admissible boundary heuristic gives optimal lengths;
    // greedy best-first (h only) just looks for any solution quickly.
    final open = SplayTreeMap<int, List<_Node>>();
    final seen = <String, int>{};
    void push(_Node n) {
      final f = greedy ? n.h : n.g + n.h;
      (open[f] ??= []).add(n);
    }

    push(_Node(b0, 0, _h(b0)));
    seen[_key(b0)] = 0;
    var expanded = 0;
    var cut = false;
    while (open.isNotEmpty) {
      final f = open.firstKey()!;
      final bucket = open[f]!;
      final node = bucket.removeLast();
      if (bucket.isEmpty) open.remove(f);
      if (node.board.isWon) return (moves: node.g, exhausted: false);
      if (!greedy && node.g >= maxMoves) {
        cut = true;
        continue;
      }
      if (++expanded > maxStates) return (moves: null, exhausted: false);
      final b = node.board;
      for (var a = 0; a < b.tubes.length; a++) {
        final g = b.groupSize(a);
        if (g == 0) continue;
        final srcPure = g == b.tubes[a].stack.length;
        for (var c = 0; c < b.tubes.length; c++) {
          final n = b.movable(a, c);
          if (n == 0) continue;
          // Moving a whole pure stack onto an empty tube is pointless.
          if (srcPure && b.tubes[c].stack.isEmpty) continue;
          final nb = b.copy()..drop(a, c);
          final k = _key(nb);
          final prev = seen[k];
          if (prev != null && (greedy || prev <= node.g + 1)) continue;
          seen[k] = node.g + 1;
          push(_Node(nb, node.g + 1, _h(nb)));
        }
      }
    }
    return (moves: null, exhausted: !cut);
  }

  /// Each move removes at most one flavour boundary inside a tube, so the
  /// number of boundaries never overestimates the moves left.
  static int _h(Board b) {
    var h = 0;
    for (final p in b.tubes) {
      for (var i = 1; i < p.stack.length; i++) {
        if (p.stack[i].type != p.stack[i - 1].type) h++;
      }
    }
    return h;
  }

  static String _key(Board b) {
    final parts = <String>[];
    for (var i = 0; i < b.tubes.length; i++) {
      final p = b.tubes[i];
      final s = StringBuffer(b.isLocked(i) ? 'L' : '');
      for (final x in p.stack) {
        // Hidden beans are a different state: they block groups.
        s.writeCharCode((x.hidden ? 0x61 : 0x41) + x.type.index);
      }
      parts.add(s.toString());
    }
    parts.sort();
    return parts.join('|');
  }
}

class _Node {
  final Board board;
  final int g, h;
  _Node(this.board, this.g, this.h);
}
