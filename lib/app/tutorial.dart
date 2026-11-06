/// Tutorial lessons and when they show. Pure Dart (unit-tested).
library;

/// One concept taught once. The enum name is what goes in the save
/// (`tutorialSeen`, a string list).
enum Lesson {
  /// Scoop 1: tap a tube; its top bean lifts.
  tap(1),
  /// Scoop 1: tap an empty tube to drop it.
  drop(1),
  /// Scoop 2: beans can be dragged too (tip, only when drag is on).
  drag(2),
  /// Scoop 2, after the first move: the Undo booster.
  undo(2),
  /// Scoop 4: a run of matching beans moves as one group.
  group(4),
  /// First scoop with pouches (11): what a pouch is.
  pouch(11),
  /// First pouch opened (11): the Peek booster.
  peek(11),
  /// First Sticky jam: what Extra tube does. Not tied to a scoop.
  extra(null),
  /// First scoop with a locked tube (21).
  lock(21),
  /// P6a twists. First board with a double lock (41).
  lock2(41),
  /// First board with tall, 5-bean tubes (61).
  tall(61),
  /// The Big Kitchen stage starts (101).
  bigKitchen(101);

  /// Scoop where the lesson first appears in level order; null when it
  /// depends on play (a Sticky jam can happen anywhere).
  final int? level;
  const Lesson(this.level);

  /// Added with the P6a twists (save keys from before them have none).
  bool get isTwist => index > Lesson.lock.index;

  static Lesson? byName(String s) {
    for (final l in values) {
      if (l.name == s) return l;
    }
    return null;
  }
}

/// Facts about the level being started that decide its lessons.
class LevelFacts {
  final int level;
  final bool hasPouch;
  final bool hasLock;
  /// A lock that needs 2 or more sealed tubes.
  final bool hasLock2;
  /// Tubes hold more than 4 beans.
  final bool tall;
  const LevelFacts(this.level,
      {this.hasPouch = false,
      this.hasLock = false,
      this.hasLock2 = false,
      this.tall = false});
}

class Tutorial {
  /// Seen set read from the save. [stored] is the saved list, or null when
  /// the key has never been written (a save from before the tutorial).
  /// Such players skip every lesson for a scoop they have already passed,
  /// except the twists, which they meet on boards that are new to them.
  static Set<Lesson> load(List<String>? stored, int currentLevel) {
    if (stored != null) {
      return {for (final s in stored) ?Lesson.byName(s)};
    }
    return {
      for (final l in Lesson.values)
        if (l.level != null && l.level! < currentLevel && !l.isTwist) l
    };
  }

  static List<String> save(Set<Lesson> seen) =>
      [for (final l in Lesson.values) if (seen.contains(l)) l.name];

  /// Lessons to start when [f] begins, in order. Lessons that wait for an
  /// event (undo after the first move, peek after a pouch opens, extra in
  /// a Sticky jam) are not listed here; see [showUndoAfterMove],
  /// [showPeekOnReveal] and [showExtraInJam].
  static List<Lesson> atStart(LevelFacts f, Set<Lesson> seen,
      {required bool dragOn}) {
    bool want(Lesson l) => !seen.contains(l);
    return [
      if (f.level == 1 && (want(Lesson.tap) || want(Lesson.drop))) Lesson.tap,
      if (f.level == 2 && dragOn && want(Lesson.drag)) Lesson.drag,
      if (f.level == 4 && want(Lesson.group)) Lesson.group,
      if (f.hasPouch && want(Lesson.pouch)) Lesson.pouch,
      if (f.level >= Lesson.bigKitchen.level! && want(Lesson.bigKitchen))
        Lesson.bigKitchen,
      if (f.hasLock2 && want(Lesson.lock2))
        Lesson.lock2
      else if (f.hasLock && want(Lesson.lock))
        Lesson.lock,
      if (f.tall && want(Lesson.tall)) Lesson.tall,
    ];
  }

  static bool showUndoAfterMove(int level, Set<Lesson> seen) =>
      level == 2 && !seen.contains(Lesson.undo);

  static bool showPeekOnReveal(int level, bool levelHasPouch, Set<Lesson> seen) =>
      Boosters.peek(level, levelHasPouch) && !seen.contains(Lesson.peek);

  static bool showExtraInJam(Set<Lesson> seen) => !seen.contains(Lesson.extra);
}

/// Which boosters the bar shows. A booster appears once it has been
/// taught, and only where it can help; the bar keeps its height either way.
class Boosters {
  /// Undo and Extra tube from Scoop 2 (Scoop 1 is the guided tutorial).
  static bool basic(int level) => level >= 2;

  /// Peek from Scoop 11, and only on levels that start with pouches.
  static bool peek(int level, bool levelHasPouch) =>
      level >= Lesson.peek.level! && levelHasPouch;
}
