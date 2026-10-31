/// Pure interstitial frequency rules (unit-tested).
class AdPolicy {
  static const firstLevel = 10;
  static const everyN = 3;
  static const minGapMs = 90 * 1000;

  static bool shouldShowInterstitial({
    required int level,
    required int completedSinceAd,
    required int nowMs,
    required int lastMs,
    required bool restarted,
    required bool removeAds,
  }) {
    if (removeAds || restarted) return false;
    if (level <= firstLevel) return false;
    if (completedSinceAd < everyN) return false;
    return nowMs - lastMs >= minGapMs;
  }
}
