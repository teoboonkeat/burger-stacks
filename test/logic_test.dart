import 'package:burger_stacks/ads/ad_policy.dart';
import 'package:burger_stacks/logic/board.dart';
import 'package:burger_stacks/logic/solver.dart';
import 'package:flutter_test/flutter_test.dart';

Piece p(Ingredient t, {bool h = false}) => Piece(t, hidden: h);
const pa = Ingredient.patty, ch = Ingredient.cheese, to = Ingredient.tomato;

void main() {
  test('grouped pickup lifts identical run', () {
    final b = Board([Plate([p(ch), p(pa), p(pa)]), Plate([])]);
    expect(b.groupSize(0), 2);
    b.drop(0, 1);
    expect(b.plates[1].stack.length, 2);
    expect(b.plates[0].stack.length, 1);
  });

  test('drop moves only as many as fit', () {
    final b = Board([Plate([p(pa), p(pa), p(pa)]), Plate([p(ch), p(ch), p(pa)])]);
    final m = b.drop(0, 1)!;
    expect(m.count, 1);
    expect(b.plates[0].stack.length, 2);
  });

  test('invalid drop on mismatched top', () {
    final b = Board([Plate([p(pa)]), Plate([p(ch)])]);
    expect(b.drop(0, 1), isNull);
  });

  test('cloche revealed when it reaches top', () {
    final b = Board([Plate([p(ch, h: true), p(pa)]), Plate([])]);
    expect(b.plates[0].stack.first.hidden, isTrue);
    b.drop(0, 1);
    expect(b.plates[0].top!.hidden, isFalse);
    b.undo();
    expect(b.plates[0].stack.first.hidden, isTrue);
  });

  test('covered cloche cannot be picked up', () {
    final b = Board([Plate([p(ch), p(pa)])]);
    b.plates[0].stack.last.hidden = true;
    expect(b.canPick(0), isFalse);
  });

  test('complete plate seals and win detection', () {
    final b = Board([Plate([p(pa), p(pa), p(pa)]), Plate([p(pa)])]);
    final m = b.drop(1, 0)!;
    expect(m.sealedTarget, isTrue);
    expect(b.plates[0].sealed, isTrue);
    expect(b.canPick(0), isFalse);
    expect(b.isWon, isTrue);
  });

  test('locked plate opens after N completes', () {
    final b = Board([
      Plate([p(pa), p(pa), p(pa)]),
      Plate([p(ch), p(pa)]),
      Plate([], unlockAt: 1),
    ]);
    expect(b.movable(1, 2), 0);
    b.drop(1, 0);
    expect(b.isLocked(2), isFalse);
    expect(b.movable(1, 2), 1);
  });

  test('stars', () {
    expect(starsFor(10, 10), 3);
    expect(starsFor(15, 10), 2);
    expect(starsFor(16, 10), 1);
  });

  test('stuck when no valid move', () {
    final b = Board([
      Plate([p(pa), p(ch), p(pa), p(ch)]),
      Plate([p(ch), p(pa), p(ch), p(pa)])
    ]);
    expect(b.isStuck, isTrue);
  });

  test('undo restores state', () {
    final b = Board([Plate([p(to), p(pa)]), Plate([])]);
    b.drop(0, 1);
    b.undo();
    expect(b.plates[0].stack.length, 2);
    expect(b.plates[1].stack, isEmpty);
    expect(b.canUndo, isFalse);
  });

  test('solver finds shortest simple solution', () {
    final b = Board([
      Plate([p(pa), p(pa), p(ch), p(ch)]),
      Plate([p(ch), p(ch), p(pa), p(pa)]),
      Plate([]),
    ]);
    expect(Solver().solve(b), 3);
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
