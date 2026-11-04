import 'dart:math';

import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        const AdBadge(),
        if (price != null) ...[
          const SizedBox(width: 3),
          PriceTag(price!),
        ],
      ]);
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
class Jar extends StatelessWidget {
  final List<Ingredient>? tubes;
  final double width;
  const Jar({super.key, this.tubes, this.width = 180});
  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size(width, width * 1.15), painter: JarPainter(tubes));
}

class JarPainter extends CustomPainter {
  final List<Ingredient>? tubes;
  JarPainter(this.tubes);

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
      final n = tubes!.length;
      final cols = n <= 4 ? max(n, 1) : (n / 2).ceil();
      final rows = n <= 4 ? 1 : 2;
      final tw = min(inner.width / cols * .78, w * .2);
      final th = min(inner.height / rows * .9, tw * 3.2);
      for (var i = 0; i < n; i++) {
        final row = i ~/ cols, col = i % cols;
        final inRow = row == rows - 1 ? n - cols * (rows - 1) : cols;
        final gap = (inner.width - inRow * tw) / (inRow + 1);
        final x = inner.left + gap + col * (tw + gap);
        final y = inner.bottom - (rows - row) * (th + 6);
        final tr = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, tw, th), Radius.circular(tw * .3));
        c.drawRRect(tr, Paint()..color = const Color(0xE6FFFFFF));
        c.drawRRect(tr, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFD7E3EE));
        final bh = (th - 10) / 4 - 2;
        final bw = min(tw - 6, bh * beanSize.width / beanSize.height);
        for (var b = 0; b < 4; b++) {
          paintBean(c, Rect.fromLTWH(x + (tw - bw) / 2, y + th - 5 - (bh + 2) * (b + 1), bw, bh), tubes![i]);
        }
        c.drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(x - 1, y - 4, tw + 2, 7), const Radius.circular(3)),
            Paint()..color = const Color(0xFFC9D1D9));
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
  bool shouldRepaint(JarPainter o) => o.tubes != tubes;
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
