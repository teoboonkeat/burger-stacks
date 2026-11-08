/// Bean Jars (P1a): every 10 scoops fill one jar; winning the 10th, the
/// Lid scoop, seals it onto the Pantry shelf. Pure Dart (unit-tested).
library;

import '../logic/board.dart';

class Jars {
  static const size = 10;

  /// Sealing a jar pays this many sweets, plus one free Extra tube.
  static const sealPay = 50;

  /// Every [goldEvery]th jar is a gold jar and pays this on top of
  /// [sealPay].
  static const goldPay = 150;
  static const goldEvery = 5;

  /// First win of a Lid scoop pays this on top of the normal win.
  static const lidBonus = 10;

  static int count(int levels) => (levels + size - 1) ~/ size;

  /// Jar that [level] pours into (1-based).
  static int of(int level) => (level - 1) ~/ size + 1;

  static int first(int jar) => (jar - 1) * size + 1;

  /// The jar's last scoop; winning it seals the jar.
  static int lid(int jar) => jar * size;

  static bool isLid(int level) => level % size == 0;

  static bool isGold(int jar) => jar % goldEvery == 0;

  /// Sweets for sealing [jar]: 50, or 200 for a gold jar.
  static int payFor(int jar) => sealPay + (isGold(jar) ? goldPay : 0);

  /// Each jar is named after a flavour, in the game's flavour order.
  static Ingredient flavour(int jar) =>
      Ingredient.values[(jar - 1) % Ingredient.values.length];

  static String name(int jar) {
    final f = flavour(jar).name;
    return 'Jar $jar · ${f[0].toUpperCase()}${f.substring(1)}';
  }

  /// Scoops of [jar] won at least once.
  static int filled(int jar, Map<int, int> stars) {
    var n = 0;
    for (var l = first(jar); l <= lid(jar); l++) {
      if ((stars[l] ?? 0) > 0) n++;
    }
    return n;
  }

  /// Jars to treat as sealed for a save written before jars existed: every
  /// jar whose Lid scoop is already won. They are sealed silently, without
  /// back-pay.
  static Set<int> sealedFromStars(Map<int, int> stars) => {
        for (final e in stars.entries)
          if (isLid(e.key) && e.value > 0) of(e.key)
      };
}
