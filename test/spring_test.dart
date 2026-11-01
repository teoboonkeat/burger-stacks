import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_beans/game/spring.dart';

void main() {
  test('spring settles on target at normal frame rate', () {
    final s = Spring()..velocity = 900;
    for (var i = 0; i < 120; i++) {
      s.update(1 / 60, 18);
    }
    expect(s.value, closeTo(18, .5));
  });

  test('spring stays bounded through long frames', () {
    for (final dt in [.1, .3, 2.0, 30.0]) {
      final s = Spring()..velocity = 900;
      for (var i = 0; i < 200; i++) {
        s.update(dt, i.isEven ? 18 : 0);
        expect(s.value.abs(), lessThan(60), reason: 'dt=$dt frame $i');
      }
    }
  });
}
