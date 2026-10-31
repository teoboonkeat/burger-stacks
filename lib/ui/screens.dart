import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/theme.dart';
import '../levels/level.dart';
import 'game_screen.dart';
import 'widgets.dart';

class Services {
  final AppState state;
  final List<Level> levels;
  Services(this.state, this.levels);
}

class HomeScreen extends StatelessWidget {
  final Services s;
  const HomeScreen(this.s, {super.key});

  void _play(BuildContext context, int level) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => GameScreen(s, level)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s.state,
          builder: (context, _) => Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('🍔', style: TextStyle(fontSize: 96)),
              const Text('Burger Stacks',
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: C.text)),
              const SizedBox(height: 8),
              Text('🪙 ${s.state.coins} tips',
                  style: const TextStyle(color: C.text2, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 40),
              BigButton('Play · Order ${s.state.currentLevel}',
                  onTap: () => _play(context, s.state.currentLevel)),
              const SizedBox(height: 16),
              BigButton('Levels',
                  primary: false,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => LevelListScreen(s)))),
              const SizedBox(height: 16),
              BigButton('Settings',
                  primary: false,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => SettingsScreen(s)))),
              const SizedBox(height: 16),
              if (!s.state.removeAds)
                TextButton(
                    onPressed: () => buyRemoveAds(context, s.state),
                    child: const Text('Remove ads',
                        style: TextStyle(color: C.text2, fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ),
    );
  }
}

Future<void> buyRemoveAds(BuildContext context, AppState st) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Remove ads (test purchase)'),
      content: const Text('Turns off banners and interstitials. Rewarded ads stay available.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Buy')),
      ],
    ),
  );
  if (ok == true) st.update((s) => s.removeAds = true);
}

class LevelListScreen extends StatelessWidget {
  final Services s;
  const LevelListScreen(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Levels'), backgroundColor: C.bg),
      body: ListenableBuilder(
        listenable: s.state,
        builder: (context, _) => Column(children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5, mainAxisSpacing: 10, crossAxisSpacing: 10),
              itemCount: s.levels.length,
              itemBuilder: (context, i) {
                final id = i + 1;
                final open = s.state.isUnlocked(id);
                return GestureDetector(
                  onTap: open
                      ? () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => GameScreen(s, id)))
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: open ? C.panel : const Color(0xFFE9E2D6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: C.border, width: 2),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('$id',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: open ? C.text : C.text2.withValues(alpha: .5))),
                      if (open) Stars(s.state.stars[id] ?? 0, size: 13),
                    ]),
                  ),
                );
              },
            ),
          ),
          BannerSlot(hidden: s.state.removeAds),
        ]),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final Services s;
  const SettingsScreen(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final st = s.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: C.bg),
      body: ListenableBuilder(
        listenable: st,
        builder: (context, _) => ListView(children: [
          SwitchListTile(
              title: const Text('Sound'),
              value: st.sound,
              onChanged: (v) => st.update((x) => x.sound = v)),
          SwitchListTile(
              title: const Text('Music'),
              value: st.music,
              onChanged: (v) => st.update((x) => x.music = v)),
          SwitchListTile(
              title: const Text('Haptics'),
              value: st.haptics,
              onChanged: (v) => st.update((x) => x.haptics = v)),
          ListTile(
              title: const Text('Restore purchases'),
              subtitle: Text(st.removeAds ? 'Remove ads: owned' : 'No purchases found'),
              onTap: () {}),
          const ListTile(
              title: Text('Privacy options'),
              subtitle: Text('Consent form appears here once AdMob is connected')),
          ListTile(
              title: const Text('Reset progress'),
              onTap: () => st.update((x) {
                    x.currentLevel = 1;
                    x.stars = {};
                    x.coins = 0;
                    x.removeAds = false;
                  })),
          const AboutListTile(
              applicationName: 'Burger Stacks',
              aboutBoxChildren: [Text('Art drawn in code. No third-party sounds yet.')],
              child: Text('Credits')),
        ]),
      ),
    );
  }
}
