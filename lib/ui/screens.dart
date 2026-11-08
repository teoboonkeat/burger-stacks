import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/chapters.dart';
import '../app/rank.dart';
import '../app/rewards.dart';
import '../app/theme.dart';
import '../game/bean_painter.dart';
import '../levels/level.dart';
import 'game_screen.dart';
import 'road_screen.dart';
import 'widgets.dart';

class Services {
  final AppState state;
  final List<Level> levels;
  Services(this.state, this.levels);
}

/// Home: logo, stars and sweets, Play, Levels and Settings. From the first
/// win a small jar chip shows the jar being filled (it opens the Pantry
/// sheet); from rank 2 a rank badge sits beside the sweets.
class HomeScreen extends StatelessWidget {
  final Services s;
  const HomeScreen(this.s, {super.key});

  /// The jar chip shows once a scoop has been won.
  bool get _chip => s.state.stars.isNotEmpty;

  /// Leaving Home after the chip has shown its explainer line: the next
  /// visit shows the jar's reward instead.
  void _leave() {
    if (_chip && !s.state.jarChipSeen) {
      s.state.update((x) => x.jarChipSeen = true);
    }
  }

  void _go(BuildContext context, Widget Function(BuildContext) page) {
    _leave();
    Navigator.push(context, MaterialPageRoute(builder: page));
  }

  void _pantry(BuildContext context) {
    _leave();
    showPantry(context, s);
  }

  @override
  Widget build(BuildContext context) {
    final bw = min(S.homeButtonW,
        MediaQuery.sizeOf(context).width - 2 * S.screenMargin);
    final tall = MediaQuery.sizeOf(context).height >= 720;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: s.state,
          builder: (context, _) => Center(
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Jar(width: tall ? 110 : 84),
                const SizedBox(height: 4),
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
                  if (s.state.rank >= 2) ...[
                    const SizedBox(width: 4),
                    _RankBadge(s.state.rank, onTap: () => _pantry(context)),
                  ],
                ]),
                if (_chip) ...[
                  const SizedBox(height: 12),
                  JarChip(s: s, width: bw, onTap: () => _pantry(context)),
                ],
                SizedBox(height: _chip ? 16 : 24),
                BigButton('Play · Scoop ${s.state.currentLevel}',
                    width: bw,
                    onTap: () => _go(context,
                        (_) => GameScreen(s, s.state.currentLevel))),
                const SizedBox(height: 12),
                BigButton('Levels',
                    primary: false,
                    width: bw,
                    onTap: () => _go(context, (_) => RoadScreen(s))),
                const SizedBox(height: 12),
                BigButton('Settings',
                    primary: false,
                    width: bw,
                    onTap: () => _go(context, (_) => SettingsScreen(s))),
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

/// Rank number beside the sweets (48 dp target); opens the Pantry.
class _RankBadge extends StatelessWidget {
  final int rank;
  final VoidCallback onTap;
  const _RankBadge(this.rank, {required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Rank $rank, ${Rank.title(rank)}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: S.minTouch,
            height: S.minTouch,
            child: Center(child: ExcludeSemantics(child: RankDot(rank, size: 32))),
          ),
        ),
      );
}

/// Home's jar chip: a small jar filling up, "Jar 1 · Berry 3 / 10" and a
/// bar. The first time it shows, one line explains jars; after that the
/// line says what sealing the jar pays. Tapping opens the Pantry.
class JarChip extends StatefulWidget {
  final Services s;
  final double width;
  final VoidCallback onTap;
  const JarChip({super.key, required this.s, required this.width, required this.onTap});

  @override
  State<JarChip> createState() => _JarChipState();
}

/// The chip remembers the fill it last showed. Home stays built under the
/// game, so a win updates it while hidden; once Home is the top route
/// again, the jar and bar fill from the old count to the new one.
class _JarChipState extends State<JarChip> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: S.fill);
  int _jar = 0;
  double _from = 0, _to = 0;
  bool _pending = false;

  double get _shown =>
      _from + (_to - _from) * Curves.easeOutCubic.transform(_anim.value);

  @override
  void initState() {
    super.initState();
    _anim.value = 1;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.s.state;
    final jar = Jars.of(st.currentLevel);
    final filled = Jars.filled(jar, st.stars);
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    if (_jar == 0) {
      // First build: shown as it is, or, when the chip first appears
      // under the game (after the first win), filled from empty.
      _jar = jar;
      _from = _to = visible ? filled.toDouble() : 0;
    } else if (jar != _jar) {
      // A new jar (the last one was sealed): no fill animation.
      _jar = jar;
      _from = _to = filled.toDouble();
    }
    if (visible && _to != filled && !_pending) {
      _pending = true;
      final from = _shown, to = filled.toDouble();
      final still = MediaQuery.of(context).disableAnimations;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _pending = false;
        setState(() {
          _from = from;
          _to = to;
          _anim.value = still ? 1 : 0;
        });
        // A short pause first, so the player sees Home before it fills.
        if (!still) {
          Future.delayed(S.fillPause, () {
            if (mounted) _anim.forward(from: 0);
          });
        }
      });
    }
    return AnimatedBuilder(
        animation: _anim, builder: (context, _) => _chip(st, jar, filled, _shown));
  }

  Widget _chip(AppState st, int jar, int filled, double shown) {
    final sealed = st.jarsSealed.contains(jar);
    final colour = beanColors[Jars.flavour(jar)]!;
    final line = !st.jarChipSeen
        ? 'Win ${Jars.size} scoops to fill and seal a jar'
        : (sealed
            ? 'Sealed · see your Pantry'
            : 'Seal it at Lid scoop ${Jars.lid(jar)} · +${Jars.payFor(jar)}');
    const small = TextStyle(fontSize: 13, fontWeight: FontWeight.w800);
    return Semantics(
      button: true,
      label: '${Jars.name(jar)}, $filled of ${Jars.size} scoops. $line. Opens the Pantry',
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: widget.width,
            constraints: const BoxConstraints(minHeight: S.minTouch),
            padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
            decoration: BoxDecoration(
              color: C.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: C.border, width: 2),
              boxShadow: const [BoxShadow(color: C.border, offset: Offset(0, 3))],
            ),
            child: Row(children: [
              MiniJar(jar: jar, filled: shown, sealed: sealed, size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text(Jars.name(jar),
                            overflow: TextOverflow.ellipsis,
                            style: small.copyWith(fontSize: 14, fontWeight: FontWeight.w900))),
                    Text('${shown.round()} / ${Jars.size}',
                        style: small.copyWith(color: C.text2)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: shown / Jars.size,
                      minHeight: 6,
                      backgroundColor: C.border,
                      color: colour,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(line, style: small.copyWith(fontSize: 12, color: C.accentText)),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.text2, size: 22),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A bottom sheet in the Pantry's style: drag handle, a title, and
/// [children] scrolling under it.
Future<void> _sheet(BuildContext context, String title,
        List<Widget> Function(double width) children) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: C.bg,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: LayoutBuilder(
            builder: (c, box) => Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              ...children(box.maxWidth),
            ]),
          ),
        ),
      ),
    );

/// The Pantry: the jar being filled and the shelf of every jar, then the
/// rank, each with how it works.
Future<void> showPantry(BuildContext context, Services s) =>
    _sheet(context, 'Pantry', (w) => [
          JarCard(s: s, width: w),
          const SizedBox(height: 10),
          const JarHowTo(),
          const SizedBox(height: 18),
          RankBar(xp: s.state.xp),
          const SizedBox(height: 10),
          const RankHowTo(),
        ]);

/// How jars work, from the result card's jar row: [jar] and its scoops.
Future<void> showJarHelp(BuildContext context, Services s, int jar) =>
    _sheet(context, 'Bean jars', (w) => [
          JarProgress(jar: jar, filled: Jars.filled(jar, s.state.stars)),
          const SizedBox(height: 12),
          const JarHowTo(),
        ]);

/// How rank works, from the result card's rank row.
Future<void> showRankHelp(BuildContext context, Services s) =>
    _sheet(context, 'Rank', (w) => [
          RankBar(xp: s.state.xp),
          const SizedBox(height: 12),
          const RankHowTo(),
        ]);

/// "How it works" panel: a heading and short lines, each led by what it
/// pays ("+50") or a small icon.
class _HowTo extends StatelessWidget {
  final String title;
  final List<(Widget, String)> lines;
  const _HowTo(this.title, this.lines);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: C.border, width: 2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          for (final (lead, text) in lines)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 40, child: lead),
                Expanded(child: Text(text, style: _howText)),
              ]),
            ),
        ]),
      );
}

const _howText =
    TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w700, color: C.text);

/// Amount at the start of a how-it-works line ("+50").
Widget _pay(int n) => Text('+$n',
    style: const TextStyle(
        fontSize: 13, height: 1.3, fontWeight: FontWeight.w900, color: C.accentText));

Widget _icon(Widget w) =>
    Align(alignment: Alignment.topLeft, child: Padding(padding: const EdgeInsets.only(top: 1), child: w));

/// How jars work, with the numbers from [Jars].
class JarHowTo extends StatelessWidget {
  const JarHowTo({super.key});

  @override
  Widget build(BuildContext context) => _HowTo('How jars work', [
        (
          _icon(const MiniJar(jar: 1, filled: 4, size: 15)),
          'Each new scoop you win adds one to your jar.'
        ),
        (
          _pay(Jars.sealPay),
          'Win the ${Jars.size}th scoop, the Lid scoop, to seal the jar: '
              '+${Jars.sealPay} sweets and a free Extra tube.'
        ),
        (
          _icon(extraTubeIcon),
          'An Extra tube gives you an empty tube when you are stuck.'
        ),
        (
          _pay(Jars.goldPay),
          'Every ${Jars.goldEvery}th jar is gold: +${Jars.goldPay} sweets more.'
        ),
      ]);
}

/// How rank works, with the numbers from [Rank] and [Spoons].
class RankHowTo extends StatelessWidget {
  const RankHowTo({super.key});

  @override
  Widget build(BuildContext context) => _HowTo('How rank works', [
        (_pay(Rank.xpClear), 'points for each new scoop you win'),
        (_pay(Rank.xpStar), 'points for each star (your best on each scoop)'),
        (_pay(Rank.xpJar), 'points for each jar you seal'),
        (_pay(Rank.xpSpoon), 'points for each gold spoon'),
        (
          _icon(const SpoonIcon(gold: true)),
          'A gold spoon: win a scoop again with ★★★ and no Undo, Peek or '
              'Extra tube (+${Spoons.pay} sweets).'
        ),
        (
          _icon(const RankDot(2, size: 18)),
          'Enough points and you rank up: a new title and '
              '+${Rank.gift} sweets.'
        ),
      ]);
}

/// The Pantry's jar card: the jar being filled, how to seal it and what
/// that pays, and the Pantry shelf of every jar.
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
    final filled = Jars.filled(jar, st.stars);
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        JarProgress(jar: jar, filled: filled),
        const SizedBox(height: 8),
        if (sealed)
          Text('Sealed', style: small.copyWith(color: C.newBadge))
        else ...[
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Win Lid scoop ${Jars.lid(jar)} to seal it'),
            TextSpan(
                text: toLid == 0 ? ' · up next' : ' · $toLid to go',
                style: const TextStyle(color: C.text2)),
          ]), style: small),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            RewardChip(
                icon: const SweetIcon(width: 16),
                text: '+${Jars.payFor(jar)} sweets',
                gold: Jars.isGold(jar)),
            const RewardChip(icon: extraTubeIcon, text: 'Extra tube'),
          ]),
        ],
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Pantry shelf', style: small)),
          Text('${st.jarsSealed.length} / $jars sealed',
              style: small.copyWith(color: C.text2)),
        ]),
        const SizedBox(height: 4),
        PantryShelf(
            jars: jars,
            current: jar,
            filled: filled,
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
  /// Master spoon: null before the first clear, false while still to win
  /// (not drawn on the road), true once won (a gold spoon on the tile).
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
                      fontSize: 11,
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
    // Only won spoons show on the road; the ghost spoon stays in the
    // jar label, so 50+ tiles are not cluttered.
    if (spoon != true) return tile;
    return Stack(fit: StackFit.expand, children: [
      tile,
      const Positioned(top: 5, right: 6, child: SpoonIcon(gold: true, size: 15)),
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
    x.jarChipSeen = false;
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
