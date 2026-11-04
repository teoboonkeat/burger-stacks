import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/services.dart';

import '../app/theme.dart' show C, S;
import '../logic/board.dart';
import '../logic/solver.dart';
import 'bean_painter.dart';
import 'spring.dart';

/// `land` fires once per bean as it settles in its new tube.
enum GameEvent { pick, drop, land, invalid, reveal, tubeComplete, won, stuck, undo }

/// Tube design size and inner geometry (all scaled by [JellyGame.k]).
const tubeW = 62.0, tubeH = 232.0;
const _capH = 18.0, _bodyTop = 14.0, _bodyBottom = 214.0, _slotBottom = 206.0;
const _beanGap = 4.0;

/// How far the selected group rises (design px, scaled by k).
const liftHeight = 26.0;

/// Most tubes in one row; more wrap onto a second row.
const maxPerRow = 6;

/// Damped spring used for every jelly wobble: starts at 1, rings out to 0.
double wobble(double t, {double freq = 20, double decay = 7}) =>
    t >= 1 ? 0 : exp(-decay * t) * cos(freq * t);

class JellyGame extends FlameGame {
  Board board;
  final void Function(GameEvent e) onEvent;
  /// Called with a short, player-facing reason when a tap on [tube] is
  /// refused.
  final void Function(String reason, int tube)? onRefuse;
  /// Tutorial filter: when set, only tubes it accepts take input; a tap on
  /// any other tube calls [onBlocked] and does nothing else (no refusal).
  bool Function(int tube)? allowTube;
  void Function(int tube)? onBlocked;
  /// The next pouch to open tears slowly (first pouch in the tutorial).
  bool slowNextReveal = false;
  bool haptics;
  /// When true, beans can also be dragged from tube to tube.
  bool dragEnabled;
  /// Finger position while a group is being dragged (game coordinates).
  Vector2? dragPos;
  bool get dragging => dragPos != null && selected != null;
  int? selected;
  double k = 1;
  final List<TubeComponent> tubeComps = [];

  JellyGame(this.board,
      {required this.onEvent,
      this.onRefuse,
      this.haptics = true,
      this.dragEnabled = true});

  @override
  Color backgroundColor() => C.bg;

  /// Tube [i]'s box in game (widget-local) coordinates.
  Rect tubeRect(int i) {
    final t = tubeComps[i];
    return Rect.fromLTWH(t.position.x, t.position.y, t.size.x, t.size.y);
  }

  /// Top-left of bean slot [slot] in tube [i] and the bean size, for
  /// pointing at a bean (tutorial hand).
  Rect slotRect(int i, int slot) {
    final p = tubeComps[i].slotPos(slot);
    return Rect.fromLTWH(p.x, p.y, beanW, beanH);
  }

  @override
  Future<void> onLoad() async {
    add(DotsBackground());
    add(DragGhost());
    _build();
  }

  void reset(Board b) {
    board = b;
    selected = null;
    dragPos = null;
    _build();
  }

  void _build() {
    for (final t in tubeComps) {
      t.removeFromParent();
    }
    children.whereType<FlyingBean>().forEach((f) => f.removeFromParent());
    _flying = 0;
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
    final rows = (n / maxPerRow).ceil();
    final perRow = (n / rows).ceil();
    const gapX = 12.0, gapY = 34.0;
    // Leave headroom above the top row for beans arcing over the tubes.
    final headroom = 40.0;
    // One scale for every level at a given screen size: size the tubes as
    // if the board were full ([maxPerRow] per row, two rows), so a 4-tube
    // level shows the same beans as an 8-tube one (or after Extra tube).
    final kRows = max(2, rows);
    k = min(
        min((size.x - gapX * (maxPerRow + 1)) / (maxPerRow * tubeW),
            (size.y - headroom - 16 - gapY * (kRows - 1)) / (kRows * tubeH)),
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

  static String _name(Ingredient t) =>
      t.name[0].toUpperCase() + t.name.substring(1);

  String _lockReason(int i) {
    final need = board.tubes[i].unlockAt! - board.completeCount;
    return 'Locked: finish $need more tube${need == 1 ? '' : 's'} to open';
  }

  String _pickReason(int i) {
    final t = board.tubes[i];
    if (t.sealed) return 'This tube is finished';
    if (board.isLocked(i)) return _lockReason(i);
    if (t.top?.hidden ?? false) return 'Hidden bean: uncover it first';
    return "Can't pick that up";
  }

  String _dropReason(int from, int to) {
    final t = board.tubes[to];
    if (t.sealed) return 'This tube is finished';
    if (board.isLocked(to)) return _lockReason(to);
    if (t.stack.length >= board.capacity) return 'That tube is full';
    final top = t.top;
    if (top != null && top.hidden) return 'Only empty tubes or matching tops';
    if (top != null) {
      final mine = board.tubes[from].top!.type;
      return 'Top must match: ${_name(mine)} can only go on ${_name(mine)}';
    }
    return "Can't move there";
  }

  /// Where the bottom bean of the dragged group (index [j] from the bottom)
  /// is drawn, top-left corner. The group floats just above the finger.
  Vector2 ghostSlot(int j) {
    final p = dragPos!;
    return Vector2(p.x - beanW / 2,
        p.y - beanH * 1.6 - (beanH + _beanGap * k) * j);
  }

  void dragStart(int i, Vector2 at) {
    if (!dragEnabled || !inputEnabled || board.isWon) return;
    // The tap-down on this tube already ran; it may have picked it up,
    // put it down, or dropped another tube's beans into it.
    if (selected == null && board.canPick(i) && tubeComps[i].incoming == 0) {
      tapTube(i);
    }
    if (selected == i) dragPos = at.clone();
  }

  void dragUpdate(Vector2 delta) => dragPos?.add(delta);

  void dragEnd() {
    final at = dragPos, s = selected;
    if (at == null) return;
    dragPos = null;
    if (s == null) return;
    final target = _tubeAt(at, s);
    if (target == null || target == s) {
      // Dropped on nothing: settle the group back into its own tube.
      selected = null;
      tubeComps[s].putDown();
      return;
    }
    _dragFrom = at;
    tapTube(target);
    _dragFrom = null;
    // A refused drop leaves the group back in its tube, unselected.
    if (selected == s) {
      selected = null;
      tubeComps[s].resetLift();
    }
  }

  Vector2? _dragFrom;

  /// Tube under [p], forgiving: anywhere in a tube's column counts, using
  /// the nearest row when tubes are laid out in two rows.
  int? _tubeAt(Vector2 p, int source) {
    int? best;
    var bestD = double.infinity;
    for (var i = 0; i < tubeComps.length; i++) {
      final t = tubeComps[i];
      final pad = 8 * k;
      if (p.x < t.position.x - pad || p.x > t.position.x + t.size.x + pad) {
        continue;
      }
      final cy = t.position.y + t.size.y / 2;
      final d = (p.y - cy).abs();
      if (d < bestD && d < t.size.y) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void tapTube(int i) {
    if (!inputEnabled || board.isWon) return;
    final allow = allowTube;
    if (allow != null && !allow(i)) {
      onBlocked?.call(i);
      return;
    }
    final s = selected;
    if (s == null) {
      // Beans still dropping into a tube can't be lifted back out yet; it
      // can take more beans, though (see below).
      if (tubeComps[i].incoming > 0) {
        onRefuse?.call('Wait for the beans to land', i);
        return;
      }
      if (board.canPick(i)) {
        selected = i;
        tubeComps[i].pickUp();
        onEvent(GameEvent.pick);
        _haptic(false);
      } else if (board.tubes[i].stack.isNotEmpty || board.isLocked(i)) {
        tubeComps[i].shake();
        onEvent(GameEvent.invalid);
        onRefuse?.call(_pickReason(i), i);
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
    final group = board.groupSize(s);
    final m = board.drop(s, i);
    if (m == null) {
      final why = _dropReason(s, i);
      tubeComps[i].shake();
      onEvent(GameEvent.invalid);
      onRefuse?.call(why, i);
      return;
    }
    selected = null;
    final type = board.tubes[i].top!.type;
    final from = tubeComps[s], to = tubeComps[i];
    final lift = from.lift;
    from.resetLift();
    // Board state is already final; slots stay empty until their bean lands.
    // Earlier moves still dropping into this tube hold the slots below.
    for (var b = 0; b < m.count; b++) {
      to.pendingSlots.add(dstLen + b);
    }
    final dragFrom = _dragFrom;
    var landed = 0;
    _flying += m.count;
    // Beans leave top-first; the first one out falls deepest in the target.
    for (var b = 0; b < m.count; b++) {
      add(FlyingBean(
        type: type,
        from: from,
        to: to,
        srcSlot: srcLen - 1 - b,
        dstSlot: dstLen + b,
        lift: lift,
        delay: b * .05,
        startAt: dragFrom == null ? null : _ghostStart(dragFrom, group, b),
        onLand: () {
          _flying--;
          to.pendingSlots.remove(dstLen + b);
          to.landed(dstLen + b);
          landed++;
          onEvent(GameEvent.land);
          _haptic(landed == m.count);
          // Seal once every bean bound for the tube is in, whichever
          // move's beans arrive last.
          if (to.incoming == 0 && to.tube.sealed && !to.shownSealed) {
            to.complete();
            _celebrate(to);
            onEvent(GameEvent.tubeComplete);
          }
          if (landed == m.count && board.completeCount > before) {
            for (final t in tubeComps) {
              t.unlockCheck();
            }
          }
          // Judge the board once, after the last bean in the air lands.
          if (_flying > 0) return;
          if (board.isWon) {
            onEvent(GameEvent.won);
          } else if (isDeadEnd) {
            onEvent(GameEvent.stuck);
          }
        },
      ));
    }
    if (_hiddenCount() < hiddenBefore) {
      from.reveal(slow: slowNextReveal);
      slowNextReveal = false;
      onEvent(GameEvent.reveal);
    }
    onEvent(GameEvent.drop);
  }

  /// Start position of the [b]th bean (0 = top) of a dragged group of
  /// [group] beans released at [at].
  Vector2 _ghostStart(Vector2 at, int group, int b) {
    final saved = dragPos;
    dragPos = at;
    final v = ghostSlot(group - 1 - b);
    dragPos = saved;
    return v;
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

  /// Beans currently in the air.
  int _flying = 0;
  bool get animating => _flying > 0;

  /// False while the level is over (win shown): taps and drags do nothing.
  bool inputEnabled = true;

  /// True when the level can no longer be won from here: no legal move at
  /// all, or a bounded search proves every line of play is a dead end
  /// (e.g. only a bean shuttling back and forth). If the search is too big
  /// to finish quickly, the board gets the benefit of the doubt.
  bool get isDeadEnd {
    if (board.isWon) return false;
    if (!board.hasValidMove) return true;
    return Solver(maxStates: 5000).winnable(board) == false;
  }

  bool doUndo() {
    if (animating) return false;
    if (selected != null) tubeComps[selected!].putDown();
    selected = null;
    if (board.undo() == null) return false;
    for (final t in tubeComps) {
      t.unlockCheck();
      t.syncSealed();
    }
    onEvent(GameEvent.undo);
    return true;
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
    with TapCallbacks, DragCallbacks, HasGameReference<JellyGame> {
  final int index;
  /// Slots whose bean is still in the air on its way here.
  final Set<int> pendingSlots = {};
  int get incoming => pendingSlots.length;
  // Spring-driven lift of the selected group (overshoots, then settles).
  final _lift = Spring();
  double get lift => _lift.value;
  double _time = 0;
  double _reveal = 0;
  /// Tear speed: 1 / duration in seconds.
  double _revealRate = 4;
  /// Padlock pop-off clock after the tube unlocks (1 = idle).
  double _unlock = 1;
  bool _wasLocked = false;
  /// Tear clock for pouches opened by completing the tube.
  double _sealTear = 0;
  final Set<int> _sealTorn = {};
  double _done = 1; // 0 → 1 after completion: cap bounce + tube pop.
  bool _shownSealed = false;
  bool get shownSealed => _shownSealed;
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
    _wasLocked = game.board.isLocked(index);
  }

  double _shake = 1;
  void shake() => _shake = 0;

  void pickUp() => _lift.velocity = 900; // kick upward; spring overshoots
  void putDown() {}
  void resetLift() => _lift.reset();

  void landed(int slot) {
    // The landing bean squashes hardest; beans under it jiggle in sympathy.
    for (var s = 0; s <= slot; s++) {
      _land[s] = s == slot ? 0 : -.04 * (slot - s);
    }
  }

  /// Pouch tear: 0.25 s, or 0.5 s for the first one the tutorial shows.
  void reveal({bool slow = false}) {
    _reveal = 1;
    _revealRate = slow ? 2 : 4;
  }
  void complete() {
    _done = 0;
    // A finished tube never keeps a pouch closed: tear them all open.
    _sealTorn
      ..clear()
      ..addAll([
        for (var s = 0; s < tube.stack.length; s++)
          if (tube.stack[s].hidden) s
      ]);
    if (_sealTorn.isNotEmpty) _sealTear = 1;
    _shownSealed = true;
    for (var s = 0; s < tube.stack.length; s++) {
      _land[s] = -.05 * s;
    }
  }

  void syncSealed() {
    if (!tube.sealed) _shownSealed = false;
  }

  /// Called when the completed count changes: a tube that just opened
  /// pops its padlock off; one locked again by Undo shows it at once.
  void unlockCheck() {
    final locked = game.board.isLocked(index);
    if (_wasLocked && !locked) _unlock = 0;
    if (locked) _unlock = 1;
    _wasLocked = locked;
  }

  @override
  void onTapDown(TapDownEvent event) => game.tapTube(index);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    game.dragStart(index, event.canvasPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) => game.dragUpdate(event.canvasDelta);

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    game.dragEnd();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    game.dragEnd();
  }

  @override
  void update(double dt) {
    _time += dt;
    final target = game.selected == index ? liftHeight * k : 0.0;
    _lift.update(dt, target);
    if (game.selected != index && lift.abs() < .1 && _lift.velocity.abs() < 1) {
      _lift.reset();
    }
    _reveal = max(0, _reveal - dt * _revealRate);
    _unlock = min(1, _unlock + dt * 1.6);
    _shake = min(1, _shake + dt / .16);
    _sealTear = max(0, _sealTear - dt * 4);
    _done = min(1, _done + dt * 1.8);
    for (final s in _land.keys.toList()) {
      final v = _land[s]! + dt * 2.2;
      v >= 1 ? _land.remove(s) : _land[s] = v;
    }
  }

  @override
  void render(Canvas canvas) {
    final c = canvas;
    // Drawn lock state flips when the opening tube's beans land (see
    // unlockCheck), so the padlock pops off at that moment.
    final locked = _wasLocked;
    final sealed = tube.sealed && incoming == 0 && _shownSealed;
    final flavour = sealed ? beanColors[tube.stack.first.type]! : null;

    // Completion pop: the whole tube springs bigger then settles.
    final pop = sealed ? 1 + .12 * wobble(_done, freq: 16, decay: 5) * (1 - _done) : 1.0;
    c.save();
    if (_shake < 1) c.translate(sin(_shake * pi * 3) * 6 * k, 0);
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
            ..color = C.accent.withValues(alpha: .45 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      // Soft halo in the flavour colour around the whole tube.
      c.drawRRect(
          body.inflate(4 * k),
          Paint()
            ..color = flavour!.withValues(alpha: .35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    }
    c.drawPath(spout, Paint()..color = C.accent);

    // Clear body (tinted with the flavour once complete).
    c.drawRRect(body.shift(Offset(0, 3 * k)), Paint()..color = const Color(0x14000000));
    c.drawRRect(body, Paint()..color = const Color(0xBFFFFFFF));
    if (sealed) {
      c.drawRRect(body, Paint()..color = flavour!.withValues(alpha: .18));
    }
    final picked = game.selected == index;
    if (locked) {
      _dashed(c, body);
    } else if (picked) {
      // Selected source tube: raspberry ring with a soft glow.
      c.drawRRect(
          body.inflate(2 * k),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * k
            ..color = C.accent.withValues(alpha: .25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      c.drawRRect(
          body,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * k
            ..color = C.accent);
    } else {
      c.drawRRect(
          body,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = (sealed ? 3 : 2) * k
            ..color = sealed ? flavour! : C.glass);
    }

    // Beans.
    final stack = tube.stack;
    final group = game.selected == index ? game.board.groupSize(index) : 0;
    final bw = game.beanW, bh = game.beanH;
    // Soft shadow where the lifted group rests, so the lift reads as height.
    if (group > 0 && !game.dragging && lift > 1) {
      final rest = stack.length - group;
      final y = _slotTop(rest) + bh * .8;
      final a = (lift / (liftHeight * k)).clamp(0.0, 1.0);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(size.x / 2, y), width: bw * .8, height: bh * .25),
          Paint()
            ..color = C.text.withValues(alpha: .14 * a)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    }
    for (var i = 0; i < stack.length; i++) {
      if (pendingSlots.contains(i)) continue;
      final lifted = i >= stack.length - group;
      // While dragging, the lifted group is drawn under the finger instead.
      if (lifted && game.dragging) continue;
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
      paintBean(c, r, stack[i].type, hidden: stack[i].hidden && !sealed);
      if (_reveal > 0 && i == stack.length - 1 && !stack[i].hidden) {
        paintPouch(c, r, tear: 1 - _reveal);
      }
      if (sealed && _sealTear > 0 && _sealTorn.contains(i)) {
        paintPouch(c, r, tear: 1 - _sealTear);
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
    if (locked) {
      _padlock(c);
    } else if (_unlock < 1) {
      // Just opened: the padlock springs up and fades away.
      final u = Curves.easeOut.transform(_unlock);
      final sc = 1 + .35 * wobble(_unlock, freq: 14, decay: 6).abs();
      final cy = (_bodyTop + _bodyBottom) / 2 * k;
      c.save();
      c.translate(size.x / 2, cy - 40 * k * u);
      c.scale(sc, sc);
      c.translate(-size.x / 2, -cy);
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, 1 - u));
      _padlock(c, label: false);
      c.restore();
      c.restore();
    }
    c.restore();
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
      ..color = C.text2;
    for (final m in (Path()..addRRect(body)).computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12 * k) {
        c.drawPath(m.extractPath(d, d + 7 * k), paint);
      }
    }
  }

  /// Padlock with the number of tubes still to finish, plus a white
  /// "finish N tube(s)" label that never drops below [S.minBoardText].
  void _padlock(Canvas c, {bool label = true}) {
    final cx = size.x / 2, cy = (_bodyTop + _bodyBottom) / 2 * k;
    final need = max(1, (tube.unlockAt ?? 1) - game.board.completeCount);
    final ink = Paint()..color = C.text2;
    c.drawArc(
        Rect.fromCenter(center: Offset(cx, cy - 8 * k), width: 20 * k, height: 22 * k),
        pi, pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * k
          ..color = C.text2);
    final lock = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 6 * k), width: 32 * k, height: 26 * k),
        Radius.circular(6 * k));
    c.drawRRect(lock, ink);
    final n = _text('$need', max(11, 17 * k), C.bg, FontWeight.w900, lock.width);
    c.drawParagraph(n, Offset(lock.left, lock.center.dy - n.height / 2));
    if (!label) return;
    final fs = max(S.minBoardText, 12 * k);
    final p = _text(labelFor(need), fs, C.text, FontWeight.w800, size.x + 6 * k);
    final w = p.longestLine + 10, h = p.height + 6;
    final box = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, lock.bottom + 8 * k + h / 2), width: w, height: h),
        const Radius.circular(8));
    c.drawRRect(box, Paint()..color = C.panel);
    c.drawRRect(
        box,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = C.border);
    c.drawParagraph(p, Offset(cx - p.width / 2, box.top + 3));
  }

  /// Lock label text; two short lines so it fits a narrow tube.
  static String labelFor(int need) => 'finish\n$need tube${need == 1 ? '' : 's'}';

  static Paragraph _text(String s, double size, Color col, FontWeight w, double width) {
    final pb = ParagraphBuilder(ParagraphStyle(textAlign: TextAlign.center, fontSize: size, height: 1.1))
      ..pushStyle(TextStyle(color: col, fontWeight: w))
      ..addText(s);
    return pb.build()..layout(ParagraphConstraints(width: width));
  }
}

/// One bean's trip: straight up out of the source tube's mouth, an arc over
/// the tubes, then a gravity drop in through the target's mouth.
/// Positions are read from the tubes every frame, so a relayout mid-flight
/// (extra tube, HUD resize) can't strand the bean.
class FlyingBean extends PositionComponent with HasGameReference<JellyGame> {
  final Ingredient type;
  final TubeComponent from, to;
  final int srcSlot, dstSlot;
  final double lift, delay;
  final VoidCallback onLand;
  /// Set when released from a drag: start here and skip the rise.
  final Vector2? startAt;
  double _t = 0;

  static const rise = .10, across = .13, fall = .12;
  static const total = rise + across + fall;

  FlyingBean({
    required this.type,
    required this.from,
    required this.to,
    required this.srcSlot,
    required this.dstSlot,
    required this.lift,
    required this.delay,
    required this.onLand,
    this.startAt,
  }) : super(priority: 10);

  /// A dragged bean just glides straight into its slot.
  static const glide = .14;
  double get _duration => startAt != null ? glide : total;

  @override
  void update(double dt) {
    _t += dt;
    if (_t - (startAt != null ? 0 : delay) >= _duration) {
      removeFromParent();
      onLand();
    }
  }

  @override
  void render(Canvas canvas) {
    final w = game.beanW, h = game.beanH, k = game.k;
    final start = startAt ?? from.slotPos(srcSlot) - Vector2(0, lift);
    final end = to.slotPos(dstSlot);
    final exitY = startAt?.y ?? from.position.y - h - 6 * k;
    final enterY = to.position.y - h - 6 * k;
    final t = max(0.0, _t - delay);
    late Offset p;
    var tilt = 0.0, sx = 1.0, sy = 1.0;
    if (startAt != null) {
      final u = Curves.easeOutCubic.transform((_t / glide).clamp(0.0, 1.0));
      p = Offset(start.x + (end.x - start.x) * u, start.y + (end.y - start.y) * u);
    } else if (t < rise) {
      // Accelerate up and stretch tall while leaving the tube.
      final u = Curves.easeOut.transform(t / rise);
      p = Offset(start.x, start.y + (exitY - start.y) * u);
      sx = 1 - .08 * sin(u * pi);
      sy = 1 + .12 * sin(u * pi);
    } else if (t < rise + across) {
      final u = Curves.easeInOut.transform((t - rise) / across);
      final top = min(exitY, enterY) - 26;
      // Quadratic Bezier hop between the two tube mouths.
      final a = Offset(start.x, exitY), b = Offset(end.x, enterY);
      final ctrl = Offset((a.dx + b.dx) / 2, top);
      p = a * ((1 - u) * (1 - u)) + ctrl * (2 * u * (1 - u)) + b * (u * u);
      tilt = (end.x - start.x).sign * .35 * sin(u * pi);
    } else {
      // Gravity drop into the target, stretching as it falls.
      final u = Curves.easeIn.transform(((t - rise - across) / fall).clamp(0.0, 1.0));
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

/// The dragged group, drawn under the player's finger.
class DragGhost extends Component with HasGameReference<JellyGame> {
  DragGhost() : super(priority: 20);

  @override
  void render(Canvas canvas) {
    final s = game.selected;
    if (!game.dragging || s == null) return;
    final n = game.board.groupSize(s);
    final type = game.board.tubes[s].top?.type;
    if (n == 0 || type == null) return;
    final w = game.beanW, h = game.beanH;
    for (var j = 0; j < n; j++) {
      final p = game.ghostSlot(j);
      final r = Rect.fromLTWH(p.x, p.y, w, h);
      canvas.drawOval(r.shift(Offset(0, 6 * game.k)).deflate(2),
          Paint()..color = const Color(0x22000000));
      paintBean(canvas, r, type);
    }
  }
}
