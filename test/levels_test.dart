import 'dart:convert';
import 'dart:io';

import 'package:jelly_beans/levels/level.dart';
import 'package:jelly_beans/logic/board.dart';
import 'package:jelly_beans/logic/solver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final levels = parseLevels(
      jsonDecode(File('assets/levels/levels.json').readAsStringSync()) as List);

  test('200 levels', () => expect(levels.length, 200));

  test('every ingredient appears exactly capacity times', () {
    for (final l in levels) {
      final counts = <String, int>{};
      for (final p in l.tubes) {
        for (final k in p.stack) {
          final key = k.replaceFirst('?', '');
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
      expect(counts.values.every((c) => c == l.capacity), isTrue,
          reason: 'level ${l.id}');
    }
  });

  test('every level is solvable and par equals the real-rules optimum', () {
    // Solver plays by Board.drop: pouches block groups until uncovered.
    for (final l in levels) {
      expect(l.toBoard().isWon, isFalse, reason: 'level ${l.id}');
      final n = Solver().solve(l.toBoard());
      expect(n, isNotNull, reason: 'level ${l.id}');
      expect(l.par, n, reason: 'level ${l.id} par');
    }
  });

  group('level 28 soft dead end (play-test s09)', () {
    // The tester's line: afterwards only a lone bean can shuttle between
    // two tubes, so the level can't be won although moves remain.
    Board deadEnd() {
      final b = levels[27].toBoard();
      for (final (a, c) in [(1, 5), (2, 1), (0, 2), (0, 5), (3, 5), (3, 0)]) {
        expect(b.drop(a, c), isNotNull, reason: '$a>$c');
      }
      return b;
    }

    test('is detected as unwinnable although moves remain', () {
      final b = deadEnd();
      expect(b.hasValidMove, isTrue);
      expect(b.isStuck, isFalse);
      expect(Solver(maxStates: 5000).winnable(b), isFalse);
    });

    test('one move earlier the level is still winnable', () {
      final b = deadEnd()..undo();
      expect(Solver(maxStates: 5000).winnable(b), isTrue);
    });

    test('an extra tube gets the player out', () {
      final b = deadEnd()..addTube();
      expect(Solver(maxStates: 5000).winnable(b), isTrue);
    });
  });
}
