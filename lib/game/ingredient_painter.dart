import 'dart:math';
import 'dart:ui';

import '../logic/board.dart';

const ingredientColors = {
  Ingredient.patty: Color(0xFF7A4A2E),
  Ingredient.cheese: Color(0xFFFFC93C),
  Ingredient.tomato: Color(0xFFE8483B),
  Ingredient.lettuce: Color(0xFF5DBB4A),
  Ingredient.onion: Color(0xFFF3E6F6),
  Ingredient.pickle: Color(0xFF8DB257),
};

/// Draws one ingredient (or cloche) into [r] with code shapes plus a
/// shape cue per ingredient for colour-blind play.
void paintIngredient(Canvas c, Rect r, Ingredient type, {bool hidden = false}) {
  final fill = Paint()..color = ingredientColors[type]!;
  final dark = Paint()..color = const Color(0x55000000);
  final stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0x66000000);
  if (hidden) {
    final dome = Path()
      ..moveTo(r.left + 4, r.bottom)
      ..quadraticBezierTo(r.center.dx, r.top - r.height * .6, r.right - 4, r.bottom)
      ..close();
    c.drawPath(dome, Paint()..color = const Color(0xFFD9CDBA));
    c.drawPath(dome, stroke);
    c.drawCircle(Offset(r.center.dx, r.top - 2), 4, Paint()..color = const Color(0xFFB8AA94));
    final pb = ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center, fontSize: r.height * .7))
      ..pushStyle(TextStyle(color: const Color(0xFF7A6450), fontWeight: FontWeight.w800))
      ..addText('?');
    final p = pb.build()..layout(ParagraphConstraints(width: r.width));
    c.drawParagraph(p, Offset(r.left, r.center.dy - p.height / 2));
    return;
  }
  switch (type) {
    case Ingredient.patty:
      final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height / 2));
      c.drawRRect(rr, fill);
      c.drawRRect(rr, stroke);
      final line = Paint()
        ..color = const Color(0xFF4A2A18)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 1; i <= 4; i++) {
        final x = r.left + r.width * i / 5;
        c.drawLine(Offset(x - 5, r.top + 5), Offset(x + 5, r.bottom - 5), line);
      }
    case Ingredient.cheese:
      final rr = RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(3));
      c.drawRRect(rr, fill);
      c.drawRRect(rr, stroke);
      final hole = Paint()..color = const Color(0xFFE0A820);
      c.drawCircle(Offset(r.left + r.width * .25, r.center.dy), r.height * .17, hole);
      c.drawCircle(Offset(r.left + r.width * .55, r.top + r.height * .35), r.height * .13, hole);
      c.drawCircle(Offset(r.left + r.width * .78, r.center.dy + 3), r.height * .15, hole);
    case Ingredient.tomato:
      final rr = RRect.fromRectAndRadius(r.deflate(2), Radius.circular(r.height / 2));
      c.drawRRect(rr, fill);
      c.drawRRect(rr, stroke);
      c.drawRRect(
          RRect.fromRectAndRadius(r.deflate(r.height * .28), Radius.circular(r.height)),
          Paint()..color = const Color(0xFFF7766B));
      final seed = Paint()..color = const Color(0xFFFFE9A8);
      for (var i = 0; i < 5; i++) {
        c.drawCircle(Offset(r.left + r.width * (.2 + i * .15), r.center.dy), 2.2, seed);
      }
    case Ingredient.lettuce:
      final p = Path()..moveTo(r.left, r.center.dy);
      const waves = 7;
      for (var i = 0; i <= waves; i++) {
        final x = r.left + r.width * i / waves;
        p.lineTo(x, r.top + (i.isEven ? 0 : r.height * .35));
      }
      p.lineTo(r.right, r.center.dy);
      for (var i = waves; i >= 0; i--) {
        final x = r.left + r.width * i / waves;
        p.lineTo(x, r.bottom - (i.isEven ? r.height * .1 : r.height * .4));
      }
      p.close();
      c.drawPath(p, fill);
      c.drawPath(p, stroke);
    case Ingredient.onion:
      final rr = RRect.fromRectAndRadius(r.deflate(2), Radius.circular(r.height / 2));
      c.drawRRect(rr, fill);
      c.drawRRect(rr, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFFA874BC));
      c.drawRRect(
          RRect.fromRectAndRadius(r.deflate(r.height * .32), Radius.circular(r.height)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFFA874BC));
    case Ingredient.pickle:
      final rr = RRect.fromRectAndRadius(
          Rect.fromLTRB(r.left + 6, r.top + 2, r.right - 6, r.bottom - 2),
          Radius.circular(r.height / 2));
      c.drawRRect(rr, fill);
      c.drawRRect(rr, stroke);
      final rnd = Random(3);
      for (var i = 0; i < 7; i++) {
        c.drawCircle(
            Offset(r.left + 12 + rnd.nextDouble() * (r.width - 24),
                r.top + 5 + rnd.nextDouble() * (r.height - 10)),
            2.2,
            dark);
      }
  }
}

void paintBun(Canvas c, Rect r) {
  final p = Path()
    ..moveTo(r.left, r.bottom)
    ..quadraticBezierTo(r.left, r.top, r.center.dx, r.top)
    ..quadraticBezierTo(r.right, r.top, r.right, r.bottom)
    ..close();
  c.drawPath(p, Paint()..color = const Color(0xFFE8A04A));
  c.drawPath(p, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0x66000000));
  final s = Paint()..color = const Color(0xFFFFF4D6);
  for (var i = 0; i < 6; i++) {
    c.drawOval(
        Rect.fromCenter(
            center: Offset(r.left + r.width * (.2 + i * .12), r.top + r.height * (i.isEven ? .4 : .6)),
            width: 6,
            height: 3),
        s);
  }
}
