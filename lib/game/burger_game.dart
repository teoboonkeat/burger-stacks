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
import 'ingredient_painter.dart';

enum GameEvent { pick, drop, invalid, reveal, plateComplete, won, stuck, undo }

class BurgerGame extends FlameGame {
  Board board;
  final void Function(GameEvent e) onEvent;
  bool haptics;
  int? selected;
  final List<PlateComponent> plateComps = [];

  BurgerGame(this.board, {required this.onEvent, this.haptics = true});

  @override
  Color backgroundColor() => const Color(0xFFFFF4E2);

  @override
  Future<void> onLoad() async => _build();

  void reset(Board b) {
    board = b;
    selected = null;
    _build();
  }

  void _build() {
    for (final p in plateComps) {
      p.removeFromParent();
    }
    children.whereType<FlyingGroup>().forEach((f) => f.removeFromParent());
    plateComps.clear();
    for (var i = 0; i < board.plates.length; i++) {
      final pc = PlateComponent(i);
      plateComps.add(pc);
      add(pc);
    }
    if (hasLayout) _layout(size);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _layout(size);
  }

  void _layout(Vector2 size) {
    final n = plateComps.length;
    if (n == 0) return;
    final rows = n > 6 ? 2 : 1;
    final perRow = (n / rows).ceil();
    final pw = min(92.0, size.x / perRow - 10);
    final ph = pieceH * (board.capacity + 1.6) + 18;
    final totalH = rows * ph + (rows - 1) * 28;
    final top = max(20.0, (size.y - totalH) / 2);
    for (var i = 0; i < n; i++) {
      final row = i ~/ perRow;
      final inRow = row == rows - 1 ? n - perRow * (rows - 1) : perRow;
      final col = i % perRow;
      final rowW = inRow * (pw + 10) - 10;
      final x = (size.x - rowW) / 2 + col * (pw + 10);
      plateComps[i]
        ..size = Vector2(pw, ph)
        ..position = Vector2(x, top + row * (ph + 28));
    }
  }

  double get pieceH => 24;

  void _haptic(bool heavy) {
    if (!haptics) return;
    heavy ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
  }

  void tapPlate(int i) {
    if (board.isWon) return;
    final s = selected;
    if (s == null) {
      if (board.canPick(i)) {
        selected = i;
        onEvent(GameEvent.pick);
        _haptic(false);
      } else if (board.plates[i].stack.isNotEmpty || board.isLocked(i)) {
        plateComps[i].shake();
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
      plateComps[i].shake();
      onEvent(GameEvent.invalid);
      return;
    }
    selected = null;
    final type = board.plates[i].top!.type;
    final from = plateComps[s], to = plateComps[i];
    to.incoming += m.count;
    add(FlyingGroup(
      type: type,
      count: m.count,
      start: from.topSlotPos(board.plates[s].stack.length + m.count - 1) - Vector2(0, 16),
      end: to.topSlotPos(board.plates[i].stack.length - 1),
      width: from.size.x - 16,
      height: pieceH,
      onDone: () {
        to.incoming -= m.count;
        to.squash();
        _haptic(true);
        if (m.sealedTarget) {
          to.bunDrop();
          _steam(to);
          onEvent(GameEvent.plateComplete);
        }
        if (board.completeCount > before) {
          for (final p in plateComps) {
            p.lockChanged();
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

  int _hiddenCount() => board.plates
      .fold(0, (a, p) => a + p.stack.where((x) => x.hidden).length);

  void _steam(PlateComponent p) {
    final r = Random();
    add(ParticleSystemComponent(
      position: p.position + Vector2(p.size.x / 2, p.size.y - pieceH * 5.5),
      particle: Particle.generate(
        count: 10,
        lifespan: .6,
        generator: (_) => AcceleratedParticle(
          speed: Vector2((r.nextDouble() - .5) * 60, -40 - r.nextDouble() * 40),
          child: CircleParticle(
              radius: 3 + r.nextDouble() * 3,
              paint: Paint()..color = const Color(0x99FFFFFF)),
        ),
      ),
    ));
  }

  void confetti() {
    final r = Random();
    add(ParticleSystemComponent(
      position: Vector2(size.x / 2, size.y * .3),
      particle: Particle.generate(
        count: 60,
        lifespan: 1.4,
        generator: (_) => AcceleratedParticle(
          acceleration: Vector2(0, 300),
          speed: Vector2((r.nextDouble() - .5) * 400, -200 - r.nextDouble() * 200),
          child: ComputedParticle(
            renderer: (c, part) => c.drawOval(
                Rect.fromCenter(center: Offset.zero, width: 7, height: 3.5),
                Paint()..color = const Color(0xFFFFF4D6)),
          ),
        ),
      ),
    ));
  }

  bool get animating => children.whereType<FlyingGroup>().isNotEmpty;

  void doUndo() {
    if (animating) return;
    selected = null;
    if (board.undo() != null) {
      for (final p in plateComps) {
        p.lockChanged();
      }
      onEvent(GameEvent.undo);
    }
  }

  void addPlate() {
    board.addPlate();
    final pc = PlateComponent(board.plates.length - 1);
    plateComps.add(pc);
    add(pc);
    _layout(size);
  }
}

class PlateComponent extends PositionComponent
    with TapCallbacks, HasGameReference<BurgerGame> {
  final int index;
  int incoming = 0;
  double _lift = 0;
  double _squash = 0;
  double _reveal = 0;
  double _bun = 1;
  PlateComponent(this.index);

  Plate get plate => game.board.plates[index];

  Vector2 topSlotPos(int slot) {
    final ph = game.pieceH;
    return position +
        Vector2(8, size.y - 14 - ph * (slot + 1) - 2 * slot);
  }

  void shake() {
    add(SequenceEffect([
      MoveByEffect(Vector2(6, 0), EffectController(duration: .04)),
      MoveByEffect(Vector2(-12, 0), EffectController(duration: .08)),
      MoveByEffect(Vector2(6, 0), EffectController(duration: .04)),
    ]));
  }

  void squash() => _squash = 1;
  void reveal() => _reveal = 1;
  void bunDrop() => _bun = 0;
  void lockChanged() {}

  @override
  void onTapDown(TapDownEvent event) => game.tapPlate(index);

  @override
  void update(double dt) {
    final target = game.selected == index ? 16.0 : 0.0;
    _lift += (target - _lift) * min(1, dt * 25);
    _squash = max(0, _squash - dt * 6);
    _reveal = max(0, _reveal - dt * 4);
    _bun = min(1, _bun + dt * 4);
  }

  @override
  void render(Canvas canvas) {
    final c = canvas;
    final ph = game.pieceH;
    final locked = game.board.isLocked(index);
    // Plate dish.
    final dish = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.y - 16, size.x, 14), const Radius.circular(7));
    c.drawRRect(dish.shift(const Offset(0, 3)), Paint()..color = const Color(0x22000000));
    c.drawRRect(dish, Paint()..color = const Color(0xFFFFFFFF));
    c.drawRRect(
        dish,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFE6D2B2));
    final stack = plate.stack;
    final group = game.selected == index ? game.board.groupSize(index) : 0;
    final visible = stack.length - incoming;
    for (var i = 0; i < visible; i++) {
      final lifted = i >= stack.length - group;
      final sq = (i == visible - 1) ? _squash * 3 : 0.0;
      final y = size.y - 14 - ph * (i + 1) - 2 * i - (lifted ? _lift : 0);
      final r = Rect.fromLTWH(8 - sq, y + sq, size.x - 16 + sq * 2, ph - sq);
      if (lifted) {
        c.drawRRect(
            RRect.fromRectAndRadius(r.shift(const Offset(0, 6)), const Radius.circular(10)),
            Paint()..color = const Color(0x22000000));
      }
      paintIngredient(c, r, stack[i].type, hidden: stack[i].hidden);
      if (_reveal > 0 && i == visible - 1 && !stack[i].hidden) {
        // Fading dome lifting off the just-revealed piece.
        c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, _reveal));
        paintIngredient(c, r.shift(Offset(0, -(1 - _reveal) * 20)), stack[i].type, hidden: true);
        c.restore();
      }
    }
    if (plate.sealed && incoming == 0) {
      final i = stack.length;
      final y = size.y - 14 - ph * (i + 1) - 2 * i;
      final drop = (1 - Curves.bounceOut.transform(_bun)) * 60;
      paintBun(c, Rect.fromLTWH(6, y - drop, size.x - 12, ph + 4));
    }
    if (locked) {
      final box = Rect.fromLTWH(0, size.y - 16 - ph * 4.5, size.x, ph * 4.5);
      c.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(12)),
          Paint()..color = const Color(0x553B2A1E));
      final pb = ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center, fontSize: 14))
        ..pushStyle(TextStyle(color: const Color(0xFFFFFFFF), fontWeight: FontWeight.w800))
        ..addText('🔒\nFinish ${plate.unlockAt}');
      final p = pb.build()..layout(ParagraphConstraints(width: size.x));
      c.drawParagraph(p, Offset(0, box.center.dy - p.height / 2));
    }
  }
}

/// Group of pieces arcing from one plate to another.
class FlyingGroup extends PositionComponent {
  final Ingredient type;
  final int count;
  final Vector2 start, end;
  final double w, h;
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
    final c = canvas;
    final k = Curves.easeInOut.transform(t.clamp(0, 1));
    final p = start + (end - start) * k;
    final arc = sin(k * pi) * 60;
    for (var i = 0; i < count; i++) {
      paintIngredient(
          c, Rect.fromLTWH(p.x, p.y - arc + i * (h + 2), w, h), type);
    }
  }
}
