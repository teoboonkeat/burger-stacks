import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local save: progress, coins, settings, ad counters.
class AppState extends ChangeNotifier {
  late SharedPreferences _p;
  int currentLevel = 1;
  Map<int, int> stars = {};
  int coins = 0;
  bool removeAds = false;
  bool sound = true, music = true, haptics = true;
  /// Testing aid: every level is playable regardless of progress.
  bool unlockAll = false;
  bool dragBeans = true;
  int completedSinceAd = 0;
  int lastInterstitialMs = 0;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    currentLevel = _p.getInt('currentLevel') ?? 1;
    coins = _p.getInt('coins') ?? 0;
    removeAds = _p.getBool('removeAds') ?? false;
    sound = _p.getBool('sound') ?? true;
    music = _p.getBool('music') ?? true;
    haptics = _p.getBool('haptics') ?? true;
    unlockAll = _p.getBool('unlockAll') ?? false;
    dragBeans = _p.getBool('dragBeans') ?? true;
    completedSinceAd = _p.getInt('completedSinceAd') ?? 0;
    lastInterstitialMs = _p.getInt('lastInterstitialMs') ?? 0;
    stars = {
      for (final s in _p.getStringList('stars') ?? <String>[])
        int.parse(s.split(':')[0]): int.parse(s.split(':')[1])
    };
  }

  Future<void> save() async {
    await _p.setInt('currentLevel', currentLevel);
    await _p.setInt('coins', coins);
    await _p.setBool('removeAds', removeAds);
    await _p.setBool('sound', sound);
    await _p.setBool('music', music);
    await _p.setBool('haptics', haptics);
    await _p.setBool('unlockAll', unlockAll);
    await _p.setBool('dragBeans', dragBeans);
    await _p.setInt('completedSinceAd', completedSinceAd);
    await _p.setInt('lastInterstitialMs', lastInterstitialMs);
    await _p.setStringList(
        'stars', [for (final e in stars.entries) '${e.key}:${e.value}']);
  }

  bool isUnlocked(int level) => unlockAll || level <= currentLevel;

  void completeLevel(int level, int earnedStars, int tips, int total) {
    final prev = stars[level] ?? 0;
    if (earnedStars > prev) stars[level] = earnedStars;
    coins += tips;
    if (level >= currentLevel && level < total) currentLevel = level + 1;
    save();
    notifyListeners();
  }

  void addCoins(int n) {
    coins += n;
    save();
    notifyListeners();
  }

  void update(void Function(AppState s) f) {
    f(this);
    save();
    notifyListeners();
  }
}
