/// Candy Road (P7): the level list as a winding road, scoop 1 at the
/// bottom. Pure layout maths (unit-tested); drawn by ui/road_screen.dart.
library;

import 'dart:math';

import 'chapters.dart';

class RoadLayout {
  /// Height of one stop's row, and of a Lid scoop's (a jar landmark).
  static const rowH = 84.0, lidH = 124.0;

  /// Space above the last stop.
  static const pad = 24.0;

  /// Space below the first stop: [pad] plus room for the floating
  /// "Jump to scoop" chip, so it never covers scoop 1.
  static const bottomPad = pad + 60.0;

  static double heightOf(int level) => Jars.isLid(level) ? lidH : rowH;

  /// Horizontal centre of [level]'s stop as a share of the width: the
  /// road swings left and right, one full swing every 8 stops.
  static double xOf(int level) => .5 + .28 * sin(level * pi / 4);

  /// Total scrollable height of a road of [count] stops.
  static double extent(int count) {
    var h = pad + bottomPad;
    for (var l = 1; l <= count; l++) {
      h += heightOf(l);
    }
    return h;
  }

  /// Scroll offset of a bottom-up road (offset 0 shows scoop 1) that puts
  /// [level]'s stop in the middle of a [viewH] high view, clamped.
  static double offsetFor(int level, int count, double viewH) {
    var below = bottomPad;
    for (var l = 1; l < level; l++) {
      below += heightOf(l);
    }
    final want = below + heightOf(level) / 2 - viewH / 2;
    return want.clamp(0.0, max(0.0, extent(count) - viewH));
  }

  /// Signposts 10 stops before each P6a twist, and what they say.
  static const signs = {
    31: ('New ahead', 'Double lock · 41'),
    51: ('New ahead', 'Tall tubes · 61'),
    91: ('Ahead', 'Big Kitchen · 101'),
    131: ('New ahead', 'Tall tubes + double lock · 141'),
  };
}
