import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/services.dart';

import '../logic/board.dart';
import 'bean_painter.dart';
import 'spring.dart';

/// `land` fires once per bean as it settles in its new tube.
enum GameEvent { pick, drop, land, invalid, reveal, tubeComplete, won, stuck, undo }

/// Tube design size and inner geometry (all scaled by [JellyGame.k]).
const tubeW = 62.0, tubeH = 232.0;
const _capH = 18.0, _bodyTop = 14.0, _bodyBottom = 214.0, _slotBottom = 206.0;
const _beanGap = 4.0;

/// Damped spring used for every jelly wobble: starts at 1, rings out to 0.
double wobble(double t, {double freq = 20, double decay = 7}) =>
    t >= 1 ? 0 : exp(-decay * t) * cos(freq * t);

class JellyGame extends FlameGame {
  Board board;
  final void Function(GameEvent e) onEvent;
  bool haptics;
  int? selected;
  double k = 1;
  final List<TubeComponent> tubeComps = [];

  JellyGame(this.board, {required this.onEvent, this.haptics = true});

  @override
  Color backgroundColor() => const Color(0xFFFFF7EC);

  @override
  Future<void> onLoad() async {
    add(DotsBackground());
    _build();
  }

  void reset(Board b) {
    board = b;
    selected = null;
    _build();
  }

  void _build() {
    for (final t in tubeComps) {
      t.removeFromParent();
    }
    children.whereType<FlyingBean>().forEach((f) => f.removeFromParent());
    tubeComps.clear();
    for (var i = 0; i < board.tubes.length; i++) {
      final tc = TubeComponent(i);
      tubeComps.add(tc);
      add(tc);
    }
    if (hasLayout) _layout(size);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout(size);
  }

  void _layout(Vector2 size) {
    final n = tubeComps.length;
    if (n == 0) return;
    final rows = n > 6 ? 2 : 1;
    final perRow = (n / rows).ceil();
    const gapX = 12.0, gapY = 34.0;
    // Leave headroom above the top row for beans arcing over the tubes.
    final headroom = 40.0;
    k = min(
        min((size.x - gapX * (perRow + 1)) / (perRow * tubeW),
            (size.y - headroom - 16 - gapY * (rows - 1)) / (rows * tubeH)),
        1.15);
    final tw = tubeW * k, th = tubeH * k;
    final totalH = rows * th + (rows - 1) * gapY;
    final top = max(headroom, (size.y - totalH) / 2 + headroom / 3);
    for (var i = 0; i < n; i++) {
      final row = i ~/ perRow;
      final inRow = row == rows - 1 ? n - perRow * (rows - 1) : perRow;
      final col = i % perRow;
      final rowW = inRow * (tw + gapX) - gapX;
      tubeComps[i]
        ..size = Vector2(tw, th)
        ..position =
            Vector2((size.x - rowW) / 2 + col * (tw + gapX), top + row * (th + gapY));
    }
  }

  /// Bean height inside a tube, shrunk only if a level ever has capacity > 4.
  double get beanH {
    final fit = (_slotBottom - _capH - 12) / board.capacity - _beanGap;
    return min(beanSize.height, fit) * k;
  }

  double get beanW => beanH * beanSize.width / beanSize.height;

  void _haptic(bool heavy) {
    if (!haptics) return;
    heavy ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
  }

  void tapTube(int i) {
    if (board.isWon) return;
    // A tube with beans still dropping into it can't be used yet.
    if (tubeComps[i].incoming > 0) return;
    final s = selected;
    if (s == null) {
      if (board.canPick(i)) {
        selected = i;
        tubeComps[i].pickUp();
        onEvent(GameEvent.pick);
        _haptic(false);
      } else if (board.tubes[i].stack.isNotEmpty || board.isLocked(i)) {
        tubeComps[i].shake();
        onEvent(GameEvent.invalid);
      }
      return;
    }
    if (s == i) {
      selected = null;
      tubeComps[i].putDown();
      return;
    }
    final before = board.completeCount;
    final hiddenBefore = _hiddenCount();
    final srcLen = board.tubes[s].stack.length;
    final dstLen = board.tubes[i].stack.length;
    final m = board.drop(s, i);
    if (m == null) {
      tubeComps[i].shake();
      onEvent(GameEvent.invalid);
      return;
    }
    selected = null;
    final type = board.tubes[i].top!.type;
    final from = tubeComps[s], to = tubeComps[i];
    final lift = from.lift;
    from.resetLift();
    to.incoming += m.count;
    var landed = 0;
    // Beans leave top-first; the first one out falls deepest in the target.
    for (var b = 0; b < m.count; b++) {
      add(FlyingBean(
        type: type,
        start: from.slotPos(srcLen - 1 - b) - Vector2(0, lift),
        end: to.slotPos(dstLen + b),
        exitY: from.position.y - beanH - 6 * k,
        enterY: to.position.y - beanH - 6 * k,
        width: beanW,
        height: beanH,
        delay: b * .05,
        onLand: () {
          to.incoming--;
          to.landed(dstLen + b);
          landed++;
          onEvent(GameEvent.land);
          _haptic(landed == m.count);
          if (landed < m.count) return;
          if (m.sealedTarget) {
            to.complete();
            _celebrate(to);
            onEvent(GameEvent.tubeComplete);
          }
          if (board.completeCount > before) {
            for (final t in tubeComps) {
              t.unlockCheck();
            }
          }
          if (board.isWon) {
            onEvent(GameEvent.won);
          } else if (board.isStuck) {
            onEvent(GameEvent.stuck);
          }
        },
      ));
    }
    if (_hiddenCount() < hiddenBefore) {
      from.reveal();
      onEvent(GameEvent.reveal);
    }
    onEvent(GameEvent.drop);
  }

  int _hiddenCount() =>
      board.tubes.fold(0, (a, t) => a + t.stack.where((x) => x.hidden).length);

  /// Burst of the tube's flavour colour plus white sparkles from the cap.
  void _celebrate(TubeComponent t) {
    final r = Random();
    final col = beanColors[t.tube.stack.first.type]!;
    add(ParticleSystemComponent(
      position: t.position + Vector2(t.size.x / 2, 8 * k),
      particle: Particle.generate(
        count: 22,
        lifespan: .8,
        generator: (i) {
          final a = -pi / 2 + (r.nextDouble() - .5) * 2.2;
          final sp = 90 + r.nextDouble() * 120;
          final white = i.isEven;
          return AcceleratedParticle(
            acceleration: Vector2(0, 260),
            speed: Vector2(cos(a), sin(a)) * sp,
            child: ComputedParticle(renderer: (c, p) {
              final fade = 1 - p.progress;
              final paint = Paint()
                ..color = (white ? const Color(0xFFFFFFFF) : col)
                    .withValues(alpha: fade);
              if (white) {
                _star(c, 4.5 * fade + 1.5, paint);
              } else {
                c.drawOval(Rect.fromCenter(center: Offset.zero, width: 8, height: 6), paint);
              }
            }),
          );
        },
      ),
    ));
  }

  static void _star(Canvas c, double r, Paint p) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rad = i.isEven ? r : r * .38;
      final a = i * pi / 4;
      final o = Offset(cos(a) * rad, sin(a) * rad);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    c.drawPath(path..close(), p);
  }

  /// Level complete: a shower of tiny beans.
  void confetti() {
    final r = Random();
    final colors = beanColors.values.toList();
    add(ParticleSystemComponent(
      position: Vector2(size.x / 2, size.y * .3),
      particle: Particle.generate(
        count: 60,
        lifespan: 1.4,
        generator: (_) {
          final col = colors[r.nextInt(colors.length)];
          final rot = r.nextDouble() * pi;
          return AcceleratedParticle(
            acceleration: Vector2(0, 300),
            speed:
                Vector2((r.nextDouble() - .5) * 400, -200 - r.nextDouble() * 200),
            child: ComputedParticle(renderer: (c, part) {
              c.save();
              c.rotate(rot + part.progress * 6);
              c.drawOval(Rect.fromCenter(center: Offset.zero, width: 9, height: 6),
                  Paint()..color = col);
              c.restore();
            }),
          );
        },
      ),
    ));
  }

  bool get animating => children.whereType<FlyingBean>().isNotEmpty;

  void doUndo() {
    if (animating) return;
    if (selected != null) tubeComps[selected!].putDown();
    selected = null;
    if (board.undo() != null) {
      for (final t in tubeComps) {
        t.unlockCheck();
        t.syncSealed();
      }
      onEvent(GameEvent.undo);
    }
  }

  void addTube() {
    board.addTube();
    final tc = TubeComponent(board.tubes.length - 1);
    tubeComps.add(tc);
    add(tc);
    _layout(size);
  }
}

/// Soft pastel dots behind the board.
class DotsBackground extends Component with HasGameReference<JellyGame> {
  DotsBackground() : super(priority: -10);
  static const _dots = [
    Color(0x33E0306E), Color(0x33F07F1A), Color(0x336CCB47),
    Color(0x336E4AD6), Color(0x33F2C230),
  ];

  @override
  void render(Canvas canvas) {
    final s = game.size;
    final rnd = Random(11);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * s.x, rnd.nextDouble() * s.y),
          3 + rnd.nextDouble() * 5, Paint()..color = _dots[i % _dots.length]);
    }
  }
}

class TubeComponent extends PositionComponent
    with TapCallbacks, HasGameReference<JellyGame> {
  final int index;
  int incoming = 0;
  // Spring-driven lift of the selected group (overshoots, then settles).
  final _lift = Spring();
  double get lift => _lift.value;
  double _time = 0;
  double _reveal = 0;
  double _done = 1; // 0 → 1 after completion: cap bounce + tube pop.
  bool _shownSealed = false;
  /// Per-slot landing wobble clocks (0 → 1).
  final Map<int, double> _land = {};
  TubeComponent(this.index);

  Tube get tube => game.board.tubes[index];
  double get k => game.k;

  double _slotTop(int slot) =>
      (_slotBottom * k) - (game.beanH + _beanGap * k) * (slot + 1) + _beanGap * k;

  Vector2 slotPos(int slot) =>
      position + Vector2((size.x - game.beanW) / 2, _slotTop(slot));

  @override
  void onMount() {
    super.onMount();
    _shownSealed = tube.sealed;
  }

  void shake() {
    add(SequenceEffect([
      MoveByEffect(Vector2(6, 0), EffectController(duration: .04)),
      MoveByEffect(Vector2(-12, 0), EffectController(duration: .08)),
      MoveByEffect(Vector2(6, 0), EffectController(duration: .04)),
    ]));
  }

  void pickUp() => _lift.velocity = 900; // kick upward; spring overshoots
  void putDown() {}
  void resetLift() => _lift.reset();

  void landed(int slot) {
    // The landing bean squashes hardest; beans under it jiggle in sympathy.
    for (var s = 0; s <= slot; s++) {
      _land[s] = s == slot ? 0 : -.04 * (slot - s);
    }
  }

  void reveal() => _reveal = 1;
  void complete() {
    _done = 0;
    _shownSealed = true;
    for (var s = 0; s < tube.stack.length; s++) {
      _land[s] = -.05 * s;
    }
  }

  void syncSealed() {
    if (!tube.sealed) _shownSealed = false;
  }

  void unlockCheck() {}

  @override
  void onTapDown(TapDownEvent event) => game.tapTube(index);

  @override
  void update(double dt) {
    _time += dt;
    final target = game.selected == index ? 18.0 * k : 0.0;
    _lift.update(dt, target);
    if (game.selected != index && lift.abs() < .1 && _lift.velocity.abs() < 1) {
      _lift.reset();
    }
    _reveal = max(0, _reveal - dt * 4); // 250 ms tear
    _done = min(1, _done + dt * 1.8);
    for (final s in _land.keys.toList()) {
      final v = _land[s]! + dt * 2.2;
      v >= 1 ? _land.remove(s) : _land[s] = v;
    }
  }

  @override
  void render(Canvas canvas) {
    final c = canvas;
    final locked = game.board.isLocked(index);
    final sealed = tube.sealed && incoming == 0 && _shownSealed;
    final flavour = sealed ? beanColors[tube.stack.first.type]! : null;

    // Completion pop: the whole tube springs bigger then settles.
    final pop = sealed ? 1 + .12 * wobble(_done, freq: 16, decay: 5) * (1 - _done) : 1.0;
    c.save();
    c.translate(size.x / 2, size.y);
    c.scale(pop, pop);
    c.translate(-size.x / 2, -size.y);

    final body = RRect.fromRectAndRadius(
        Rect.fromLTRB(0, _bodyTop * k, size.x, _bodyBottom * k),
        Radius.circular(18 * k));

    // Spout (glows once the tube is complete).
    final spout = Path()
      ..moveTo(size.x * .36, _bodyBottom * k - 2)
      ..lineTo(size.x * .64, _bodyBottom * k - 2)
      ..lineTo(size.x * .57, tubeH * k)
      ..lineTo(size.x * .43, tubeH * k)
      ..close();
    if (sealed) {
      final pulse = .55 + .45 * sin(_time * 4).abs();
      c.drawCircle(Offset(size.x / 2, (tubeH - 6) * k), 14 * k,
          Paint()
            ..color = const Color(0xFFE0306E).withValues(alpha: .45 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      // Soft halo in the flavour colour around the whole tube.
      c.drawRRect(
          body.inflate(4 * k),
          Paint()
            ..color = flavour!.withValues(alpha: .35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    c.drawPath(spout, Paint()..color = const Color(0xFFE0306E));

    // Clear body (tinted with the flavour once complete).
    c.drawRRect(body.shift(Offset(0, 3 * k)), Paint()..color = const Color(0x14000000));
    c.drawRRect(body, Paint()..color = const Color(0xBFFFFFFF));
    if (sealed) {
      c.drawRRect(body, Paint()..color = flavour!.withValues(alpha: .18));
    }
    if (locked) {
      _dashed(c, body);
    } else {
      c.drawRRect(
          body,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (sealed ? 3 : 2) * k
            ..color = sealed ? flavour! : const Color(0xFFD7E3EE));
    }

    // Beans.
    final stack = tube.stack;
    final group = game.selected == index ? game.board.groupSize(index) : 0;
    final visible = stack.length - incoming;
    final bw = game.beanW, bh = game.beanH;
    for (var i = 0; i < visible; i++) {
      final lifted = i >= stack.length - group;
      // Lifted beans hover with a gentle bob.
      final bob = lifted && game.selected == index ? sin(_time * 6 + i) * 1.5 * k : 0.0;
      final y = _slotTop(i) - (lifted ? lift + bob : 0);
      var r = Rect.fromLTWH((size.x - bw) / 2, y, bw, bh);
      final lt = _land[i];
      if (lt != null && lt >= 0) {
        // Squash and stretch about the bean's bottom edge.
        final w = wobble(lt);
        final sx = 1 + .16 * w, sy = 1 - .22 * w;
        r = Rect.fromLTRB(r.center.dx - bw * sx / 2, r.bottom - bh * sy,
            r.center.dx + bw * sx / 2, r.bottom);
      }
      paintBean(c, r, stack[i].type, hidden: stack[i].hidden);
      if (_reveal > 0 && i == visible - 1 && !stack[i].hidden) {
        paintPouch(c, r, tear: 1 - _reveal);
      }
    }

    // Vertical gloss strip.
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(7 * k, (_bodyTop + 14) * k, 5 * k, (_bodyBottom - _bodyTop - 34) * k),
            Radius.circular(3 * k)),
        Paint()..color = const Color(0x99FFFFFF));
    // A shine sweeps across the glass as the tube completes.
    if (sealed && _done < 1) {
      c.save();
      c.clipRRect(body);
      final x = -size.x + _done * size.x * 3;
      c.drawPath(
          Path()
            ..moveTo(x, body.bottom)
            ..lineTo(x + 18 * k, body.bottom)
            ..lineTo(x + 18 * k + size.x, body.top)
            ..lineTo(x + size.x, body.top)
            ..close(),
          Paint()..color = const Color(0x88FFFFFF));
      c.restore();
    }

    _drawCap(c, sealed, flavour);
    c.restore();

    if (locked) _padlock(c);
  }

  void _drawCap(Canvas c, bool sealed, Color? flavour) {
    // Open tubes show the cap tipped up on its left hinge; completing a tube
    // swings it shut with a bounce.
    final t = sealed ? Curves.bounceOut.transform(min(1, _done * 2.2)) : 0.0;
    final angle = -0.55 * (1 - t);
    final capRect = Rect.fromLTWH(-2 * k, 0, size.x + 4 * k, _capH * k);
    c.save();
    c.translate(capRect.left + 4 * k, capRect.bottom);
    c.rotate(angle);
    c.translate(-(capRect.left + 4 * k), -capRect.bottom);
    final rr = RRect.fromRectAndRadius(capRect, Radius.circular(6 * k));
    c.drawRRect(
        rr,
        Paint()
          ..shader = Gradient.linear(capRect.topCenter, capRect.bottomCenter,
              const [Color(0xFFF4F7FA), Color(0xFFB9C3CD)]));
    c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * k
          ..color = const Color(0xFF9AA6B2));
    c.drawLine(Offset(capRect.left + 8 * k, capRect.top + 5 * k),
        Offset(capRect.right - 8 * k, capRect.top + 5 * k),
        Paint()
          ..strokeWidth = 2 * k
          ..color = const Color(0xCCFFFFFF));
    c.restore();

    // Check badge pops onto the closed cap.
    if (sealed && flavour != null) {
      final s = Curves.elasticOut.transform(((_done - .3) / .7).clamp(0.0, 1.0));
      if (s > 0) {
        final ctr = Offset(size.x / 2, capRect.center.dy - 2 * k);
        final rad = 11 * k * s;
        c.drawCircle(ctr.translate(0, 2 * k), rad, Paint()..color = const Color(0x33000000));
        c.drawCircle(ctr, rad, Paint()..color = flavour);
        c.drawCircle(
            ctr,
            rad,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2 * k
              ..color = const Color(0xFFFFFFFF));
        c.drawPath(
            Path()
              ..moveTo(ctr.dx - rad * .45, ctr.dy)
              ..lineTo(ctr.dx - rad * .1, ctr.dy + rad * .35)
              ..lineTo(ctr.dx + rad * .5, ctr.dy - rad * .35),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6 * k * s
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFFFFFFFF));
      }
    }
  }

  void _dashed(Canvas c, RRect body) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * k
      ..color = const Color(0xFF7E625C);
    for (final m in (Path()..addRRect(body)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12 * k) {
        c.drawPath(m.extractPath(d, d + 7 * k), paint);
      }
    }
  }

  void _padlock(Canvas c) {
    final cx = size.x / 2, cy = (_bodyTop + _bodyBottom) / 2 * k;
    final ink = Paint()..color = const Color(0xFF7E625C);
    c.drawArc(
        Rect.fromCenter(center: Offset(cx, cy - 6 * k), width: 18 * k, height: 20 * k),
        pi, pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * k
          ..color = const Color(0xFF7E625C));
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx, cy + 6 * k), width: 28 * k, height: 22 * k),
            Radius.circular(5 * k)),
        ink);
    c.drawCircle(Offset(cx, cy + 5 * k), 3 * k, Paint()..color = const Color(0xFFFFF7EC));
    final pb = ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center, fontSize: 12 * k))
      ..pushStyle(TextStyle(color: const Color(0xFF7E625C), fontWeight: FontWeight.w800))
      ..addText('Fill ${tube.unlockAt}');
    final p = pb.build()..layout(ParagraphConstraints(width: size.x));
    c.drawParagraph(p, Offset(0, cy + 22 * k));
  }
}

/// One bean's trip: straight up out of the source tube's mouth, an arc over
/// the tubes, then a gravity drop in through the target's mouth.
class FlyingBean extends PositionComponent {
  final Ingredient type;
  final Vector2 start, end;
  final double exitY, enterY, w, h, delay;
  final VoidCallback onLand;
  double _t = 0;

  static const rise = .10, across = .13, fall = .12;
  static const total = rise + across + fall;

  FlyingBean({
    required this.type,
    required this.start,
    required this.end,
    required this.exitY,
    required this.enterY,
    required double width,
    required double height,
    required this.delay,
    required this.onLand,
  })  : w = width,
        h = height,
        super(priority: 10);

  @override
  void update(double dt) {
    _t += dt;
    if (_t - delay >= total) {
      removeFromParent();
      onLand();
    }
  }

  @override
  void render(Canvas canvas) {
    final t = max(0.0, _t - delay);
    late Offset p;
    var tilt = 0.0, sx = 1.0, sy = 1.0;
    if (t < rise) {
      // Accelerate up and stretch tall while leaving the tube.
      final u = Curves.easeOut.transform(t / rise);
      p = Offset(start.x, start.y + (exitY - start.y) * u);
      sx = 1 - .08 * sin(u * pi);
      sy = 1 + .12 * sin(u * pi);
    } else if (t < rise + across) {
      final u = Curves.easeInOut.transform((t - rise) / across);
      final top = min(exitY, enterY) - 26;
      // Quadratic Bézier hop between the two tube mouths.
      final a = Offset(start.x, exitY), b = Offset(end.x, enterY);
      final ctrl = Offset((a.dx + b.dx) / 2, top);
      p = a * ((1 - u) * (1 - u)) + ctrl * (2 * u * (1 - u)) + b * (u * u);
      tilt = (end.x - start.x).sign * .35 * sin(u * pi);
    } else {
      // Gravity drop into the target, stretching as it falls.
      final u = Curves.easeIn.transform((t - rise - across) / fall);
      p = Offset(end.x, enterY + (end.y - enterY) * u);
      sx = 1 - .1 * u;
      sy = 1 + .14 * u;
    }
    canvas.save();
    canvas.translate(p.dx + w / 2, p.dy + h / 2);
    canvas.rotate(tilt);
    canvas.scale(sx, sy);
    paintBean(canvas, Rect.fromCenter(center: Offset.zero, width: w, height: h), type);
    canvas.restore();
  }
}
