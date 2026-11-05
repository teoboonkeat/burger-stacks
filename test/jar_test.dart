import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_beans/logic/board.dart';
import 'package:jelly_beans/ui/widgets.dart';

void main() {
  test('jar packs every bean inside the glass for 1 to 10 finished tubes', () {
    // Inner rect of a 170-wide jar, as JarPainter computes it.
    const w = 170.0, h = w * 1.15;
    final inner = Rect.fromLTWH(w * .06, h * .2, w * .88, h * .78).deflate(w * .05);
    for (var tubes = 1; tubes <= 10; tubes++) {
      final beans = List.filled(tubes * 4, Ingredient.berry);
      final (bw, placed) = JarPainter.pack(inner, beans, inner.top + h * .04);
      expect(placed.length, beans.length, reason: '$tubes tubes');
      final bh = bw * 40 / 52;
      for (final (p, _, _) in placed) {
        expect(p.dx - bw / 2, greaterThanOrEqualTo(inner.left - bw * .3), reason: '$tubes tubes');
        expect(p.dx + bw / 2, lessThanOrEqualTo(inner.right + bw * .3), reason: '$tubes tubes');
        expect(p.dy - bh / 2, greaterThanOrEqualTo(inner.top), reason: '$tubes tubes');
      }
    }
  });
}
