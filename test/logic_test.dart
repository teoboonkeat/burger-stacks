import 'package:jelly_beans/ads/ad_policy.dart';
import 'package:jelly_beans/logic/board.dart';
import 'package:jelly_beans/logic/solver.dart';
import 'package:flutter_test/flutter_test.dart';

Piece p(Ingredient t, {bool h = false}) => Piece(t, hidden: h);
const pa = Ingredient.berry, ch = Ingredient.peach, to = Ingredient.lime;

void main() {
  test('grouped pickup lifts identical run', () {
    final b = Board([Tube([p(ch), p(pa), p(pa)]), Tube([])]);
    expect(b.groupSize(0), 2);
    b.drop(0, 1);
    expect(b.tubes[1].stack.length, 2);
    expect(b.tubes[0].stack.length, 1);
  });

  test('drop moves only as many as fit', () {
    final b = Board([Tube([p(pa), p(pa), p(pa)]), Tube([p(ch), p(ch), p(pa)])]);
    final m = b.drop(0, 1)!;
    expect(m.count, 1);
    expect(b.tubes[0].stack.length, 2);
  });

  test('invalid drop on mismatched top', () {
    final b = Board([Tube([p(pa)]), Tube([p(ch)])]);
    expect(b.drop(0, 1), isNull);
  });

  test('pouch revealed when it reaches top', () {
    final b = Board([Tube([p(ch, h: true), p(pa)]), Tube([])]);
    expect(b.tubes[0].stack.first.hidden, isTrue);
    b.drop(0, 1);
    expect(b.tubes[0].top!.hidden, isFalse);
    b.undo();
    expect(b.tubes[0].stack.first.hidden, isTrue);
  });

  test('undo after Peek does not close the pouch again', () {
    final b = Board([Tube([p(ch, h: true), p(to, h: true), p(pa)]), Tube([])]);
    b.drop(0, 1); // uncovers the lime
    b.revealAll(); // Peek
    expect(b.tubes[0].stack.every((x) => !x.hidden), isTrue);
    b.undo();
    expect(b.tubes[0].stack.every((x) => !x.hidden), isTrue);
    expect(b.tubes[0].top!.type, pa);
  });

  test('covered pouch cannot be picked up', () {
    final b = Board([Tube([p(ch), p(pa)])]);
    b.tubes[0].stack.last.hidden = true;
    expect(b.canPick(0), isFalse);
  });

  test('complete tube seals and win detection', () {
    final b = Board([Tube([p(pa), p(pa), p(pa)]), Tube([p(pa)])]);
    final m = b.drop(1, 0)!;
    expect(m.sealedTarget, isTrue);
    expect(b.tubes[0].sealed, isTrue);
    expect(b.canPick(0), isFalse);
    expect(b.isWon, isTrue);
  });

  test('locked tube opens after N completes', () {
    final b = Board([
      Tube([p(pa), p(pa), p(pa)]),
      Tube([p(ch), p(pa)]),
      Tube([], unlockAt: 1),
    ]);
    expect(b.movable(1, 2), 0);
    b.drop(1, 0);
    expect(b.isLocked(2), isFalse);
    expect(b.movable(1, 2), 1);
  });

  test('stars', () {
    expect(starsFor(10, 10), 3);
    expect(starsFor(12, 10), 2);
    expect(starsFor(13, 10), 1);
    expect(starsFor(20, 17), 2);
    expect(starsFor(21, 17), 1);
    expect(starsFor(4, 3), 2);
    expect(starsFor(5, 3), 1);
  });

  test('stuck when no valid move', () {
    final b = Board([
      Tube([p(pa), p(ch), p(pa), p(ch)]),
      Tube([p(ch), p(pa), p(ch), p(pa)])
    ]);
    expect(b.isStuck, isTrue);
  });

  test('undo restores state', () {
    final b = Board([Tube([p(to), p(pa)]), Tube([])]);
    b.drop(0, 1);
    b.undo();
    expect(b.tubes[0].stack.length, 2);
    expect(b.tubes[1].stack, isEmpty);
    expect(b.canUndo, isFalse);
  });

  test('solver finds shortest simple solution', () {
    final b = Board([
      Tube([p(pa), p(pa), p(ch), p(ch)]),
      Tube([p(ch), p(ch), p(pa), p(pa)]),
      Tube([]),
    ]);
    expect(Solver().solve(b), 3);
  });

  test('solver: a hidden bean blocks the group under real rules', () {
    // Revealed, the two berries would lift together (2 moves); with the
    // lower one in a pouch the berries must come off one at a time.
    final b = Board([
      Tube([p(ch), p(ch), p(pa, h: true), p(pa)]),
      Tube([p(pa), p(pa), p(ch), p(ch)]),
      Tube([]),
    ]);
    expect(Solver().solve(b), 4);
    final open = b.copy()..revealAll();
    expect(Solver().solve(open), 3);
  });

  test('solver: winnable is false when no win is reachable', () {
    final b = Board([
      Tube([p(pa), p(ch), p(pa), p(ch)]),
      Tube([p(ch), p(pa), p(ch), p(pa)]),
      Tube([p(to), p(to)]),
      Tube([p(to)]),
    ]);
    expect(b.hasValidMove, isTrue);
    expect(Solver().winnable(b), isFalse);
  });

  test('ad policy caps', () {
    bool f({int level = 20, int since = 3, int now = 200000, bool r = false, bool ra = false}) =>
        AdPolicy.shouldShowInterstitial(
            level: level, completedSinceAd: since, nowMs: now, lastMs: 0, restarted: r, removeAds: ra);
    expect(f(), isTrue);
    expect(f(level: 10), isFalse);
    expect(f(since: 2), isFalse);
    expect(f(now: 50000), isFalse);
    expect(f(r: true), isFalse);
    expect(f(ra: true), isFalse);
  });
}
