import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'chapters.dart';
import 'rank.dart';
import 'rewards.dart';
import 'shop.dart';
import 'tutorial.dart';

/// Local save: progress, coins (shown as "sweets"), settings, ad counters.
class AppState extends ChangeNotifier implements Wallet {
  late SharedPreferences _p;
  int currentLevel = 1;
  Map<int, int> stars = {};
  @override
  int coins = 0;
  bool removeAds = false;
  bool sound = true, music = true, haptics = true;
  /// Testing aid: every level is playable regardless of progress.
  bool unlockAll = false;
  bool dragBeans = true;
  int completedSinceAd = 0;
  int lastInterstitialMs = 0;
  /// Tutorial lessons already shown (save key `tutorialSeen`).
  Set<Lesson> tutorialSeen = {};
  /// Jars on the Pantry shelf (save key `jarsSealed`). A save from before
  /// jars gets every jar whose Lid scoop is won, without back-pay.
  Set<int> jarsSealed = {};
  /// Free boosters won as rewards, used before paying (`boosterStock`).
  Map<Booster, int> boosterStock = {};
  /// Highest rank whose gift is paid (`rankPaid`). A save from before ranks
  /// starts at its current rank, so there is no back-pay.
  int rankPaid = 1;
  /// Scoops with a gold Master spoon (`spoons`). Starts empty: past runs
  /// did not record whether help was used.
  Set<int> spoons = {};
  /// Candy Road stop the marker was last drawn at (`roadSeen`), so it
  /// walks to a new stop once. Starts at the current scoop.
  int roadSeen = 1;
  /// Home's jar chip has shown its one-line explainer (`jarChipSeen`).
  bool jarChipSeen = false;

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
    tutorialSeen = Tutorial.load(_p.getStringList('tutorialSeen'), currentLevel);
    stars = {
      for (final s in _p.getStringList('stars') ?? <String>[])
        int.parse(s.split(':')[0]): int.parse(s.split(':')[1])
    };
    final jars = _p.getStringList('jarsSealed');
    jarsSealed = jars == null
        ? Jars.sealedFromStars(stars)
        : {for (final j in jars) int.parse(j)};
    boosterStock = {
      for (final s in _p.getStringList('boosterStock') ?? <String>[])
        ?Booster.values.asNameMap()[s.split(':')[0]]: int.parse(s.split(':')[1])
    };
    spoons = {for (final s in _p.getStringList('spoons') ?? <String>[]) int.parse(s)};
    rankPaid = _p.getInt('rankPaid') ?? rank;
    roadSeen = _p.getInt('roadSeen') ?? currentLevel;
    jarChipSeen = _p.getBool('jarChipSeen') ?? false;
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
    await _p.setStringList('tutorialSeen', Tutorial.save(tutorialSeen));
    await _p.setStringList(
        'stars', [for (final e in stars.entries) '${e.key}:${e.value}']);
    await _p.setStringList(
        'jarsSealed', [for (final j in jarsSealed.toList()..sort()) '$j']);
    await _p.setStringList('boosterStock',
        [for (final e in boosterStock.entries) '${e.key.name}:${e.value}']);
    await _p.setInt('rankPaid', rankPaid);
    await _p.setInt('roadSeen', roadSeen);
    await _p.setBool('jarChipSeen', jarChipSeen);
    await _p.setStringList('spoons', [for (final s in spoons.toList()..sort()) '$s']);
  }

  bool isUnlocked(int level) => unlockAll || level <= currentLevel;

  /// Records a win and pays for it: [winPay], the Lid bonus on a first Lid
  /// win, the jar seal (sweets and a free Extra tube), a gold spoon and any
  /// rank gained. [helped]: Undo, Peek or Extra tube was used this run.
  WinReport completeLevel(int level, int earnedStars, int total,
      {bool helped = true}) {
    final xpBefore = xp;
    final prev = stars[level] ?? 0;
    final spoon = Spoons.earns(best: prev, stars: earnedStars, helped: helped) &&
        spoons.add(level);
    var spoonPay = spoon ? Spoons.pay : 0;
    int? spoonJar;
    if (spoon && allSpooned(Jars.of(level))) {
      spoonJar = Jars.of(level);
      spoonPay += Spoons.jarPay;
    }
    final lid = prev == 0 && Jars.isLid(level) ? Jars.lidBonus : 0;
    final pay = winPay(earnedStars, prev) + lid;
    if (earnedStars > prev) stars[level] = earnedStars;
    final jar = Jars.of(level);
    int? sealed;
    var sealPay = 0;
    if (Jars.isLid(level) && jarsSealed.add(jar)) {
      sealed = jar;
      sealPay = Jars.payFor(jar);
      addStock(Booster.extra);
    }
    final r = rank;
    final rankUp = r > rankPaid ? r : null;
    final rankPay = r > rankPaid ? (r - rankPaid) * Rank.gift : 0;
    if (r > rankPaid) rankPaid = r;
    coins += pay + sealPay + rankPay + spoonPay;
    if (level >= currentLevel && level < total) currentLevel = level + 1;
    save();
    notifyListeners();
    return WinReport(
        pay: pay,
        lidBonus: lid,
        sealed: sealed,
        sealPay: sealPay,
        xp: xp - xpBefore,
        rankUp: rankUp,
        rankPay: rankPay,
        spoon: spoon,
        spoonPay: spoonPay,
        spoonJar: spoonJar);
  }

  /// Gold spoons won in [jar].
  int spoonsIn(int jar) => [
        for (var l = Jars.first(jar); l <= Jars.lid(jar); l++)
          if (spoons.contains(l)) l
      ].length;

  /// Every scoop of [jar] has its gold spoon (gold rim on the shelf).
  bool allSpooned(int jar) => spoonsIn(jar) == Jars.size;

  int get starTotal => stars.values.fold(0, (a, b) => a + b);

  /// Rank XP, worked out from progress ([Rank.xp]).
  int get xp => Rank.xp(
      clears: stars.values.where((s) => s > 0).length,
      stars: starTotal,
      jars: jarsSealed.length,
      spoons: spoons.length);

  int get rank => Rank.of(xp);

  int stock(Booster b) => boosterStock[b] ?? 0;

  void addStock(Booster b, [int n = 1]) => boosterStock[b] = stock(b) + n;

  /// Uses one free [b] from the stock; false when there is none.
  bool useStock(Booster b) {
    if (stock(b) == 0) return false;
    boosterStock[b] = stock(b) - 1;
    save();
    notifyListeners();
    return true;
  }

  bool seen(Lesson l) => tutorialSeen.contains(l);

  void markSeen(Iterable<Lesson> ls) {
    if (tutorialSeen.containsAll(ls)) return;
    tutorialSeen.addAll(ls);
    save();
  }

  /// Settings > Replay tutorial: every lesson shows again.
  void replayTutorial() => update((s) => s.tutorialSeen = {});

  @override
  void spendCoins(int n) {
    coins = (coins - n).clamp(0, coins);
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
