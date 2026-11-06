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
  const Jar({super.key, this.tubes, this.width = 180, this.pour = true});
  @override
  Widget build(BuildContext context) {
    final size = Size(width, width * 1.15);
    if (tubes == null || !pour) {
      return CustomPaint(size: size, painter: JarPainter(tubes, 1));
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 500 + 60 * tubes!.length * 4),
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
/// card.
class JarProgress extends StatelessWidget {
  final int jar, filled;
  final bool compact;
  const JarProgress(
      {super.key, required this.jar, required this.filled, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final colour = beanColors[Jars.flavour(jar)]!;
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: filled / Jars.size,
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
      Text('$filled / ${Jars.size} scoops',
          style: TextStyle(
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w800,
              color: C.text2)),
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

/// The Pantry shelf: one small jar per chapter, filled and lidded once
/// sealed, gold-lidded every 5th jar, outlined for the jar in progress,
/// and gold-rimmed once all its Master spoons are won.
class PantryShelf extends StatelessWidget {
  final int jars, current;
  final Set<int> sealed;
  final Set<int> goldRim;
  final double width;
  const PantryShelf(
      {super.key,
      required this.jars,
      required this.current,
      required this.sealed,
      this.goldRim = const {},
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
        painter: _ShelfPainter(jars, current, sealed, goldRim),
      ),
    );
  }
}

class _ShelfPainter extends CustomPainter {
  final int jars, current;
  final Set<int> sealed, goldRim;
  _ShelfPainter(this.jars, this.current, this.sealed, this.goldRim);

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
      final body = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + cell * .14, y + cell * .32, cell * .72, cell * .8),
          Radius.circular(cell * .16));
      final done = sealed.contains(j);
      final colour = beanColors[Jars.flavour(j)]!;
      c.drawRRect(body, Paint()..color = done ? colour : C.panel);
      c.drawRRect(
          body,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = j == current || goldRim.contains(j) ? 2.5 : 1.5
            ..color = j == current
                ? C.accent
                : (goldRim.contains(j) ? C.star : C.glass));
      if (done) {
        final lid = RRect.fromRectAndRadius(
            Rect.fromLTWH(x + cell * .2, y + cell * .16, cell * .6, cell * .18),
            Radius.circular(cell * .06));
        c.drawRRect(lid, Paint()..color = Jars.isGold(j) ? C.star : C.accent);
      }
    }
  }

  @override
  bool shouldRepaint(_ShelfPainter o) =>
      o.jars != jars ||
      o.current != current ||
      o.sealed.length != sealed.length ||
      o.goldRim.length != goldRim.length;
}

/// Confectioner rank: badge with the rank number, title and a thin XP bar
/// towards the next rank. [gain] shows "+N XP" from the last win instead of
/// the XP count.
class RankBar extends StatelessWidget {
  final int xp;
  final int? gain;
  const RankBar({super.key, required this.xp, this.gain});

  @override
  Widget build(BuildContext context) {
    final rank = Rank.of(xp);
    final top = rank >= Rank.top;
    final from = Rank.threshold(rank), to = Rank.threshold(rank + 1);
    final right = gain != null
        ? '+$gain XP'
        : (top ? 'Top rank' : '$xp / $to XP');
    return Semantics(
      label: 'Rank $rank, ${Rank.title(rank)}, $right',
      child: ExcludeSemantics(
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: C.accent,
              shape: BoxShape.circle,
              border: Border.all(color: C.primaryShadow, width: 2),
            ),
            child: Text('$rank',
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
          ),
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
                  value: top ? 1 : (xp - from) / (to - from),
                  minHeight: 6,
                  backgroundColor: C.border,
                  color: C.star,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Master spoon mark: gold once won, an outline while still to win.
class SpoonIcon extends StatelessWidget {
  final bool gold;
  final double size;
  const SpoonIcon({super.key, required this.gold, this.size = 14});

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size(size * .55, size), painter: _SpoonPainter(gold));
}

class _SpoonPainter extends CustomPainter {
  final bool gold;
  _SpoonPainter(this.gold);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final bowl = Rect.fromLTWH(0, 0, w, h * .45);
    final handle = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .36, h * .4, w * .28, h * .6), Radius.circular(w * .14));
    if (gold) {
      final p = Paint()..color = C.star;
      c.drawOval(bowl, p);
      c.drawRRect(handle, p);
      c.drawOval(bowl.deflate(w * .18).shift(Offset(-w * .08, -h * .04)),
          Paint()..color = const Color(0x99FFFFFF));
    } else {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, w * .14)
        ..color = C.text2.withValues(alpha: .7);
      c.drawOval(bowl.deflate(p.strokeWidth / 2), p);
      c.drawRRect(handle.deflate(p.strokeWidth / 2), p);
    }
  }

  @override
  bool shouldRepaint(_SpoonPainter o) => o.gold != gold;
}
