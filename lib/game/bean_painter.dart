import 'dart:math';
import 'dart:ui';

import '../logic/board.dart';

/// Base colour per flavour (enum order matches level data).
const beanColors = {
  Ingredient.berry: Color(0xFFE0305A),
  Ingredient.peach: Color(0xFFF07F1A),
  Ingredient.lime: Color(0xFF6CCB47),
  Ingredient.grape: Color(0xFF6E4AD6),
  Ingredient.lemon: Color(0xFFF2C230),
  Ingredient.cola: Color(0xFF6B3E26),
};

/// Design size of one bean; callers pass any rect with this aspect.
const beanSize = Size(52, 40);

Color _darken(Color c, double f) => Color.fromARGB(
    255, (c.r * 255 * f).round(), (c.g * 255 * f).round(), (c.b * 255 * f).round());

/// Bean silhouette: rounded top, slightly flatter bottom.
Path beanPath(Rect r) {
  Offset p(double x, double y) => Offset(r.left + r.width * x, r.top + r.height * y);
  final a = p(.10, .80);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(p(-.02, .55).dx, p(-.02, .55).dy, p(.04, .04).dx, p(.04, .04).dy,
        p(.50, .03).dx, p(.50, .03).dy)
    ..cubicTo(p(.96, .04).dx, p(.96, .04).dy, p(1.02, .55).dx, p(1.02, .55).dy,
        p(.90, .80).dx, p(.90, .80).dy)
    ..cubicTo(p(.78, .95).dx, p(.78, .95).dy, p(.22, .95).dx, p(.22, .95).dy,
        a.dx, a.dy)
    ..close();
}

/// Draws one jelly bean (or a paper pouch when [hidden]) into [r].
/// The bean fills the rect; a 3 px (at design size) shadow sits under it.
void paintBean(Canvas c, Rect r, Ingredient type, {bool hidden = false}) {
  if (hidden) {
    paintPouch(c, r);
    return;
  }
  final k = r.height / beanSize.height;
  final base = beanColors[type]!;
  final body = Rect.fromLTRB(r.left, r.top, r.right, r.bottom - 3 * k);
  final path = beanPath(body);
  c.drawPath(path.shift(Offset(0, 3 * k)), Paint()..color = _darken(base, .62));
  c.drawPath(path, Paint()..color = base);

  c.save();
  c.clipPath(path);
  switch (type) {
    case Ingredient.berry:
      break;
    case Ingredient.peach:
      final rnd = Random(7);
      final dot = Paint()..color = const Color(0xFFFFE1BF);
      for (var i = 0; i < 14; i++) {
        c.drawCircle(
            Offset(body.left + body.width * (.08 + rnd.nextDouble() * .84),
                body.top + body.height * (.12 + rnd.nextDouble() * .76)),
            (1.1 + rnd.nextDouble() * .9) * k,
            dot);
      }
    case Ingredient.lime:
      final stripe = Paint()..color = const Color(0xFFB8EB98);
      for (var x = body.left + 5 * k; x < body.right; x += 10 * k) {
        c.drawRect(Rect.fromLTWH(x, body.top, 3.5 * k, body.height), stripe);
      }
    case Ingredient.grape:
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * k
            ..color = const Color(0xFFC9B8FF));
    case Ingredient.lemon:
      final swirl = Path();
      final ctr = body.center.translate(0, 2 * k);
      for (var t = 0.0; t < 3.4 * pi; t += .15) {
        final rad = (1.2 + t * 1.25) * k;
        final o = ctr + Offset(cos(t) * rad * 1.3, sin(t) * rad);
        t == 0 ? swirl.moveTo(o.dx, o.dy) : swirl.lineTo(o.dx, o.dy);
      }
      c.drawPath(
          swirl,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * k
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFFFFFFF));
    case Ingredient.cola:
      c.drawOval(
          Rect.fromCenter(
              center: body.center.translate(0, 1 * k),
              width: body.width * .56,
              height: body.height * .5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 * k
            ..color = const Color(0xFFC48A5A));
  }
  c.restore();

  // Gloss highlight, top-left.
  c.save();
  c.translate(body.left + body.width * .28, body.top + body.height * .26);
  c.rotate(-.45);
  c.drawOval(Rect.fromCenter(center: Offset.zero, width: 15 * k, height: 7 * k),
      Paint()..color = const Color(0xD9FFFFFF));
  c.restore();
  c.drawCircle(Offset(body.left + body.width * .47, body.top + body.height * .17),
      1.8 * k, Paint()..color = const Color(0xB3FFFFFF));
}

/// Paper pouch hiding a bean. [tear] 0→1 rips it open and fades it out.
void paintPouch(Canvas c, Rect r, {double tear = 0}) {
  final k = r.height / beanSize.height;
  final box = Rect.fromLTRB(r.left + 1 * k, r.top + 1 * k, r.right - 1 * k, r.bottom - 1 * k);
  final rr = RRect.fromRectAndRadius(box, Radius.circular(8 * k));
  void drawWhole() {
    c.drawRRect(rr.shift(Offset(0, 2 * k)), Paint()..color = const Color(0x22000000));
    c.drawRRect(rr, Paint()..color = const Color(0xFFF3E6D8));
    c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * k
          ..color = const Color(0xFFD3C2B4));
    // Folded top seam.
    c.drawLine(Offset(box.left + 4 * k, box.top + 7 * k), Offset(box.right - 4 * k, box.top + 7 * k),
        Paint()
          ..strokeWidth = 1.2 * k
          ..color = const Color(0xFFD3C2B4));
    final pb = ParagraphBuilder(
        ParagraphStyle(textAlign: TextAlign.center, fontSize: 22 * k))
      ..pushStyle(TextStyle(color: const Color(0xFF7E625C), fontWeight: FontWeight.w800))
      ..addText('?');
    final p = pb.build()..layout(ParagraphConstraints(width: box.width));
    c.drawParagraph(p, Offset(box.left, box.center.dy - p.height / 2 + 3 * k));
  }

  if (tear <= 0) {
    drawWhole();
    return;
  }
  // Zigzag tear line down the middle; halves fly apart and fade.
  Path half(bool left) {
    final p = Path();
    final mid = box.center.dx;
    final edge = left ? box.left - 20 * k : box.right + 20 * k;
    p.moveTo(edge, box.top - 10 * k);
    const steps = 6;
    for (var i = 0; i <= steps; i++) {
      final y = box.top - 10 * k + (box.height + 20 * k) * i / steps;
      p.lineTo(mid + (i.isEven ? -3 : 3) * k, y);
    }
    p.lineTo(edge, box.bottom + 10 * k);
    return p..close();
  }

  final alpha = (1 - tear).clamp(0.0, 1.0);
  for (final left in [true, false]) {
    final dir = left ? -1.0 : 1.0;
    c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    c.translate(box.center.dx + dir * tear * 14 * k, box.bottom - tear * 6 * k);
    c.rotate(dir * tear * .5);
    c.translate(-box.center.dx, -box.bottom);
    c.clipPath(half(left));
    drawWhole();
    c.restore();
  }
}
