import 'dart:math';

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
    final bw = min(S.homeButtonW,
        MediaQuery.sizeOf(context).width - 2 * S.screenMargin);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s.state,
          builder: (context, _) => Center(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Jar(width: 150),
                const SizedBox(height: 8),
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
                const SizedBox(height: 32),
                BigButton('Play · Scoop ${s.state.currentLevel}',
                    width: bw,
                    onTap: () => _play(context, s.state.currentLevel)),
                const SizedBox(height: 16),
                BigButton('Levels',
                    primary: false,
                    width: bw,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => LevelListScreen(s)))),
                const SizedBox(height: 16),
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

/// Level grid geometry, shared by the grid and its initial scroll.
class LevelGrid {
  static const cols = 5, pad = 16.0, gap = 10.0;

  /// Scroll offset that puts [level]'s row in the middle of a [viewH] high
  /// grid that is [width] wide, clamped to the scrollable range.
  static double offsetFor(int level, int count, double width, double viewH) {
    final tile = (width - 2 * pad - (cols - 1) * gap) / cols;
    final rowH = tile + gap;
    final rows = (count / cols).ceil();
    final content = 2 * pad + rows * rowH - gap;
    final row = (level - 1) ~/ cols;
    final want = pad + row * rowH - (viewH - tile) / 2;
    return want.clamp(0.0, max(0.0, content - viewH));
  }
}

class LevelListScreen extends StatelessWidget {
  final Services s;
  const LevelListScreen(this.s, {super.key});

  @override
  Widget build(BuildContext context) {
    final st = s.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Levels'), actions: [
        ListenableBuilder(
          listenable: st,
          builder: (context, _) => InfoChip(
              leading: const Icon(Icons.star_rounded, color: C.star, size: 20),
              text: '${st.starTotal} / ${s.levels.length * 3}'),
        ),
        const SizedBox(width: 16),
      ]),
      body: ListenableBuilder(
        listenable: st,
        builder: (context, _) => Column(children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => GridView.builder(
                controller: ScrollController(
                    initialScrollOffset: LevelGrid.offsetFor(st.currentLevel,
                        s.levels.length, box.maxWidth, box.maxHeight)),
                padding: const EdgeInsets.all(LevelGrid.pad),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: LevelGrid.cols,
                    mainAxisSpacing: LevelGrid.gap,
                    crossAxisSpacing: LevelGrid.gap),
                itemCount: s.levels.length,
                itemBuilder: (context, i) {
                  final id = i + 1;
                  return _LevelTile(
                    id: id,
                    open: st.isUnlocked(id),
                    next: id == st.currentLevel && (st.stars[id] ?? 0) == 0,
                    stars: st.stars[id] ?? 0,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => GameScreen(s, id))),
                  );
                },
              ),
            ),
          ),
          BannerSlot(hidden: st.removeAds),
        ]),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  final int id, stars;
  final bool open, next;
  final VoidCallback onTap;
  const _LevelTile(
      {required this.id,
      required this.open,
      required this.next,
      required this.stars,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = next ? C.primary : (open ? C.panel : C.lockedTile);
    final edge = next ? C.primaryShadow : C.border;
    return Semantics(
      button: open,
      label: open ? 'Scoop $id, $stars stars' : 'Scoop $id, locked',
      child: GestureDetector(
        onTap: open ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: edge, width: 2),
            boxShadow: open ? [BoxShadow(color: edge, offset: const Offset(0, 3))] : null,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
