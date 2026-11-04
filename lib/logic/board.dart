/// Pure-Dart puzzle rules for Jelly Beans. No Flutter imports.
library;

enum Ingredient { berry, peach, lime, grape, lemon, cola }

Ingredient ingredientFromKey(String k) =>
    Ingredient.values.firstWhere((i) => i.name == k,
        orElse: () => throw FormatException('Unknown ingredient "$k"'));

class Piece {
  final Ingredient type;
  bool hidden;
  Piece(this.type, {this.hidden = false});
  Piece copy() => Piece(type, hidden: hidden);
  @override
  String toString() => '${hidden ? '?' : ''}${type.name}';
}

class Tube {
  final List<Piece> stack;
  /// Tubes needed complete before this one opens; null = never locked.
  final int? unlockAt;
  bool sealed = false;
  Tube(this.stack, {this.unlockAt});
  Tube copy() => Tube(stack.map((p) => p.copy()).toList(), unlockAt: unlockAt)
    ..sealed = sealed;
  Piece? get top => stack.isEmpty ? null : stack.last;
}

class Move {
  final int from, to, count;
  /// Pieces revealed in `from` as a result of this move (for undo).
  final bool revealed;
  /// Whether `to` got sealed by this move.
  final bool sealedTarget;
  const Move(this.from, this.to, this.count, this.revealed, this.sealedTarget);
}

enum DropResult { moved, invalid }

class Board {
  final int capacity;
  final List<Tube> tubes;
  final List<Move> _undo = [];
  /// Set once every pouch has been opened by Peek; undo then never closes
  /// a pouch again.
  bool peeked = false;

  Board(this.tubes, {this.capacity = 4}) {
    for (final p in tubes) {
      _revealTop(p);
      if (_isComplete(p)) p.sealed = true;
    }
  }

  Board copy() => Board(tubes.map((p) => p.copy()).toList(), capacity: capacity)
    ..peeked = peeked;

  int get completeCount => tubes.where((p) => p.sealed).length;
  int get undoDepth => _undo.length;

  bool isLocked(int i) {
    final u = tubes[i].unlockAt;
    return u != null && completeCount < u;
  }

  bool _isComplete(Tube p) =>
      p.stack.length == capacity &&
      p.stack.every((x) => x.type == p.stack.first.type);

  bool _revealTop(Tube p) {
    final t = p.top;
    if (t != null && t.hidden) {
      t.hidden = false;
      return true;
    }
    return false;
  }

  bool get isWon => tubes.every((p) => p.stack.isEmpty || p.sealed);

  /// Size of the group lifted from tube [i] (0 if it can't be picked up).
  int groupSize(int i) {
    final p = tubes[i];
    if (p.sealed || isLocked(i) || p.stack.isEmpty) return 0;
    final t = p.top!;
    if (t.hidden) return 0;
    var n = 0;
    for (var k = p.stack.length - 1; k >= 0; k--) {
      final x = p.stack[k];
      if (x.hidden || x.type != t.type) break;
      n++;
    }
    return n;
  }

  bool canPick(int i) => groupSize(i) > 0;

  /// How many pieces would move from [from] to [to]; 0 means invalid.
  int movable(int from, int to) {
    if (from == to) return 0;
    final g = groupSize(from);
    if (g == 0) return 0;
    final t = tubes[to];
    if (t.sealed || isLocked(to)) return 0;
    final free = capacity - t.stack.length;
    if (free <= 0) return 0;
    if (t.stack.isNotEmpty && t.top!.type != tubes[from].top!.type) return 0;
    return g < free ? g : free;
  }

  Move? drop(int from, int to) {
    final n = movable(from, to);
    if (n == 0) return null;
    final src = tubes[from], dst = tubes[to];
    final moved = src.stack.sublist(src.stack.length - n);
    src.stack.removeRange(src.stack.length - n, src.stack.length);
    dst.stack.addAll(moved);
    final revealed = _revealTop(src);
    var sealedNow = false;
    if (_isComplete(dst)) {
      dst.sealed = true;
      sealedNow = true;
    }
    final m = Move(from, to, n, revealed, sealedNow);
    _undo.add(m);
    return m;
  }

  bool get canUndo => _undo.isNotEmpty;

  Move? undo() {
    if (_undo.isEmpty) return null;
    final m = _undo.removeLast();
    final src = tubes[m.from], dst = tubes[m.to];
    if (m.sealedTarget) dst.sealed = false;
    if (m.revealed && !peeked) src.top!.hidden = true;
    final moved = dst.stack.sublist(dst.stack.length - m.count);
    dst.stack.removeRange(dst.stack.length - m.count, dst.stack.length);
    src.stack.addAll(moved);
    return m;
  }

  bool get hasValidMove {
    for (var a = 0; a < tubes.length; a++) {
      if (!canPick(a)) continue;
      for (var b = 0; b < tubes.length; b++) {
        if (movable(a, b) > 0) return true;
      }
    }
    return false;
  }

  bool get isStuck => !isWon && !hasValidMove;

  void revealAll() {
    peeked = true;
    for (final p in tubes) {
      for (final x in p.stack) {
        x.hidden = false;
      }
    }
  }

  void addTube() => tubes.add(Tube([]));

  void clearUndo() => _undo.clear();
}

int starsFor(int moves, int par) {
  if (moves <= par) return 3;
  if (moves <= par * 1.5) return 2;
  return 1;
}
