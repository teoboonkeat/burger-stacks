import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/chapters.dart';
import '../app/road.dart';
import '../app/theme.dart';
import '../game/bean_painter.dart';
import 'game_screen.dart';
import 'screens.dart';
import 'widgets.dart';

/// Candy Road (P7): every scoop is a stop on a winding road, bottom to
/// top. Lid scoops are jar landmarks, signposts announce the next twist,
/// and the marker walks to the new stop after a win.
class RoadScreen extends StatefulWidget {
  final Services s;
  const RoadScreen(this.s, {super.key});
  @override
  State<RoadScreen> createState() => _RoadScreenState();
}

class _RoadScreenState extends State<RoadScreen> {
  ScrollController? _scroll;
  double _viewH = 0;

  /// Stop the marker is drawn at; it starts where it was last seen and
  /// walks to the current scoop once the screen is up.
  late int _marker =
      widget.s.state.roadSeen.clamp(1, widget.s.state.currentLevel);

  int get _count => widget.s.levels.length;

  @override
  void initState() {
    super.initState();
    final st = widget.s.state;
    if (_marker < st.currentLevel) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        setState(() => _marker = st.currentLevel);
        st.update((x) => x.roadSeen = x.currentLevel);
      });
    } else if (st.roadSeen != st.currentLevel) {
      st.update((x) => x.roadSeen = x.currentLevel);
    }
  }

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  void _open(int level) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => GameScreen(widget.s, level)));

  Future<void> _jump() async {
    final ctl = TextEditingController();
    final n = await showDialog<int>(
      context: context,
      builder: (c) {
        void go() => Navigator.pop(c, int.tryParse(ctl.text));
        return AlertDialog(
          title: const Text('Jump to scoop'),
          content: TextField(
            controller: ctl,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(hintText: '1 to $_count'),
            onSubmitted: (_) => go(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(onPressed: go, child: const Text('Go')),
          ],
        );
      },
    );
    if (n == null || !mounted || _scroll == null) return;
    _scroll!.animateTo(
        RoadLayout.offsetFor(n.clamp(1, _count), _count, _viewH),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.s.state;
    return Scaffold(
      appBar: AppBar(title: const Text('Candy Road'), actions: [
        ListenableBuilder(
          listenable: st,
          builder: (context, _) => InfoChip(
              leading: const Icon(Icons.star_rounded, color: C.star, size: 20),
              text: '${st.starTotal} / ${_count * 3}'),
        ),
        const SizedBox(width: 16),
      ]),
      body: Column(children: [
        Expanded(
          child: LayoutBuilder(builder: (context, box) {
            _viewH = box.maxHeight;
            _scroll ??= ScrollController(
                initialScrollOffset:
                    RoadLayout.offsetFor(st.currentLevel, _count, box.maxHeight));
            return Stack(children: [
              ListenableBuilder(
                listenable: st,
                builder: (context, _) => ListView.builder(
                  controller: _scroll,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: RoadLayout.pad),
                  itemCount: _count,
                  itemBuilder: (context, i) => _Stop(
                    s: widget.s,
                    level: i + 1,
                    count: _count,
                    width: box.maxWidth,
                    marker: _marker == i + 1,
                    onTap: () => _open(i + 1),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(
                  child: ActionChip(
                    avatar: const Icon(Icons.search_rounded, color: C.text, size: 18),
                    label: const Text('Jump to scoop…',
                        style: TextStyle(fontWeight: FontWeight.w800, color: C.text)),
                    backgroundColor: C.panel,
                    side: const BorderSide(color: C.border, width: 2),
                    onPressed: _jump,
                  ),
                ),
              ),
            ]);
          }),
        ),
        BannerSlot(hidden: st.removeAds),
      ]),
    );
  }
}

/// One row of the road: its piece of road, the stop, and for Lid scoops
/// the jar landmark, for signpost stops the sign.
class _Stop extends StatelessWidget {
  final Services s;
  final int level, count;
  final double width;
  final bool marker;
  final VoidCallback onTap;
  const _Stop(
      {required this.s,
      required this.level,
      required this.count,
      required this.width,
      required this.marker,
      required this.onTap});

  static const tile = 58.0;

  @override
  Widget build(BuildContext context) {
    final st = s.state;
    final h = RoadLayout.heightOf(level);
    final x = RoadLayout.xOf(level) * width;
    // Labels go on the roomier side of the stop.
    final labelLeft = RoadLayout.xOf(level) > .5;
    final stars = st.stars[level] ?? 0;
    final jar = Jars.of(level);
    final sign = RoadLayout.signs[level];
    Widget side(Widget child) => Positioned(
          top: 0,
          bottom: 0,
          left: labelLeft ? 12 : x + tile / 2 + 12,
          right: labelLeft ? width - x + tile / 2 + 12 : 12,
          child: Align(
            alignment: labelLeft ? Alignment.centerRight : Alignment.centerLeft,
            child: child,
          ),
        );
    return SizedBox(
      height: h,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          child: CustomPaint(painter: _RoadPainter(level, count, width)),
        ),
        Positioned(
          left: x - tile / 2,
          top: (h - tile) / 2,
          width: tile,
          height: tile,
          child: LevelTile(
            id: level,
            open: st.isUnlocked(level),
            next: level == st.currentLevel && stars == 0,
            stars: stars,
            lid: Jars.isLid(level),
            spoon: stars == 0 ? null : st.spoons.contains(level),
            onTap: onTap,
          ),
        ),
        if (Jars.isLid(level))
          side(_JarLabel(
            jar: jar,
            sealed: st.jarsSealed.contains(jar),
            spoons: st.spoonsIn(jar),
            alignEnd: labelLeft,
          ))
        else if (sign != null)
          side(_Sign(sign.$1, sign.$2)),
        Positioned(
          left: x - 15,
          top: (h - tile) / 2 - 30,
          child: AnimatedScale(
            scale: marker ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            child: const Icon(Icons.location_on_rounded,
                color: C.accent,
                size: 30,
                shadows: [Shadow(color: Colors.white, blurRadius: 6)]),
          ),
        ),
      ]),
    );
  }
}

/// Jar landmark beside a Lid scoop: "Jar 6 · Cola", sealed or "seal here",
/// and its Master spoons.
class _JarLabel extends StatelessWidget {
  final int jar, spoons;
  final bool sealed, alignEnd;
  const _JarLabel(
      {required this.jar,
      required this.sealed,
      required this.spoons,
      required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    final colour = beanColors[Jars.flavour(jar)]!;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: C.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colour, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(Jars.name(jar),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          Text(
              sealed
                  ? (Jars.isGold(jar) ? 'Sealed · gold lid' : 'Sealed')
                  : 'Seal here · +${Jars.payFor(jar)}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: sealed ? C.newBadge : C.accentText)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            SpoonIcon(gold: spoons == Jars.size, size: 12),
            const SizedBox(width: 4),
            Text('Spoons $spoons / ${Jars.size}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: C.text2)),
          ]),
        ],
      ),
    );
  }
}

/// Signpost announcing the next twist.
class _Sign extends StatelessWidget {
  final String head, text;
  const _Sign(this.head, this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
        decoration: BoxDecoration(
          color: C.star,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFC99A12), width: 2),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(head.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w900)),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        ]),
      );
}

/// This row's piece of road: from the edge it shares with the stop below,
/// through its own stop, to the edge it shares with the stop above. Each
/// row stays inside its own box, so rows can be built lazily.
class _RoadPainter extends CustomPainter {
  final int level, count;
  final double width;
  _RoadPainter(this.level, this.count, this.width);

  @override
  void paint(Canvas c, Size s) {
    final x = RoadLayout.xOf(level) * width;
    final mid = Offset(x, s.height / 2);
    final path = Path();
    if (level > 1) {
      final xb = (x + RoadLayout.xOf(level - 1) * width) / 2;
      path
        ..moveTo(xb, s.height)
        ..quadraticBezierTo(x, s.height * .75, mid.dx, mid.dy);
    } else {
      path.moveTo(mid.dx, mid.dy);
    }
    if (level < count) {
      final xt = (x + RoadLayout.xOf(level + 1) * width) / 2;
      path.quadraticBezierTo(x, s.height * .25, xt, 0);
    }
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 30
          ..strokeCap = StrokeCap.butt
          ..color = C.border);
    // Dashed sugar line down the middle.
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    for (final m in path.computeMetrics()) {
      for (var d = 4.0; d < m.length; d += 16) {
        c.drawPath(m.extractPath(d, d + 7), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter o) =>
      o.level != level || o.count != count || o.width != width;
}
