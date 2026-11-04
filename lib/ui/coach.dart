import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../app/theme.dart';
import '../game/bean_painter.dart';
import '../game/jelly_game.dart' show wobble;
import '../logic/board.dart';

/// One coach mark. Geometry is read through callbacks every frame (in the
/// overlay's coordinates), so it follows the board if the layout changes.
class CoachStep {
  final String text;
  final String? sub;
  /// Spotlight hole; null for no hole.
  final Rect? Function() target;
  /// Dim everything but the hole.
  final bool dim;
  /// Any tap closes the step (and nothing reaches the game).
  final bool tapToClose;
  /// Taps inside this area reach the game (guided moves); everything else
  /// is swallowed. Ignored for [tapToClose] and [passive] steps.
  final Rect? Function()? passThrough;
  /// No dim, no input lock: the game is fully playable (tips).
  final bool passive;
  /// Bubble sits above the target (else below).
  final bool above;
  /// Hand taps this point.
  final Offset? Function()? hand;
  /// Ghost drag: a bean of this type travels from the first to the second
  /// point along a dotted arc, with the hand.
  final (Offset, Offset, Ingredient)? Function()? drag;
  final bool skippable;

  const CoachStep({
    required this.text,
    this.sub,
    required this.target,
    this.dim = true,
    this.tapToClose = false,
    this.passThrough,
    this.passive = false,
    this.above = true,
    this.hand,
    this.drag,
    this.skippable = true,
  });
}

class CoachOverlay extends StatefulWidget {
  final CoachStep step;
  final VoidCallback onSkip;
  final VoidCallback onClose;
  /// Bumped by the game when a blocked tube is tapped: the hand wobbles.
  final ValueNotifier<int> nudge;
  const CoachOverlay({
    super.key,
    required this.step,
    required this.onSkip,
    required this.onClose,
    required this.nudge,
  });

  @override
  State<CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<CoachOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 60))
        ..repeat();
  double _nudgeAt = -10;
  DateTime _shownAt = DateTime.now();

  double get _t => _clock.lastElapsedDuration == null
      ? 0
      : _clock.lastElapsedDuration!.inMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    widget.nudge.addListener(_onNudge);
  }

  @override
  void didUpdateWidget(CoachOverlay old) {
    super.didUpdateWidget(old);
    if (old.nudge != widget.nudge) {
      old.nudge.removeListener(_onNudge);
      widget.nudge.addListener(_onNudge);
    }
    if (old.step != widget.step) _shownAt = DateTime.now();
  }

  void _onNudge() => _nudgeAt = _t;

  @override
  void dispose() {
    widget.nudge.removeListener(_onNudge);
    _clock.dispose();
    super.dispose();
  }

  void _tapToClose() {
    // Ignore the tail of the tap that opened the step.
    if (DateTime.now().difference(_shownAt).inMilliseconds < 350) return;
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) => LayoutBuilder(builder: (context, box) {
        final step = widget.step;
        final size = box.biggest;
        final target = step.target();
        final t = _t;
        final bubbleW = min(300.0, size.width - 32);
        final cx = (target?.center.dx ?? size.width / 2);
        final left = (cx - bubbleW / 2).clamp(16.0, size.width - 16 - bubbleW);
        final hole = target?.inflate(8);
        final drag = step.drag?.call();
        final hand = step.hand?.call();

        Widget gate;
        if (step.passive) {
          gate = const SizedBox.shrink();
        } else {
          gate = _HitGate(
            pass: step.tapToClose ? null : step.passThrough?.call(),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: step.tapToClose ? _tapToClose : () => _onNudge(),
            ),
          );
        }

        // Hand position: tap bob, or travelling along the drag arc.
        Offset? handAt;
        var handScale = 1.0;
        var ghost = 0.0;
        if (drag != null) {
          final (a, b, _) = drag;
          final u = (t % 2.2) / 2.2;
          if (u < .15) {
            handAt = a;
            handScale = 1 - .12 * (u / .15);
          } else if (u < .75) {
            final v = Curves.easeInOut.transform((u - .15) / .6);
            handAt = _arc(a, b, v);
            handScale = .88;
            ghost = v;
          } else {
            handAt = b;
            handScale = .88 + .12 * ((u - .75) / .25);
            ghost = 1;
          }
        } else if (hand != null) {
          handAt = hand;
          handScale = 1 - .12 * (sin(t * 2 * pi / 1.1).abs());
        }
        final nudgeT = (t - _nudgeAt) / .6;
        final nudgeX = nudgeT >= 0 && nudgeT < 1 ? 10 * wobble(nudgeT) * sin(nudgeT * 30) : 0.0;

        const handSize = 48.0;
        return Stack(children: [
          Positioned.fill(child: gate),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CoachPainter(
                  hole: hole,
                  dim: step.dim && !step.passive,
                  ring: hole != null,
                  drag: drag,
                  ghost: ghost,
                  pulse: .5 + .5 * sin(t * 4),
                ),
              ),
            ),
          ),
          if (handAt != null)
            Positioned(
              // Fingertip of touch_app sits at about (0.42, 0.08) of the icon.
              left: handAt.dx - handSize * .42 + nudgeX,
              top: handAt.dy - handSize * .08,
              child: IgnorePointer(
                child: Transform.scale(
                  scale: handScale,
                  alignment: const Alignment(-.16, -.84),
                  child: const Icon(Icons.touch_app_rounded,
                      size: handSize,
                      color: C.text,
                      shadows: [Shadow(color: Colors.white, blurRadius: 8)]),
                ),
              ),
            ),
          Positioned(
            left: left,
            width: bubbleW,
            top: target == null
                ? 12
                : (step.above ? null : hole!.bottom + 14),
            bottom: target != null && step.above
                ? size.height - hole!.top + 14
                : null,
            child: GestureDetector(
              onTap: step.tapToClose ? _tapToClose : null,
              child: _Bubble(
                text: step.text,
                sub: step.sub,
                onSkip: step.skippable ? widget.onSkip : null,
              ),
            ),
          ),
          if (target != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PointerPainter(
                    x: cx.clamp(left + 24, left + bubbleW - 24),
                    y: step.above ? hole!.top - 14 : hole!.bottom + 14,
                    up: !step.above,
                  ),
                ),
              ),
            ),
        ]);
      }),
    );
  }
}

Offset _arc(Offset a, Offset b, double u) {
  final ctrl = Offset((a.dx + b.dx) / 2, min(a.dy, b.dy) - 60);
  return a * ((1 - u) * (1 - u)) + ctrl * (2 * u * (1 - u)) + b * (u * u);
}

class _Bubble extends StatelessWidget {
  final String text;
  final String? sub;
  final VoidCallback? onSkip;
  const _Bubble({required this.text, this.sub, this.onSkip});

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: C.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: C.border, width: 2),
            boxShadow: const [BoxShadow(color: C.border, offset: Offset(0, 4))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: C.text)),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: C.text2)),
            ],
          ]),
        ),
        if (onSkip != null)
          Positioned(
            right: -8,
            top: -26,
            child: Semantics(
              button: true,
              label: 'Skip tutorial step',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSkip,
                // 48 dp target around a small chip.
                child: Container(
                  width: 64,
                  height: S.minTouch,
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: C.text,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Text('Skip',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ),
          ),
      ]);
}

class _PointerPainter extends CustomPainter {
  final double x, y;
  final bool up;
  _PointerPainter({required this.x, required this.y, required this.up});

  @override
  void paint(Canvas c, Size s) {
    final d = up ? -1.0 : 1.0;
    // Triangle from the bubble edge (y) towards the target.
    final tri = Path()
      ..moveTo(x - 10, y - d * 2)
      ..lineTo(x, y + d * 10)
      ..lineTo(x + 10, y - d * 2)
      ..close();
    c.drawPath(tri, Paint()..color = C.panel);
    c.drawPath(
        Path()
          ..moveTo(x - 10, y)
          ..lineTo(x, y + d * 10)
          ..lineTo(x + 10, y),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = C.border);
  }

  @override
  bool shouldRepaint(_PointerPainter o) => o.x != x || o.y != y || o.up != up;
}

class _CoachPainter extends CustomPainter {
  final Rect? hole;
  final bool dim, ring;
  final (Offset, Offset, Ingredient)? drag;
  final double ghost, pulse;
  _CoachPainter({
    required this.hole,
    required this.dim,
    required this.ring,
    required this.drag,
    required this.ghost,
    required this.pulse,
  });

  @override
  void paint(Canvas c, Size s) {
    final rr = hole == null
        ? null
        : RRect.fromRectAndRadius(hole!, const Radius.circular(20));
    if (dim) {
      final p = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & s);
      if (rr != null) p.addRRect(rr);
      c.drawPath(p, Paint()..color = C.coachDim);
    }
    if (rr != null && ring && dim) {
      c.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withValues(alpha: .7 + .3 * pulse));
    }
    final d = drag;
    if (d != null) {
      final (a, b, type) = d;
      // Dotted arc.
      final dot = Paint()..color = C.accent.withValues(alpha: .8);
      for (var u = 0.0; u <= 1.0; u += .06) {
        c.drawCircle(_arc(a, b, u), 2.5, dot);
      }
      // Arrow head at the end.
      final e = _arc(a, b, .97);
      final dir = (b - e) / (b - e).distance;
      final n = Offset(-dir.dy, dir.dx);
      c.drawPath(
          Path()
            ..moveTo(b.dx, b.dy)
            ..lineTo(b.dx - dir.dx * 10 + n.dx * 6, b.dy - dir.dy * 10 + n.dy * 6)
            ..lineTo(b.dx - dir.dx * 10 - n.dx * 6, b.dy - dir.dy * 10 - n.dy * 6)
            ..close(),
          dot);
      if (ghost > 0 && ghost < 1) {
        final p = _arc(a, b, ghost);
        c.saveLayer(null, Paint()..color = const Color(0xB3000000));
        paintBean(c, Rect.fromCenter(center: p.translate(0, -18), width: 30, height: 23), type);
        c.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_CoachPainter o) => true;
}

/// Swallows every pointer event except those inside [pass], which fall
/// through to the widgets below (the game board during a guided move).
class _HitGate extends SingleChildRenderObjectWidget {
  final Rect? pass;
  const _HitGate({required this.pass, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitGate(pass);

  @override
  void updateRenderObject(BuildContext context, _RenderHitGate r) => r.pass = pass;
}

class _RenderHitGate extends RenderProxyBox {
  Rect? pass;
  _RenderHitGate(this.pass);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (pass != null && pass!.contains(position)) return false;
    return super.hitTest(result, position: position);
  }
}
