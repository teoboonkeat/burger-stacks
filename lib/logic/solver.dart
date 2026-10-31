import 'dart:collection';

import 'board.dart';

/// Search over board states with cloches treated as known.
/// Returns the solution length or null if none found within [maxStates].
class Solver {
  final int maxStates;
  final int maxMoves;
  Solver({this.maxStates = 400000, this.maxMoves = 60});

  int? solve(Board start) {
    final b0 = start.copy()..revealAll();
    b0.clearUndo();
    if (b0.isWon) return 0;
    // A* with a boundary heuristic; returns optimal-or-near-optimal lengths.
    final open = SplayTreeMap<int, List<_Node>>();
    final seen = <String, int>{};
    void push(_Node n) {
      final f = n.g + n.h;
      (open[f] ??= []).add(n);
    }

    push(_Node(b0, 0, _h(b0)));
    seen[_key(b0)] = 0;
    var expanded = 0;
    while (open.isNotEmpty) {
      final f = open.firstKey()!;
      final bucket = open[f]!;
      final node = bucket.removeLast();
      if (bucket.isEmpty) open.remove(f);
      if (node.board.isWon) return node.g;
      if (node.g >= maxMoves) continue;
      if (++expanded > maxStates) return null;
      final b = node.board;
      for (var a = 0; a < b.plates.length; a++) {
        final g = b.groupSize(a);
        if (g == 0) continue;
        final srcPure = g == b.plates[a].stack.length;
        for (var c = 0; c < b.plates.length; c++) {
          final n = b.movable(a, c);
          if (n == 0) continue;
          // Moving a whole pure stack onto an empty plate is pointless.
          if (srcPure && b.plates[c].stack.isEmpty) continue;
          final nb = b.copy()..drop(a, c);
          final k = _key(nb);
          final prev = seen[k];
          if (prev != null && prev <= node.g + 1) continue;
          seen[k] = node.g + 1;
          push(_Node(nb, node.g + 1, _h(nb)));
        }
      }
    }
    return null;
  }

  static int _h(Board b) {
    var h = 0;
    for (final p in b.plates) {
      for (var i = 1; i < p.stack.length; i++) {
        if (p.stack[i].type != p.stack[i - 1].type) h++;
      }
    }
    return h;
  }

  static String _key(Board b) {
    final parts = <String>[];
    for (var i = 0; i < b.plates.length; i++) {
      final p = b.plates[i];
      final s = StringBuffer(b.isLocked(i) ? 'L' : '');
      for (final x in p.stack) {
        s.write(x.type.index);
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
