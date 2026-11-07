import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_beans/app/app_state.dart';
import 'package:jelly_beans/app/road.dart';
import 'package:jelly_beans/app/tutorial.dart';
import 'package:jelly_beans/game/jelly_game.dart';
import 'package:jelly_beans/ui/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Tutorial.load (tutorialSeen key)', () {
    test('fresh install: nothing seen', () {
      expect(Tutorial.load(null, 1), isEmpty);
    });

    test('old save without the key skips lessons of passed scoops', () {
      final seen = Tutorial.load(null, 15);
      expect(seen, containsAll([Lesson.tap, Lesson.drop, Lesson.drag,
          Lesson.undo, Lesson.group, Lesson.pouch, Lesson.peek]));
      expect(seen, isNot(contains(Lesson.lock)));
      expect(seen, isNot(contains(Lesson.extra)));
    });

    test('old save on Scoop 2 still gets the Scoop 2 lessons', () {
      final seen = Tutorial.load(null, 2);
      expect(seen, {Lesson.tap, Lesson.drop});
    });

    test('a stored list wins over the level, unknown names are dropped', () {
      expect(Tutorial.load(['tap', 'bogus', 'lock'], 50),
          {Lesson.tap, Lesson.lock});
      // Replay tutorial stores an empty list: everything shows again.
      expect(Tutorial.load([], 50), isEmpty);
    });

    test('save/load round trip', () {
      final s = {Lesson.group, Lesson.extra, Lesson.tap};
      expect(Tutorial.load(Tutorial.save(s), 1), s);
    });
  });

  group('Tutorial.atStart', () {
    const none = <Lesson>{};
    test('Scoop 1 guided move', () {
      expect(Tutorial.atStart(const LevelFacts(1), none, dragOn: true),
          [Lesson.tap]);
      expect(
          Tutorial.atStart(const LevelFacts(1), {Lesson.tap, Lesson.drop},
              dragOn: true),
          isEmpty);
    });

    test('Scoop 2 drag tip only when drag is on', () {
      expect(Tutorial.atStart(const LevelFacts(2), none, dragOn: true),
          [Lesson.drag]);
      expect(Tutorial.atStart(const LevelFacts(2), none, dragOn: false),
          isEmpty);
    });

    test('Scoop 4 groups, pouches and locks by mechanic', () {
      expect(Tutorial.atStart(const LevelFacts(4), none, dragOn: true),
          [Lesson.group]);
      expect(
          Tutorial.atStart(const LevelFacts(11, hasPouch: true), none,
              dragOn: true),
          [Lesson.pouch]);
      expect(
          Tutorial.atStart(const LevelFacts(21, hasPouch: true, hasLock: true),
              {Lesson.pouch}, dragOn: true),
          [Lesson.lock]);
      expect(
          Tutorial.atStart(const LevelFacts(21, hasPouch: true, hasLock: true),
              {Lesson.pouch, Lesson.lock}, dragOn: true),
          isEmpty);
    });

    test('existing player on Scoop 15 sees no early lesson', () {
      final seen = Tutorial.load(null, 15);
      for (final l in [1, 2, 4, 11, 15]) {
        expect(
            Tutorial.atStart(LevelFacts(l, hasPouch: l >= 11), seen,
                dragOn: true),
            isEmpty,
            reason: 'scoop $l');
      }
      expect(
          Tutorial.atStart(const LevelFacts(21, hasPouch: true, hasLock: true),
              seen, dragOn: true),
          [Lesson.lock]);
    });

    test('P6a twists: double lock, tall tubes, Big Kitchen', () {
      final early = {for (final l in Lesson.values) if (!l.isTwist) l};
      expect(
          Tutorial.atStart(const LevelFacts(41, hasLock: true, hasLock2: true),
              early, dragOn: true),
          [Lesson.lock2]);
      expect(
          Tutorial.atStart(const LevelFacts(61, tall: true), early,
              dragOn: true),
          [Lesson.tall]);
      expect(Tutorial.atStart(const LevelFacts(101), early, dragOn: true),
          [Lesson.bigKitchen]);
      expect(
          Tutorial.atStart(
              const LevelFacts(141, hasLock: true, hasLock2: true, tall: true),
              early, dragOn: true),
          [Lesson.bigKitchen, Lesson.lock2, Lesson.tall]);
      expect(
          Tutorial.atStart(const LevelFacts(141, hasLock2: true, tall: true),
              {...Lesson.values}, dragOn: true),
          isEmpty);
    });

    test('an old save past 41 still meets the twists', () {
      final seen = Tutorial.load(null, 150);
      expect(seen, contains(Lesson.lock));
      expect(seen.where((l) => l.isTwist), isEmpty);
    });

    test('event lessons', () {
      expect(Tutorial.showUndoAfterMove(2, none), isTrue);
      expect(Tutorial.showUndoAfterMove(3, none), isFalse);
      expect(Tutorial.showUndoAfterMove(2, {Lesson.undo}), isFalse);
      expect(Tutorial.showPeekOnReveal(11, true, none), isTrue);
      expect(Tutorial.showPeekOnReveal(11, true, {Lesson.peek}), isFalse);
      expect(Tutorial.showPeekOnReveal(5, true, none), isFalse);
      expect(Tutorial.showExtraInJam(none), isTrue);
      expect(Tutorial.showExtraInJam({Lesson.extra}), isFalse);
    });
  });

  test('booster bar: none on Scoop 1, Peek from 11 on pouch levels only', () {
    expect(Boosters.basic(1), isFalse);
    expect(Boosters.basic(2), isTrue);
    expect(Boosters.peek(10, true), isFalse);
    expect(Boosters.peek(11, true), isTrue);
    expect(Boosters.peek(30, false), isFalse);
  });

  group('AppState tutorialSeen', () {
    test('old save gets passed lessons marked and written back', () async {
      SharedPreferences.setMockInitialValues({'flutter.currentLevel': 15});
      final st = AppState();
      await st.load();
      expect(st.seen(Lesson.group), isTrue);
      expect(st.seen(Lesson.lock), isFalse);
      st.markSeen([Lesson.lock]);
      await st.save();
      final p = await SharedPreferences.getInstance();
      expect(p.getStringList('tutorialSeen'), contains('lock'));
      expect(p.getInt('currentLevel'), 15);
    });

    test('replay clears every lesson and survives a reload', () async {
      SharedPreferences.setMockInitialValues(
          {'flutter.currentLevel': 30, 'flutter.tutorialSeen': <String>['tap']});
      final st = AppState();
      await st.load();
      expect(st.tutorialSeen, {Lesson.tap});
      st.replayTutorial();
      await st.save();
      final again = AppState();
      await again.load();
      expect(again.tutorialSeen, isEmpty);
      expect(again.currentLevel, 30);
    });

    test('star total', () async {
      SharedPreferences.setMockInitialValues({
        'flutter.stars': <String>['1:3', '2:2', '3:1']
      });
      final st = AppState();
      await st.load();
      expect(st.starTotal, 6);
    });
  });

  test('result line never says par or overclaims', () {
    expect(resultLine(5, 5), 'Done in 5 moves · ★★★');
    expect(resultLine(4, 5), 'Done in 4 moves · ★★★');
    expect(resultLine(8, 5), 'Done in 8 moves · ★★★ needs 5 or fewer');
    expect(resultLine(5, 5), isNot(contains('par')));
  });

  test('refusal bubble sits above the tube and stays on screen', () {
    const area = Size(360, 400);
    const child = Size(200, 36);
    final mid = bubbleOrigin(const Rect.fromLTWH(150, 100, 44, 160), area, child);
    expect(mid.dx, closeTo(172 - 100, .01));
    expect(mid.dy, 100 - 36 - 4);
    final left = bubbleOrigin(const Rect.fromLTWH(4, 10, 44, 160), area, child);
    expect(left.dx, 8);
    expect(left.dy, 2);
    final right = bubbleOrigin(const Rect.fromLTWH(320, 100, 44, 160), area, child);
    expect(right.dx, 360 - 8 - 200);
  });

  test('Candy Road opens with the next scoop in view', () {
    const view = 500.0;
    expect(RoadLayout.offsetFor(1, 200, view), 0);
    for (final l in [57, 60, 100, 133]) {
      // Bottom-up: the stop's centre, measured from the bottom of the road.
      var centre = RoadLayout.bottomPad + RoadLayout.heightOf(l) / 2;
      for (var k = 1; k < l; k++) {
        centre += RoadLayout.heightOf(k);
      }
      final onScreen = centre - RoadLayout.offsetFor(l, 200, view);
      expect(onScreen, closeTo(view / 2, .01), reason: 'scoop $l');
    }
    // The top of the road: clamped to its end.
    expect(RoadLayout.offsetFor(200, 200, view),
        RoadLayout.extent(200) - view);
    expect(RoadLayout.extent(200),
        RoadLayout.pad + RoadLayout.bottomPad + 180 * 84 + 20 * 124);
    // Room below scoop 1 for the Jump to scoop chip.
    expect(RoadLayout.bottomPad, greaterThanOrEqualTo(RoadLayout.pad + 56));
  });

  test('Candy Road: signposts 10 stops before each twist, stops on screen', () {
    expect(RoadLayout.signs.keys, [31, 51, 91, 131]);
    for (var l = 1; l <= 200; l++) {
      expect(RoadLayout.xOf(l), inInclusiveRange(.2, .8));
    }
  });

  test('lock label', () {
    expect(TubeComponent.labelFor(1), 'finish\n1 tube');
    expect(TubeComponent.labelFor(2), 'finish\n2 tubes');
  });
}
