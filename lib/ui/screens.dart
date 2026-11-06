import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/chapters.dart';
import '../app/theme.dart';
import '../levels/level.dart';
import 'game_screen.dart';
import 'road_screen.dart';
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
    final bw = min(S.homeButtonW,
        MediaQuery.sizeOf(context).width - 2 * S.screenMargin);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s.state,
          builder: (context, _) => Center(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Short phones drop the logo jar so every button fits
                // under the jar card without scrolling.
                if (MediaQuery.sizeOf(context).height >= 720) ...[
                  const Jar(width: 110),
                  const SizedBox(height: 4),
                ],
                const Text('Jelly Beans',
                    style: TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w900, color: C.accent)),
                const SizedBox(height: 12),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  InfoChip(
                      leading: const Icon(Icons.star_rounded, color: C.star, size: 20),
                      text: '${s.state.starTotal}'),
                  const SizedBox(width: 8),
                  InfoChip(
                      leading: const SweetIcon(),
                      text: '${s.state.coins} sweets'),
                ]),
                const SizedBox(height: 12),
                SizedBox(width: bw - 8, child: RankBar(xp: s.state.xp)),
                const SizedBox(height: 12),
                JarCard(s: s, width: bw),
                const SizedBox(height: 16),
                BigButton('Play · Scoop ${s.state.currentLevel}',
                    width: bw,
                    onTap: () => _play(context, s.state.currentLevel)),
                const SizedBox(height: 12),
                BigButton('Levels',
                    primary: false,
                    width: bw,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => RoadScreen(s)))),
                const SizedBox(height: 12),
                BigButton('Settings',
                    primary: false,
                    width: bw,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => SettingsScreen(s)))),
                const SizedBox(height: 12),
                if (!s.state.removeAds)
                  TextButton(
                      onPressed: () => buyRemoveAds(context, s.state),
                      child: const Text('Remove ads')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Home's goal card: the jar being filled, what sealing it pays, how far
/// the Lid scoop is, and the Pantry shelf of every jar.
class JarCard extends StatelessWidget {
  final Services s;
  final double width;
  const JarCard({super.key, required this.s, required this.width});

  @override
  Widget build(BuildContext context) {
    final st = s.state;
    final jars = Jars.count(s.levels.length);
    final jar = Jars.of(st.currentLevel);
    final sealed = st.jarsSealed.contains(jar);
    final toLid = Jars.lid(jar) - st.currentLevel;
    const small = TextStyle(fontSize: 13, fontWeight: FontWeight.w800);
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.border, width: 2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        JarProgress(jar: jar, filled: Jars.filled(jar, st.stars)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text(
                sealed
                    ? 'Sealed'
                    : 'Seal it: +${Jars.payFor(jar)} sweets, Extra tube',
                style: small.copyWith(color: C.accentText)),
          ),
          if (!sealed)
            Text(toLid == 0 ? 'Lid scoop next!' : 'Lid scoop in $toLid',
                style: small.copyWith(color: C.text2)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(child: Text('Pantry shelf', style: small)),
          Text('${st.jarsSealed.length} / $jars sealed',
              style: small.copyWith(color: C.text2)),
        ]),
        const SizedBox(height: 4),
        PantryShelf(
            jars: jars,
            current: jar,
            sealed: st.jarsSealed,
            goldRim: {
              for (var j = 1; j <= jars; j++)
                if (st.allSpooned(j)) j
            },
            width: width - 32),
      ]),
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

/// One scoop as a tile: number, stars, lock or play, the Lid label and
/// the Master spoon. Used as the stops of the Candy Road.
class LevelTile extends StatelessWidget {
  final int id, stars;
  final bool open, next;
  /// Lid scoop: the jar's last scoop, gold-edged and labelled.
  final bool lid;
  /// Master spoon: null before the first clear, then an outline until
  /// it is won gold.
  final bool? spoon;
  final VoidCallback onTap;
  const LevelTile(
      {super.key,
      required this.id,
      required this.open,
      required this.next,
      required this.stars,
      required this.onTap,
      this.lid = false,
      this.spoon});

  @override
  Widget build(BuildContext context) {
    final bg = next ? C.primary : (open ? C.panel : C.lockedTile);
    final edge = next ? C.primaryShadow : (lid ? C.star : C.border);
    final kind = lid ? 'Lid scoop' : 'Scoop';
    final spoonText = spoon == true ? ', gold spoon' : '';
    final tile = Semantics(
      button: open,
      label: open
          ? '$kind $id, $stars stars$spoonText'
          : '$kind $id, locked',
      child: GestureDetector(
        onTap: open ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: edge, width: lid ? 3 : 2),
            boxShadow: open ? [BoxShadow(color: edge, offset: const Offset(0, 3))] : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (lid)
              Text('LID',
                  style: TextStyle(
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: next ? Colors.white : C.text2)),
            Text('$id',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: next
                        ? Colors.white
                        : (open ? C.text : C.text2.withValues(alpha: .6)))),
            if (next)
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18)
            else if (open)
              Stars(stars, size: 13)
            else
              Icon(Icons.lock_rounded, size: 13, color: C.text2.withValues(alpha: .6)),
          ]),
        ),
      ),
    );
    if (spoon == null) return tile;
    return Stack(fit: StackFit.expand, children: [
      tile,
      Positioned(top: 5, right: 6, child: SpoonIcon(gold: spoon!, size: 13)),
    ]);
  }
}

Future<void> _confirmReset(BuildContext context, AppState st) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Reset progress?'),
      content: const Text(
          'Levels, stars and sweets start again from Scoop 1. This cannot be '
          'undone. Purchases such as Remove ads are kept.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
      ],
    ),
  );
  if (ok != true) return;
  // removeAds is a purchase, not progress: it survives a reset.
  st.update((x) {
    x.currentLevel = 1;
    x.stars = {};
    x.coins = 0;
    x.jarsSealed = {};
    x.boosterStock = {};
    x.rankPaid = 1;
    x.spoons = {};
    x.roadSeen = 1;
    x.unlockAll = false;
  });
}

class SettingsScreen extends StatelessWidget {
  final Services s;
  const SettingsScreen(this.s, {super.key});

  void _replayTutorial(BuildContext context) {
    s.state.replayTutorial();
    Navigator.of(context)
      ..popUntil((r) => r.isFirst)
      ..push(MaterialPageRoute(builder: (_) => GameScreen(s, 1)));
  }

  @override
  Widget build(BuildContext context) {
    final st = s.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: st,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Group('Game', [
              SwitchListTile(
                  title: const Text('Sound'),
                  value: st.sound,
                  onChanged: (v) => st.update((x) => x.sound = v)),
              // No music yet: the Music switch stays hidden (its saved value
              // is kept in AppState so old saves still load).
              SwitchListTile(
                  title: const Text('Haptics'),
                  value: st.haptics,
                  onChanged: (v) => st.update((x) => x.haptics = v)),
              SwitchListTile(
                  title: const Text('Drag beans'),
                  subtitle: const Text('Drag a group onto a tube, as well as tapping'),
                  value: st.dragBeans,
                  onChanged: (v) => st.update((x) => x.dragBeans = v)),
            ]),
            _Group('Help', [
              ListTile(
                  leading: const Icon(Icons.school_rounded, color: C.text),
                  title: const Text('Replay tutorial'),
                  subtitle: const Text('Shows every lesson again, from Scoop 1'),
                  onTap: () => _replayTutorial(context)),
            ]),
            _Group('Purchases and privacy', [
              ListTile(
                  title: const Text('Restore purchases'),
                  subtitle: Text(st.removeAds ? 'Remove ads: owned' : 'No purchases found'),
                  onTap: () {}),
              const ListTile(
                  title: Text('Privacy options'),
                  subtitle: Text('Consent form appears here once AdMob is connected')),
            ]),
            _Group('Progress', [
              ListTile(
                  title: const Text('Reset progress'),
                  subtitle: const Text('Levels, stars and sweets. Purchases are kept.'),
                  onTap: () => _confirmReset(context, st)),
              const AboutListTile(
                  applicationName: 'Jelly Beans',
                  aboutBoxChildren: [Text('Art drawn in code. Sounds synthesised in-house.')],
                  child: Text('Credits')),
            ]),
            // Kept in release builds on purpose (testers use it on APKs),
            // but folded away at the bottom.
            _Group(null, [
              ExpansionTile(
                title: const Text('Testing',
                    style: TextStyle(color: C.text2, fontWeight: FontWeight.w800)),
                shape: const Border(),
                collapsedShape: const Border(),
                children: [
                  SwitchListTile(
                      title: const Text('Unlock all levels'),
                      subtitle: const Text('Every scoop playable, for testing'),
                      value: st.unlockAll,
                      onChanged: (v) => st.update((x) => x.unlockAll = v)),
                ],
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

/// White settings card with an optional small heading above it.
class _Group extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const _Group(this.title, this.children);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
              child: Text(title!,
                  style: const TextStyle(
                      color: C.text2, fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: C.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: C.border, width: 2),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ListTileTheme(
                data: const ListTileThemeData(
                    titleTextStyle: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: C.text),
                    subtitleTextStyle: TextStyle(fontSize: 13, color: C.text2)),
                child: Column(children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: C.border),
                    children[i],
                  ]
                ]),
              ),
            ),
          ),
        ]),
      );
}
