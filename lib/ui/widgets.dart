import 'dart:math';

import 'package:flutter/material.dart';

import '../app/chapters.dart';
import '../app/rank.dart';
import '../app/theme.dart';
import '../game/bean_painter.dart';
import '../logic/board.dart';

class BigButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool reward;
  /// Fixed width; null fills the parent's width.
  final double? width;
  /// Reward buttons: sweets price shown next to the AD badge when the
  /// player can pay with sweets instead.
  final int? price;
  const BigButton(this.label,
      {super.key,
      this.onTap,
      this.primary = true,
      this.reward = false,
      this.width,
      this.price});

  @override
  Widget build(BuildContext context) {
    final filled = primary && !reward;
    final bg = filled ? C.primary : C.panel;
    final fg = filled ? Colors.white : (reward ? C.accent : C.text);
    final edge = filled ? C.primaryShadow : (reward ? C.accent : C.border);
    return Opacity(
      opacity: onTap == null ? .5 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          constraints: const BoxConstraints(minHeight: 56, minWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: edge, width: 2),
            boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 4))],
          ),
          alignment: Alignment.center,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (reward) PayBadge(price: price),
            if (reward) const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: fg, fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class AdBadge extends StatelessWidget {
  const AdBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
            color: C.adBadge, borderRadius: BorderRadius.circular(5)),
        child: const Text('AD',
            style: TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
      );
}

/// Small white pill with a leading icon, e.g. star total or beans.
class InfoChip extends StatelessWidget {
  final Widget leading;
  final String text;
  const InfoChip({super.key, required this.leading, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: C.border, width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          leading,
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: C.text)),
        ]),
      );
}

/// Round 48 dp candy icon button (white, press shadow).
class CandyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  const CandyIconButton(this.icon,
      {super.key, required this.tooltip, this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: S.minTouch,
            height: S.minTouch,
            decoration: BoxDecoration(
              color: C.panel,
              shape: BoxShape.circle,
              border: Border.all(color: C.border, width: 2),
              boxShadow: const [BoxShadow(color: C.border, offset: Offset(0, 3))],
            ),
            child: Icon(icon, color: C.text, size: 26),
          ),
        ),
      );
}

/// AD badge, plus a sweets price tag when the booster can be bought.
class PayBadge extends StatelessWidget {
  final int? price;
  const PayBadge({super.key, this.price});
  @override
  Widget build(BuildContext context) => price == null
      ? const AdBadge()
      : Container(
          padding: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: C.panel,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: C.border, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const AdBadge(),
            const SizedBox(width: 3),
            const SweetIcon(width: 11),
            const SizedBox(width: 2),
            Text('$price',
                style: const TextStyle(
                    color: C.text, fontSize: 11, fontWeight: FontWeight.w900)),
          ]),
        );
}

/// Small sweets price: bean mark and number.
class PriceTag extends StatelessWidget {
  final int price;
  const PriceTag(this.price, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(3, 1, 5, 1),
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: C.border, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SweetIcon(width: 12),
          const SizedBox(width: 2),
          Text('$price',
              style: const TextStyle(
                  color: C.text, fontSize: 11, fontWeight: FontWeight.w900)),
        ]),
      );
}

class Stars extends StatelessWidget {
  final int n;
  final double size;
  const Stars(this.n, {super.key, this.size = 16});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(i < n ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size, color: i < n ? C.star : C.border),
        ],
      );
}

/// Placeholder for the adaptive banner slot.
class BannerSlot extends StatelessWidget {
  final bool hidden;
  const BannerSlot({super.key, this.hidden = false});
  @override
  Widget build(BuildContext context) => hidden
      ? const SizedBox.shrink()
      : Container(
          height: 50,
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: C.border))),
          alignment: Alignment.center,
          child: const Text('Banner ad (test)',
              style: TextStyle(color: C.text2, fontSize: 12)),
        );
}

/// Background with soft pastel dots.
class Dotted extends StatelessWidget {
  final Widget child;
  const Dotted({super.key, required this.child});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _DotsPainter(), child: child);
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final rnd = Random(5);
    final cols = [for (final b in beanColors.values) b.withValues(alpha: .18)];
    for (var i = 0; i < 46; i++) {
      c.drawCircle(Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height),
          3 + rnd.nextDouble() * 5, Paint()..color = cols[i % cols.length]);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter o) => false;
}

/// Glass jar. With [tubes] it shows each finished tube as a mini tube;
/// without, it is filled with mixed beans (logo).
/// The candy jar. With [tubes] (the flavours of the finished tubes) it fills
/// with those beans, four per tube, tumbling in one after another; without
/// it, it shows a full jar of mixed beans (Home).
class Jar extends StatelessWidget {
  final List<Ingredient>? tubes;
  final double width;
  /// Pour the beans in when first shown.
  final bool pour;
  /// How long the pour takes; null scales with the number of beans.
  final Duration? pourTime;
  const Jar(
      {super.key, this.tubes, this.width = 180, this.pour = true, this.pourTime});
  @override
  Widget build(BuildContext context) {
    final size = Size(width, width * 1.15);
    if (tubes == null || !pour) {
      return CustomPaint(size: size, painter: JarPainter(tubes, 1));
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: pourTime ?? Duration(milliseconds: 500 + 60 * tubes!.length * 4),
      builder: (_, t, _) => CustomPaint(size: size, painter: JarPainter(tubes, t)),
    );
  }
}

class JarPainter extends CustomPainter {
  final List<Ingredient>? tubes;
  /// Pour progress 0..1.
  final double t;
  JarPainter(this.tubes, this.t);

  /// Loose beans packed from the bottom in staggered rows.
  /// Returns the bean width used and each bean's centre, tilt and flavour.
  @visibleForTesting
  static (double, List<(Offset, double, Ingredient)>) pack(
      Rect inner, List<Ingredient> beans, double minTop) {
    final n = beans.length;
    var bw = inner.width * .2;
    for (var cols = 3; cols <= 8; cols++) {
      bw = inner.width / (cols * .92);
      final bh = bw * beanSize.height / beanSize.width;
      final rows = (n / cols).ceil();
      if (rows * bh * .8 + bh <= inner.bottom - minTop) break;
    }
    final bh = bw * beanSize.height / beanSize.width;
    final rnd = Random(7);
    final out = <(Offset, double, Ingredient)>[];
    var i = 0, row = 0;
    while (i < n) {
      final y = inner.bottom - bh / 2 - row * bh * .8;
      final shift = row.isEven ? 0.0 : bw * .45;
      for (var x = inner.left + bw * .5 + shift;
          x <= inner.right - bw * .35 && i < n;
          x += bw * .92) {
        out.add((Offset(x + (rnd.nextDouble() - .5) * bw * .12, y),
            (rnd.nextDouble() - .5) * 1.1, beans[i++]));
      }
      row++;
    }
    return (bw, out);
  }

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .06, h * .2, w * .88, h * .78), Radius.circular(w * .16));
    c.drawRRect(body.shift(Offset(0, h * .02)), Paint()..color = const Color(0x18000000));
    c.drawRRect(body, Paint()..color = const Color(0xCCFFFFFF));
    c.save();
    c.clipRRect(body.deflate(w * .03));
    final inner = body.deflate(w * .05).outerRect;
    if (tubes == null) {
      final rnd = Random(4);
      final types = Ingredient.values;
      final bw = w * .2, bh = bw * beanSize.height / beanSize.width;
      var i = 0;
      for (var y = inner.bottom - bh; y > inner.top + h * .08; y -= bh * .78) {
        for (var x = inner.left - bw * .3 + (i.isEven ? 0 : bw * .45); x < inner.right; x += bw * .9) {
          c.save();
          c.translate(x + bw / 2, y + bh / 2);
          c.rotate((rnd.nextDouble() - .5) * 1.1);
          paintBean(c, Rect.fromCenter(center: Offset.zero, width: bw, height: bh),
              types[rnd.nextInt(types.length)]);
          c.restore();
        }
        i++;
      }
    } else {
      // Four beans per finished tube, mixed so the flavours tumble together.
      final rnd = Random(3);
      final beans = [for (final f in tubes!) for (var k = 0; k < 4; k++) f]..shuffle(rnd);
      final (bw, placed) = pack(inner, beans, inner.top + h * .04);
      final bh = bw * beanSize.height / beanSize.width;
      final n = placed.length;
      if (n > 0) {
        // Each bean falls for `fall` of the timeline, starts staggered.
        const fall = .35;
        for (var i = 0; i < n; i++) {
          final start = n == 1 ? 0.0 : (1 - fall) * i / (n - 1);
          final u = ((t - start) / fall).clamp(0.0, 1.0);
          if (u <= 0) continue;
          final (p, rot, type) = placed[i];
          // Drop from above the glass with a small bounce on landing.
          final drop = Curves.bounceOut.transform(u);
          final y0 = inner.top - h * .25;
          final y = y0 + (p.dy - y0) * drop;
          c.save();
          c.translate(p.dx, y);
          c.rotate(rot * u);
          paintBean(c, Rect.fromCenter(center: Offset.zero, width: bw, height: bh), type);
          c.restore();
        }
      }
    }
    c.restore();
    // Glass gloss and outline.
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * .13, h * .3, w * .06, h * .5), Radius.circular(w * .03)),
        Paint()..color = const Color(0x99FFFFFF));
    c.drawRRect(body, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFD7E3EE));
    // Lid.
    final lid = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .14, h * .08, w * .72, h * .14), Radius.circular(w * .05));
    c.drawRRect(lid, Paint()..color = C.accent);
    c.drawRect(Rect.fromLTWH(w * .14, h * .18, w * .72, h * .03), Paint()..color = C.primaryShadow);
  }

  @override
  bool shouldRepaint(JarPainter o) => o.tubes != tubes || o.t != t;
}

/// One small jelly bean, the mark of the "sweets" currency.
class SweetIcon extends StatelessWidget {
  final double width;
  const SweetIcon({super.key, this.width = 18});
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size(width, width * beanSize.height / beanSize.width),
      painter: _BeanIconPainter());
}

class _BeanIconPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) => paintBean(c, Offset.zero & s, Ingredient.berry);
  @override
  bool shouldRepaint(_BeanIconPainter o) => false;
}

/// Bean Jars progress: "Jar 6 · Lime", scoops filled out of 10 and a bar
/// in the jar's flavour. [compact] is the one-line version for the result
/// card. [shown] draws the bar part-way (an animation from the old count);
/// the count shows it rounded. [info] adds a small ⓘ: the row explains
/// itself when tapped.
class JarProgress extends StatelessWidget {
  final int jar, filled;
  final bool compact, info;
  final double? shown;
  const JarProgress(
      {super.key,
      required this.jar,
      required this.filled,
      this.compact = false,
      this.info = false,
      this.shown});

  @override
  Widget build(BuildContext context) {
    final colour = beanColors[Jars.flavour(jar)]!;
    final now = shown ?? filled.toDouble();
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: now / Jars.size,
        minHeight: compact ? 8 : 12,
        backgroundColor: C.border,
        color: colour,
      ),
    );
    final head = Row(children: [
      Expanded(
        child: Text(Jars.name(jar).toUpperCase(),
            style: TextStyle(
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
                color: C.text)),
      ),
      Text('${now.round()} / ${Jars.size} scoops',
          style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w800,
              color: C.text2)),
      if (info) const InfoMark(),
    ]);
    return Semantics(
      label: '${Jars.name(jar)}, $filled of ${Jars.size} scoops',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        head,
        SizedBox(height: compact ? 4 : 6),
        bar,
      ]),
    );
  }
}

/// Small ⓘ at the end of a row that explains itself when tapped.
class InfoMark extends StatelessWidget {
  const InfoMark({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 6),
        child: Icon(Icons.info_outline_rounded, size: 17, color: C.text2),
      );
}

/// One shelf jar drawn in [cell] (a square; the lid rises into its top).
/// [fill] is how full an unsealed jar is (0..1); a sealed jar is full and
/// lidded. Gold jars (every 5th) get a gold lid and a gold star, outlined
/// while still to seal, so the bigger prize is visible on the shelf.
void paintShelfJar(Canvas c, Rect cell,
    {required Color colour,
    bool sealed = false,
    bool gold = false,
    bool current = false,
    bool goldRim = false,
    double fill = 0,
    bool faint = false}) {
  final u = cell.width;
  final x = cell.left, y = cell.top;
  final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + u * .14, y + u * .32, u * .72, u * .8),
      Radius.circular(u * .16));
  final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(x + u * .2, y + u * .16, u * .6, u * .18),
      Radius.circular(u * .06));
  final a = faint ? .55 : 1.0;
  c.drawRRect(body, Paint()..color = sealed ? colour : C.panel);
  if (!sealed && fill > 0) {
    c.save();
    c.clipRRect(body);
    final r = body.outerRect;
    c.drawRect(Rect.fromLTRB(r.left, r.bottom - r.height * fill.clamp(0, 1), r.right, r.bottom),
        Paint()..color = colour);
    c.restore();
  }
  c.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = current || goldRim ? 2.5 : 1.5
        ..color = current
            ? C.accent
            : (goldRim || gold ? C.starEdge : C.glass).withValues(alpha: a));
  if (sealed) {
    c.drawRRect(lid, Paint()..color = gold ? C.star : C.accent);
    c.drawRRect(
        lid,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = gold ? C.starEdge : C.primaryShadow);
  } else {
    c.drawRRect(
        lid,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = (current ? C.accent : (gold ? C.starEdge : C.glass))
              .withValues(alpha: a));
  }
  if (gold) {
    final centre = body.outerRect.center;
    final star = _starPath(centre, u * .2);
    if (sealed) c.drawPath(star, Paint()..color = C.star);
    c.drawPath(
        star,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeJoin = StrokeJoin.round
          ..color = C.starEdge.withValues(alpha: a));
  }
}

Path _starPath(Offset c, double r) {
  final p = Path();
  for (var i = 0; i < 10; i++) {
    final rr = i.isEven ? r : r * .45;
    final t = -pi / 2 + i * pi / 5;
    final o = c + Offset(cos(t) * rr, sin(t) * rr);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// One small jar filling up: the jar in progress on Home's jar chip.
class MiniJar extends StatelessWidget {
  final int jar;
  /// Scoops in the jar; fractional while it fills.
  final num filled;
  final bool sealed;
  final double size;
  const MiniJar(
      {super.key,
      required this.jar,
      required this.filled,
      this.sealed = false,
      this.size = 34});

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size(size, size * 1.15),
      painter: _MiniJarPainter(jar, filled, sealed));
}

class _MiniJarPainter extends CustomPainter {
  final int jar;
  final num filled;
  final bool sealed;
  _MiniJarPainter(this.jar, this.filled, this.sealed);

  @override
  void paint(Canvas c, Size s) => paintShelfJar(c, Offset.zero & Size(s.width, s.width),
      colour: beanColors[Jars.flavour(jar)]!,
      sealed: sealed,
      gold: Jars.isGold(jar),
      fill: filled / Jars.size);

  @override
  bool shouldRepaint(_MiniJarPainter o) =>
      o.jar != jar || o.filled != filled || o.sealed != sealed;
}

/// The Pantry shelf: one small jar per chapter. Sealed jars are full and
/// lidded; the jar in progress is outlined and filled to its scoops; gold
/// jars (every 5th) carry a gold star; a jar with all its Master spoons
/// gets a gold rim. Jars not reached yet are faint.
class PantryShelf extends StatelessWidget {
  final int jars, current;
  final Set<int> sealed;
  final Set<int> goldRim;
  /// Scoops won in the [current] jar.
  final int filled;
  final double width;
  const PantryShelf(
      {super.key,
      required this.jars,
      required this.current,
      required this.sealed,
      this.goldRim = const {},
      this.filled = 0,
      required this.width});

  static const perRow = 10;

  @override
  Widget build(BuildContext context) {
    final rows = (jars / perRow).ceil();
    final cell = width / perRow;
    return Semantics(
      label: 'Pantry shelf, ${sealed.length} of $jars jars sealed',
      child: CustomPaint(
        size: Size(width, rows * cell * 1.35),
        painter: _ShelfPainter(jars, current, sealed, goldRim, filled),
      ),
    );
  }
}

class _ShelfPainter extends CustomPainter {
  final int jars, current, filled;
  final Set<int> sealed, goldRim;
  _ShelfPainter(this.jars, this.current, this.sealed, this.goldRim, this.filled);

  @override
  void paint(Canvas c, Size s) {
    final cell = s.width / PantryShelf.perRow;
    final rowH = cell * 1.35;
    final rows = (jars / PantryShelf.perRow).ceil();
    for (var r = 0; r < rows; r++) {
      // The plank under each row.
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(0, r * rowH + cell * 1.12, s.width, cell * .14),
              const Radius.circular(3)),
          Paint()..color = C.border);
    }
    for (var j = 1; j <= jars; j++) {
      final i = j - 1;
      final x = (i % PantryShelf.perRow) * cell, y = (i ~/ PantryShelf.perRow) * rowH;
      final done = sealed.contains(j);
      paintShelfJar(c, Rect.fromLTWH(x, y, cell, cell),
          colour: beanColors[Jars.flavour(j)]!,
          sealed: done,
          gold: Jars.isGold(j),
          current: j == current && !done,
          goldRim: goldRim.contains(j),
          fill: j == current && !done ? filled / Jars.size : 0,
          faint: !done && j > current);
    }
  }

  @override
  bool shouldRepaint(_ShelfPainter o) =>
      o.jars != jars ||
      o.current != current ||
      o.filled != filled ||
      o.sealed.length != sealed.length ||
      o.goldRim.length != goldRim.length;
}

/// Rank badge: the rank number in a raspberry circle.
class RankDot extends StatelessWidget {
  final int rank;
  final double size;
  const RankDot(this.rank, {super.key, this.size = 30});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: C.accent,
          shape: BoxShape.circle,
          border: Border.all(color: C.primaryShadow, width: size >= 24 ? 2 : 1.5),
        ),
        child: Text('$rank',
            style: TextStyle(
                color: Colors.white,
                fontSize: size * .47,
                height: 1,
                fontWeight: FontWeight.w900)),
      );
}

/// Confectioner rank: badge with the rank number, title and a thin bar of
/// rank points towards the next rank, with how many points the next title
/// needs. [gain] shows "+N points" from the last win instead. [shown] draws
/// the bar at a part-way point total (an animation from the old total:
/// crossing a rank fills the bar, then it restarts in the new rank). [info]
/// adds a small ⓘ: the row explains itself when tapped.
///
/// Players see "points", not "XP": the word needs no explaining.
class RankBar extends StatelessWidget {
  final int xp;
  final int? gain;
  final double? shown;
  final bool info;
  const RankBar({super.key, required this.xp, this.gain, this.shown, this.info = false});

  @override
  Widget build(BuildContext context) {
    final now = shown ?? xp.toDouble();
    final rank = Rank.of(now.floor());
    final top = rank >= Rank.top;
    final from = Rank.threshold(rank), to = Rank.threshold(rank + 1);
    final right = gain != null
        ? '+$gain points'
        : (top ? 'Top rank' : '${to - now.round()} points to ${Rank.title(rank + 1)}');
    return Semantics(
      label: 'Rank $rank, ${Rank.title(rank)}, $right',
      child: ExcludeSemantics(
        child: Row(children: [
          RankDot(rank),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(Rank.title(rank),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w900, color: C.text)),
                ),
                Text(right,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: gain != null ? C.accentText : C.text2)),
              ]),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: top ? 1 : ((now - from) / (to - from)).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: C.border,
                  color: C.star,
                ),
              ),
            ]),
          ),
          if (info) const InfoMark(),
        ]),
      ),
    );
  }
}

/// A reward as a small chip: icon and "+50 jar sealed". [gold] edges it in
/// gold (gold jar).
class RewardChip extends StatelessWidget {
  final Widget icon;
  final String text;
  final bool gold;
  const RewardChip({super.key, required this.icon, required this.text, this.gold = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(6, 3, 10, 3),
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: gold ? C.star : C.border, width: 2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(height: 18, child: Center(child: icon)),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: C.text)),
        ]),
      );
}

/// Icon of the Extra tube booster, for reward chips.
const extraTubeIcon = Icon(Icons.add_box_outlined, color: C.text, size: 17);

/// Master spoon mark: gold once won, a soft "ghost" spoon while still to
/// win. Drawn tilted, like a spoon laid down, so it never reads as a pin
/// or a key.
class SpoonIcon extends StatelessWidget {
  final bool gold;
  final double size;
  const SpoonIcon({super.key, required this.gold, this.size = 16});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(size * .85, size), painter: _SpoonPainter(gold));
}

class _SpoonPainter extends CustomPainter {
  final bool gold;
  _SpoonPainter(this.gold);

  @override
  void paint(Canvas c, Size s) {
    // A spoon of length l along the box's diagonal: a big oval bowl taller
    // than wide and a handle that widens a little towards its end (no
    // round knob: that reads as a key).
    final l = s.height * .9;
    final handle = Path()
      ..moveTo(-l * .05, -l * .05)
      ..lineTo(l * .05, -l * .05)
      ..lineTo(l * .09, l * .44)
      ..quadraticBezierTo(0, l * .52, -l * .09, l * .44)
      ..close();
    final shape = Path.combine(
        PathOperation.union,
        Path()
          ..addOval(Rect.fromCenter(
              center: Offset(0, -l * .24), width: l * .46, height: l * .56)),
        handle);
    c.save();
    c.translate(s.width / 2, s.height / 2);
    c.rotate(pi / 5);
    if (gold) {
      c.drawPath(shape, Paint()..color = C.star);
      c.drawPath(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.0, l * .06)
            ..color = C.starEdge);
      c.drawOval(
          Rect.fromCenter(center: Offset(-l * .06, -l * .3), width: l * .12, height: l * .2),
          Paint()..color = const Color(0xAAFFFFFF));
    } else {
      c.drawPath(shape, Paint()..color = C.lockedTile);
      c.drawPath(
          shape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.2, l * .07)
            ..color = C.text2.withValues(alpha: .6));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_SpoonPainter o) => o.gold != gold;
}
