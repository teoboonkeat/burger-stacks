import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_beans/app/app_state.dart';
import 'package:jelly_beans/app/rewards.dart';
import 'package:jelly_beans/ui/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('P5 replay pay', () {
    test('first win pays 10 + 5 per star', () {
      expect(winPay(1, 0), 15);
      expect(winPay(2, 0), 20);
      expect(winPay(3, 0), 25);
    });

    test('a replay pays only the stars it adds', () {
      expect(winPay(3, 1), 10);
      expect(winPay(3, 2), 5);
      expect(winPay(2, 1), 5);
      expect(winPay(3, 3), 0);
      expect(winPay(1, 2), 0);
    });

    test('AppState pays once, then only for better stars', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      expect(s.completeLevel(2, 2, 200), 20);
      expect(s.completeLevel(2, 2, 200), 0);
      expect(s.completeLevel(2, 3, 200), 5);
      expect(s.coins, 25);
      expect(s.stars[2], 3);
    });

    test('result note', () {
      expect(payNote(3, 0), isNull);
      expect(payNote(2, 0), 'A ★★★ win pays 25 instead of 20');
      expect(payNote(3, 2), 'Best was ★★ · +5 for the new star');
      expect(payNote(3, 1), 'Best was ★ · +10 for the new stars');
      expect(payNote(2, 2), 'Replays pay for new stars · ★★★ pays +5');
      expect(payNote(3, 3), 'Replays pay for new stars only');
    });
  });
}
