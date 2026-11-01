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

enum GameEvent { pick, drop, invalid, reveal, tubeComplete, won, stuck, undo }

/// Tube design size and inner geometry (all scaled by [JellyGame.k]).
const tubeW = 62.0, tubeH = 232.0;
const _capH = 18.0, _bodyTop = 14.0, _bodyBottom = 214.0, _slotBottom = 206.0;
const _beanGap = 4.0;

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
    children.whereType<FlyingGroup>().forEach((f) => f.removeFromParent());
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
    const gapX = 12.0, gapY = 24.0;
    k = min(
        min((size.x - gapX * (perRow + 1)) / (perRow * tubeW),
            (size.y - 24 - gapY * (rows - 1)) / (rows * tubeH)),
        1.15);
    final tw = tubeW * k, th = tubeH * k;
    final totalH = rows * th + (rows - 1) * gapY;
    final top = max(12.0, (size.y - totalH) / 2);
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
    final s = selected;
    if (s == null) {
      if (board.canPick(i)) {
        selected = i;
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
      return;
    }
    final before = board.completeCount;
    final hiddenBefore = _hiddenCount();
    final m = board.drop(s, i);
    if (m == null) {
      tubeComps[i].shake();
      onEvent(GameEvent.invalid);
      return;
    }
    selected = null;
    final type = board.tubes[i].top!.type;
    final from = tubeComps[s], to = tubeComps[i];
    to.incoming += m.count;
    add(FlyingGroup(
      type: type,
      count: m.count,
      start: from.slotPos(board.tubes[s].stack.length + m.count - 1) -
          Vector2(0, 16),
      end: to.slotPos(board.tubes[i].stack.length - 1),
      width: beanW,
      height: beanH,
      gap: _beanGap * k,
      onDone: () {
        to.incoming -= m.count;
        to.squash();
        _haptic(true);
        if (m.sealedTarget) {
          to.closeCap();
          _sparkle(to);
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
    if (_hiddenCount() < hiddenBefore) {
      from.reveal();
      onEvent(GameEvent.reveal);
    }
    onEvent(GameEvent.drop);
  }

  int _hiddenCount() =>
      board.tubes.fold(0, (a, t) => a + t.stack.where((x) => x.hidden).length);

  void _sparkle(TubeComponent t) {
    final r = Random();
    final colors = beanColors.values.toList();
    add(ParticleSystemComponent(
      position: t.position + Vector2(t.size.x / 2, 10 * k),
      particle: Particle.generate(
        count: 12,
        lifespan: .6,
        generator: (_) => AcceleratedParticle(
          acceleration: Vector2(0, 120),
          speed: Vector2((r.nextDouble() - .5) * 120, -60 - r.nextDouble() * 60),
          child: CircleParticle(
              radius: 2 + r.nextDouble() * 2.5,
              paint: Paint()..color = colors[r.nextInt(colors.length)]),
        ),
      ),
    ));
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

  bool get animating => children.whereType<FlyingGroup>().isNotEmpty;

  void doUndo() {
    if (animating) return;
    selected = null;
    if (board.undo() != null) {
      for (final t in tubeComps) {
        t.unlockCheck();
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
  double _lift = 0;
  double _squash = 0;
  double _reveal = 0;
  double _cap = 1; // 0 → 1: cap closing animation progress.
  double _glow = 0;
  TubeComponent(this.index);

  Tube get tube => game.board.tubes[index];
  double get k => game.k;

  double _slotTop(int slot) =>
      (_slotBottom * k) - (game.beanH + _beanGap * k) * (slot + 1) + _beanGap * k;

  Vector2 slotPos(int slot) =>
      position + Vector2((size.x - game.beanW) / 2, _slotTop(slot));

  void shake() {
    add(SequenceEffect([
      MoveByEffect(Vector2(6, 0), EffectController(duration: .04)),
      MoveByEffect(Vector2(-12, 0), EffectController(duration: .08)),
      MoveByEffect(Vector2(6, 0), EffectController(duration: .04)),
    ]));
  }

  void squash() => _squash = 1;
  void reveal() => _reveal = 1;
  void closeCap() => _cap = 0;
  void unlockCheck() {}

  @override
  void onTapDown(TapDownEvent event) => game.tapTube(index);

  @override
  void update(double dt) {
    final target = game.selected == index ? 16.0 : 0.0;
    _lift += (target - _lift) * min(1, dt * 25);
    _squash = max(0, _squash - dt * 6);
    _reveal = max(0, _reveal - dt * 4); // 250 ms tear
    _cap = min(1, _cap + dt * 3.5);
    _glow += dt;
  }

  @override
  void render(Canvas canvas) {
    final c = canvas;
    final locked = game.board.isLocked(index);
    final sealed = tube.sealed && incoming == 0;
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
      final pulse = .55 + .45 * sin(_glow * 4).abs();
      c.drawCircle(Offset(size.x / 2, (tubeH - 6) * k), 14 * k,
          Paint()
            ..color = Color.fromRGBO(224, 48, 110, .45 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }
    c.drawPath(spout, Paint()..color = const Color(0xFFE0306E));

    // Clear body.
    c.drawRRect(body.shift(Offset(0, 3 * k)), Paint()..color = const Color(0x14000000));
    c.drawRRect(body, Paint()..color = const Color(0xBFFFFFFF));
    if (locked) {
      _dashed(c, body);
    } else {
      c.drawRRect(
          body,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * k
            ..color = const Color(0xFFD7E3EE));
    }

    // Beans.
    final stack = tube.stack;
    final group = game.selected == index ? game.board.groupSize(index) : 0;
    final visible = stack.length - incoming;
    final bw = game.beanW, bh = game.beanH;
    for (var i = 0; i < visible; i++) {
      final lifted = i >= stack.length - group;
      final sq = (i == visible - 1) ? _squash * 3 * k : 0.0;
      final y = _slotTop(i) - (lifted ? _lift : 0);
      final r = Rect.fromLTWH((size.x - bw) / 2 - sq, y + sq, bw + sq * 2, bh - sq);
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

    _drawCap(c, sealed);

    if (locked) _padlock(c);
  }

  void _drawCap(Canvas c, bool sealed) {
    // Open tubes show the cap tipped up on its left hinge; completing a tube
    // swings it shut with a bounce.
    final t = sealed ? Curves.bounceOut.transform(_cap) : 0.0;
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

/// Group of beans arcing from one tube to another.
class FlyingGroup extends PositionComponent {
  final Ingredient type;
  final int count;
  final Vector2 start, end;
  final double w, h, gap;
  final VoidCallback onDone;
  double t = 0;
  static const dur = .22;

  FlyingGroup({
    required this.type,
    required this.count,
    required this.start,
    required this.end,
    required double width,
    required double height,
    required this.gap,
    required this.onDone,
  })  : w = width,
        h = height,
        super(priority: 10);

  @override
  void update(double dt) {
    t += dt / dur;
    if (t >= 1) {
      removeFromParent();
      onDone();
    }
  }

  @override
  void render(Canvas canvas) {
    final k = Curves.easeInOut.transform(t.clamp(0, 1));
    final p = start + (end - start) * k;
    final arc = sin(k * pi) * 60;
    for (var i = 0; i < count; i++) {
      paintBean(canvas, Rect.fromLTWH(p.x, p.y - arc + i * (h + gap), w, h), type);
    }
  }
}
