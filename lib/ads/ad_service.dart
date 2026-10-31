import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'ad_policy.dart';

/// Placeholder ad service: simulates ads with a dialog so the game flow and
/// caps can be tried before AdMob is wired in (milestone 6).
class AdService {
  final AppState state;
  AdService(this.state);

  Future<bool> showRewarded(BuildContext context, String placement) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rewarded ad (test)'),
        content: Text('Pretend you watched an ad for "$placement".'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Skip')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Claim reward')),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> maybeInterstitial(BuildContext context, int level,
      {required bool restarted}) async {
    state.completedSinceAd++;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (AdPolicy.shouldShowInterstitial(
        level: level,
        completedSinceAd: state.completedSinceAd,
        nowMs: now,
        lastMs: state.lastInterstitialMs,
        restarted: restarted,
        removeAds: state.removeAds)) {
      state.completedSinceAd = 0;
      state.lastInterstitialMs = now;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Interstitial ad (test)'),
          content: const Text('An interstitial would show here.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Close'))
          ],
        ),
      );
    }
    await state.save();
  }
}
