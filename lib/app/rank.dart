/// Confectioner rank (P8): one number that rises with progress. Pure Dart
/// (unit-tested).
///
/// XP is worked out from the save, never stored: first clears, stars,
/// sealed jars and Master spoons. Replays add XP only through new stars, so
/// XP can't be farmed, and existing players get their rank at once.
library;

class Rank {
  static const top = 25;

  /// Sweets for each rank gained.
  static const gift = 25;

  static const xpClear = 10, xpStar = 5, xpJar = 30, xpSpoon = 10;

  static const titles = [
    'Bean Sorter', 'Bean Counter', 'Jar Rinser', 'Lid Twister',
    'Sugar Sifter', 'Syrup Stirrer', 'Pouch Peeker', 'Flavour Finder',
    'Candy Cadet', 'Jelly Helper', 'Jelly Apprentice', 'Sugar Shaper',
    'Gumdrop Pro', 'Fizz Fixer', 'Taffy Tamer', 'Caramel Keeper',
    'Bonbon Builder', 'Toffee Master', 'Pantry Chief', 'Sweet Specialist',
    'Kitchen Captain', 'Head Candymaker', 'Sugar Sage',
    'Master Confectioner', 'Grand Confectioner',
  ];

  static int xp(
          {required int clears,
          required int stars,
          int jars = 0,
          int spoons = 0}) =>
      clears * xpClear + stars * xpStar + jars * xpJar + spoons * xpSpoon;

  /// XP needed to reach rank [n] (rank 1 is where everyone starts).
  static int threshold(int n) => n <= 1 ? 0 : 15 * n * (n + 1) ~/ 2;

  static int of(int xp) {
    var n = 1;
    while (n < top && xp >= threshold(n + 1)) {
      n++;
    }
    return n;
  }

  static String title(int rank) => titles[rank.clamp(1, top) - 1];
}
