import 'package:flutter_test/flutter_test.dart';
import 'package:jelly_beans/app/app_state.dart';
import 'package:jelly_beans/app/rank.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('P8 rank', () {
    test('thresholds from the proposal', () {
      expect(Rank.threshold(10), 825);
      expect(Rank.threshold(20), 3150);
      expect(Rank.threshold(25), 4875);
      expect(Rank.of(0), 1);
      expect(Rank.of(1060), 11);
      expect(Rank.title(11), 'Jelly Apprentice');
      expect(Rank.title(12), 'Sugar Shaper');
      expect(Rank.of(99999), Rank.top);
      expect(Rank.titles.length, Rank.top);
    });

    test('XP: clears, stars, jars, spoons', () {
      expect(Rank.xp(clears: 2, stars: 5, jars: 1, spoons: 1),
          20 + 25 + 30 + 10);
    });

    test('casual player (1.5 stars, with jars) is about rank 11 by 50', () {
      final xp = Rank.xp(clears: 50, stars: 75, jars: 5);
      expect(Rank.of(xp), inInclusiveRange(10, 12));
    });

    test('a rank-up pays 25 per rank, once; replays add no XP', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppState();
      await s.load();
      final r = s.completeLevel(1, 3, 200); // rank 2 needs 45 XP
      expect(r.xp, 25);
      expect(s.rank, 1);
      final r2 = s.completeLevel(2, 3, 200);
      expect(r2.xp, 25);
      expect(s.rank, 2);
      expect(r2.rankUp, 2);
      expect(r2.rankPay, Rank.gift);
      expect(s.completeLevel(2, 3, 200).xp, 0);
      expect(s.completeLevel(2, 3, 200).rankUp, isNull);
    });

    test('an old save gets its rank with no back-pay', () async {
      SharedPreferences.setMockInitialValues({
        'currentLevel': 51,
        'coins': 7,
        'stars': [for (var l = 1; l <= 50; l++) '$l:2'],
      });
      final s = AppState();
      await s.load();
      expect(s.rank, greaterThan(5));
      expect(s.rankPaid, s.rank);
      expect(s.coins, 7);
    });
  });
}
