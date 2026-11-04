import 'dart:async';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/ad_service.dart';
import '../app/sfx.dart';
import '../app/shop.dart';
import '../app/theme.dart';
import '../app/tutorial.dart';
import '../game/jelly_game.dart';
import '../levels/level.dart';
import '../logic/board.dart';
import 'coach.dart';
import 'screens.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  final Services s;
  final int level;
  const GameScreen(this.s, this.level, {super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

extension on Level {
  bool get hasPouch => tubes.any((t) => t.stack.any((k) => k.startsWith('?')));
  bool get hasLock => tubes.any((t) => t.unlockAt != null);
}

class _GameScreenState extends State<GameScreen> {
  late int level = widget.level;
  late JellyGame game;
  late AdService ads = AdService(widget.s.state);
  int moves = 0;
  int undosLeft = 1;
  int undosUsed = 0;
  bool peekUsed = false, extraUsed = false, restarted = false;

  /// Set the moment the level is won; boosters, restart and the board stay
  /// off until the result screen has been dealt with.
  bool showingResult = false;
  bool _stuckOpen = false;

  final _rootKey = GlobalKey();
  final _gameKey = GlobalKey();
  final _undoKey = GlobalKey();
  final _peekKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    game = JellyGame(
      _board(),
      onEvent: _onEvent,
      onRefuse: _onRefuse,
      haptics: widget.s.state.haptics,
      dragEnabled: widget.s.state.dragBeans,
    );
    game.onBlocked = (_) => _onBlocked();
    _startLessons();
  }

  @override
  void dispose() {
    _nudge.dispose();
    super.dispose();
  }

  Level get _lv => widget.s.levels[level - 1];
  Board _board() => _lv.toBoard();

  void _start({bool restart = false}) {
    setState(() {
      moves = 0;
      undosLeft = 1;
      undosUsed = 0;
      peekUsed = false;
      extraUsed = false;
      restarted = restart;
      showingResult = false;
      refusalVisible = false;
    });
    game.inputEnabled = true;
    game.reset(_board());
    _startLessons();
  }

  // ---------------------------------------------------------------- refusal

  /// Last refusal text and the tube it is about; kept while it fades out.
  String refusal = '';
  int refusalTube = 0;
  bool refusalVisible = false;
  int _refusalId = 0;

  void _onRefuse(String reason, int tube) {
    final id = ++_refusalId;
    setState(() {
      refusal = reason;
      refusalTube = tube;
      refusalVisible = true;
    });
    Future.delayed(S.refusalShown, () {
      if (mounted && id == _refusalId) setState(() => refusalVisible = false);
    });
  }

  // --------------------------------------------------------------- tutorial

  /// Lessons still to show in this level, in order.
  final List<Lesson> _queue = [];
  Lesson? _lesson;
  int _stepIx = 0;
  CoachStep? _coach;
  final _nudge = ValueNotifier<int>(0);
  bool _goalChip = false;
  bool _undoLessonDue = false;

  Set<Lesson> get _seen => widget.s.state.tutorialSeen;

  void _startLessons() {
    _queue
      ..clear()
      ..addAll(Tutorial.atStart(
          LevelFacts(level, hasPouch: _lv.hasPouch, hasLock: _lv.hasLock),
          _seen,
          dragOn: widget.s.state.dragBeans));
    _lesson = null;
    _coach = null;
    _goalChip = false;
    _undoLessonDue = Tutorial.showUndoAfterMove(level, _seen);
    game.allowTube = null;
    game.slowNextReveal = false;
    _nextLesson();
  }

  void _nextLesson() {
    if (_queue.isEmpty) {
      _setCoach(null, null);
      return;
    }
    final l = _queue.removeAt(0);
    if (l == Lesson.pouch) game.slowNextReveal = true;
    _setCoach(l, 0);
  }

  void _setCoach(Lesson? l, int? step) {
    _lesson = l;
    _stepIx = step ?? 0;
    final c = l == null ? null : _stepFor(l, _stepIx);
    game.allowTube = c == null ? null : _allowFor(l!, _stepIx);
    if (mounted) {
      setState(() => _coach = c);
    } else {
      _coach = c;
    }
  }

  /// Ends the current lesson, marks it seen and starts the next one.
  void _finishLesson() {
    final l = _lesson;
    if (l == null) return;
    widget.s.state.markSeen(l == Lesson.tap ? [Lesson.tap, Lesson.drop] : [l]);
    if (l == Lesson.tap) {
      _goalChip = true;
      Future.delayed(S.goalChip, () {
        if (mounted) setState(() => _goalChip = false);
      });
    }
    _nextLesson();
  }

  void _onBlocked() {
    _nudge.value++;
    // A drag released on a blocked tube drops the group back: start the
    // guided move again from the pick.
    scheduleMicrotask(_checkGuided);
  }

  void _checkGuided() {
    final l = _lesson;
    if ((l == Lesson.tap || l == Lesson.group) &&
        _stepIx == 1 &&
        game.selected == null) {
      _setCoach(l, 0);
    }
  }

  // Board geometry for the coach, in the overlay's coordinates.

  Offset? _gameOrigin() {
    final root = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    final g = _gameKey.currentContext?.findRenderObject() as RenderBox?;
    if (root == null || g == null || !g.hasSize) return null;
    return g.localToGlobal(Offset.zero, ancestor: root);
  }

  Rect? _gameArea() {
    final o = _gameOrigin();
    final g = _gameKey.currentContext?.findRenderObject() as RenderBox?;
    if (o == null || g == null) return null;
    return o & g.size;
  }

  /// Where taps still work during a guided move: the board and the HUD
  /// above it (Back and Restart stay usable).
  Rect? _guidedArea() {
    final r = _gameArea();
    return r == null ? null : Rect.fromLTRB(r.left, 0, r.right, r.bottom);
  }

  Rect? _tubeRect(int? i) {
    final o = _gameOrigin();
    if (o == null || i == null || i >= game.tubeComps.length || !game.hasLayout) {
      return null;
    }
    // Include the tipped-up cap, which rises above the tube's box.
    final r = game.tubeRect(i).shift(o);
    return Rect.fromLTRB(r.left, r.top - r.width * .45, r.right, r.bottom);
  }

  Offset? _slotCenter(int? i, int slot) {
    final o = _gameOrigin();
    if (o == null || i == null || i >= game.tubeComps.length || !game.hasLayout) {
      return null;
    }
    return game.slotRect(i, slot).shift(o).center;
  }

  Rect? _keyRect(GlobalKey k) {
    final root = _rootKey.currentContext?.findRenderObject() as RenderBox?;
    final b = k.currentContext?.findRenderObject() as RenderBox?;
    if (root == null || b == null || !b.hasSize) return null;
    // Taller at the top so the booster's badges are inside the spotlight.
    final r = b.localToGlobal(Offset.zero, ancestor: root) & b.size;
    return Rect.fromLTRB(r.left, r.top - 10, r.right, r.bottom);
  }

  int? _firstWhere(bool Function(int i) f) {
    for (var i = 0; i < game.board.tubes.length; i++) {
      if (f(i)) return i;
    }
    return null;
  }

  /// Guided-move source: the first tube that can be lifted (for the group
  /// lesson, the first whose top run is two or more beans).
  int? _source(Lesson l) => _firstWhere((i) =>
      l == Lesson.group ? game.board.groupSize(i) >= 2 : game.board.canPick(i));

  int? _emptyTube() => _firstWhere(
      (i) => game.board.tubes[i].stack.isEmpty && !game.board.isLocked(i));

  int? _pouchTube() =>
      _firstWhere((i) => game.board.tubes[i].stack.any((p) => p.hidden));

  int? _lockedTube() => _firstWhere((i) => game.board.isLocked(i));

  // Tubes are fixed for the whole guided lesson (chosen when it starts).
  int? _src, _dst;

  bool Function(int)? _allowFor(Lesson l, int step) {
    if (l != Lesson.tap && l != Lesson.group) return null;
    return step == 0 ? (i) => i == _src : (i) => i == _dst;
  }

  CoachStep? _stepFor(Lesson l, int step) {
    switch (l) {
      case Lesson.tap:
      case Lesson.group:
        if (step == 0) {
          _src = _source(l);
          _dst = _emptyTube();
          if (_src == null || _dst == null) return null;
        }
        final group = l == Lesson.group;
        if (step == 0) {
          return CoachStep(
            text: group ? 'Matching beans move together' : 'Tap a tube to lift its top bean',
            sub: group ? 'Tap to lift the group · 1 of 2' : '1 of 2',
            target: () => _tubeRect(_src),
            passThrough: _guidedArea,
            hand: () => _slotCenter(_src, game.board.tubes[_src!].stack.length - 1),
          );
        }
        return CoachStep(
          text: group ? 'Drop them in an empty tube' : 'Now tap an empty tube to drop it',
          sub: '2 of 2',
          target: () => _tubeRect(_dst),
          passThrough: _guidedArea,
          hand: () => _slotCenter(_dst, 1),
        );
      case Lesson.drag:
        final a = _source(l), b = _emptyTube();
        if (a == null || b == null) return null;
        final type = game.board.tubes[a].top!.type;
        return CoachStep(
          text: 'Tip: you can also drag beans',
          sub: 'Disappears after your first move',
          // No hole (passive): the bubble just sits above the two tubes.
          target: () {
            final p = _tubeRect(a), q = _tubeRect(b);
            return p == null || q == null ? null : p.expandToInclude(q);
          },
          passive: true,
          drag: () {
            final p = _slotCenter(a, game.board.tubes[a].stack.length - 1);
            final q = _tubeRect(b);
            if (p == null || q == null) return null;
            return (p, Offset(q.center.dx, q.top + q.height * .3), type);
          },
        );
      case Lesson.undo:
        return CoachStep(
          text: 'Oops? Undo takes a move back.',
          sub: '1 free each scoop · tap to continue',
          target: () => _keyRect(_undoKey),
          tapToClose: true,
          skippable: false,
        );
      case Lesson.pouch:
        final t = _pouchTube();
        if (t == null) return null;
        return CoachStep(
          text: 'A pouch opens when it reaches the top',
          sub: 'Tap to continue',
          target: () => _tubeRect(t),
          tapToClose: true,
          skippable: false,
        );
      case Lesson.peek:
        return CoachStep(
          text: 'Peek shows every pouch (ad)',
          sub: 'Tap to continue',
          target: () => _keyRect(_peekKey),
          tapToClose: true,
          skippable: false,
        );
      case Lesson.lock:
        final t = _lockedTube();
        if (t == null) return null;
        final need = game.board.tubes[t].unlockAt! - game.board.completeCount;
        return CoachStep(
          text: 'Locked! Finish $need tube${need == 1 ? '' : 's'} to open it',
          sub: 'Tap to continue',
          target: () => _tubeRect(t),
          tapToClose: true,
          above: false,
          skippable: false,
        );
      case Lesson.drop:
      case Lesson.extra:
        return null;
    }
  }

  /// Lesson progress driven by game events.
  void _coachEvent(GameEvent e) {
    final l = _lesson;
    if ((l == Lesson.tap || l == Lesson.group) && _coach != null) {
      if (e == GameEvent.pick && _stepIx == 0) {
        _setCoach(l, 1);
      } else if (e == GameEvent.drop && _stepIx == 1) {
        _finishLesson();
      }
    }
    if (l == Lesson.drag && e == GameEvent.drop) _finishLesson();
    if (e == GameEvent.drop && _undoLessonDue && _lesson == null) {
      _undoLessonDue = false;
      // Once the beans have landed, so Undo is live under the spotlight.
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted || showingResult || _lesson != null || !game.board.canUndo) {
          return;
        }
        _queue.insert(0, Lesson.undo);
        _nextLesson();
      });
    }
    if (e == GameEvent.reveal &&
        _lesson == null &&
        Tutorial.showPeekOnReveal(level, _lv.hasPouch, _seen) &&
        !peekUsed) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted || showingResult || _lesson != null || _seen.contains(Lesson.peek)) {
          return;
        }
        _queue.insert(0, Lesson.peek);
        _nextLesson();
      });
    }
  }

  // ------------------------------------------------------------------ game

  void _onEvent(GameEvent e) {
    if (widget.s.state.sound) Sfx.forEvent(e);
    switch (e) {
      case GameEvent.drop:
        setState(() => moves++);
      case GameEvent.undo:
        setState(() => moves = (moves - 1).clamp(0, 999));
      case GameEvent.won:
        _won();
      case GameEvent.stuck:
        _stuck();
      default:
        setState(() {});
    }
    _coachEvent(e);
  }

  /// Undo is possible right now: something to undo, no beans in the air
  /// (their move can't be taken back mid-flight) and the level not over.
  bool get _canUndoNow =>
      game.board.canUndo && !game.animating && !showingResult;

  static const _boosterName = {
    Booster.undo: 'Undo',
    Booster.peek: 'Peek',
    Booster.extra: 'Extra tube',
  };
  static const _boosterWhat = {
    Booster.undo: 'Takes your last move back.',
    Booster.peek: 'Opens every pouch on the board.',
    Booster.extra: 'Adds an empty tube for this scoop.',
  };

  /// Sweets price to show on a booster, or null when the player can't
  /// afford it (then it is ad only, as before).
  int? _priceIfAffordable(Booster b) =>
      Shop.canAfford(widget.s.state.coins, b) ? Prices.of(b) : null;

  /// How the player pays for [b]: a choice of sweets or ad when they have
  /// enough sweets, otherwise the ad. Null when cancelled or the ad was
  /// skipped. Nothing is charged here; see [Shop.redeem].
  Future<Pay?> _pay(Booster b) async {
    final st = widget.s.state;
    var pay = Pay.ad;
    if (Shop.canAfford(st.coins, b)) {
      final c = await choosePayment(context,
          title: _boosterName[b]!,
          what: _boosterWhat[b]!,
          price: Prices.of(b),
          balance: st.coins);
      if (c == null || !mounted) return null;
      pay = c;
    }
    if (pay == Pay.ad) {
      final placement = b == Booster.extra ? 'extra tube' : b.name;
      if (!await ads.showRewarded(context, placement)) return null;
      if (!mounted) return null;
    }
    return pay;
  }

  /// Spends the free undo first. After that an undo costs sweets or an ad
  /// (the ad grants 3). Nothing is charged unless the undo happens: not
  /// while beans are in the air, not after the win.
  Future<void> _undo() async {
    if (!_canUndoNow) return;
    var pay = Pay.ad;
    if (undosLeft == 0) {
      final p = await _pay(Booster.undo);
      if (p == null) return;
      pay = p;
      if (pay == Pay.ad) undosLeft = 3;
    }
    if (pay == Pay.sweets) {
      final ok = Shop.redeem(widget.s.state, Booster.undo, Pay.sweets,
          () => _canUndoNow && game.doUndo());
      setState(() {
        if (ok) undosUsed++;
      });
      return;
    }
    // The ad may have taken a while; only spend the undo if it happens.
    if (!_canUndoNow || !game.doUndo()) {
      setState(() {});
      return;
    }
    setState(() {
      undosLeft--;
      undosUsed++;
    });
  }

  bool get _hasPouchNow =>
      game.board.tubes.any((p) => p.stack.any((x) => x.hidden));

  Future<void> _peek() async {
    if (peekUsed || showingResult) return;
    final pay = await _pay(Booster.peek);
    if (pay == null || !mounted) return;
    final ok = Shop.redeem(widget.s.state, Booster.peek, pay, () {
      if (peekUsed || showingResult || !_hasPouchNow) return false;
      game.board.revealAll();
      return true;
    });
    if (ok) setState(() => peekUsed = true);
  }

  Future<void> _extra() async {
    if (extraUsed || showingResult) return;
    final pay = await _pay(Booster.extra);
    if (pay == null || !mounted) return;
    final ok = Shop.redeem(widget.s.state, Booster.extra, pay, () {
      if (extraUsed || showingResult) return false;
      game.addTube();
      return true;
    });
    if (ok) setState(() => extraUsed = true);
  }

  Future<void> _stuck() async {
    // One sheet at a time, and never once the level is won.
    if (_stuckOpen || showingResult || !mounted) return;
    _stuckOpen = true;
    final noMoves = !game.board.hasValidMove;
    final explainExtra = !extraUsed && Tutorial.showExtraInJam(_seen);
    if (explainExtra) widget.s.state.markSeen([Lesson.extra]);
    final free = undosLeft > 0;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: C.bg,
      barrierColor: C.sheetScrim,
      // Size to the content (the default caps the sheet at 9/16 of the
      // screen, which clips Restart on 640 dp phones).
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sticky jam!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                noMoves
                    ? 'No moves left. Take one back?'
                    : "This jar can't be finished from here. Take one back?",
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: C.text2, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              if ((!free && _priceIfAffordable(Booster.undo) != null) ||
                  (!extraUsed && _priceIfAffordable(Booster.extra) != null))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InfoChip(
                      leading: const SweetIcon(),
                      text: '${widget.s.state.coins} sweets'),
                ),
              BigButton(
                free ? 'Undo ($undosLeft free)' : 'Undo',
                reward: !free,
                price: free ? null : _priceIfAffordable(Booster.undo),
                onTap: game.board.canUndo ? () => Navigator.pop(c, 'undo') : null,
              ),
              if (!extraUsed) ...[
                const SizedBox(height: 12),
                BigButton(
                  'Extra tube',
                  reward: true,
                  price: _priceIfAffordable(Booster.extra),
                  onTap: () => Navigator.pop(c, 'extra'),
                ),
                if (explainExtra)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Extra tube gives you an empty tube for this scoop.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: C.text2, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(c, 'restart'),
                child: const Text('Restart'),
              ),
            ],
          ),
        ),
      ),
    );
    _stuckOpen = false;
    if (!mounted) return;
    switch (choice) {
      case 'undo':
        await _undo();
      case 'extra':
        await _extra();
      case 'restart':
        _start(restart: true);
      default:
        // Closed without a choice (e.g. Back): leave the board as it is;
        // Undo and Restart stay available in the HUD.
        return;
    }
    if (mounted && !game.animating && game.isDeadEnd) _stuck();
  }

  Future<void> _won() async {
    if (showingResult) return;
    // Freeze the level: nothing may change the board or the count now.
    setState(() {
      showingResult = true;
      _coach = null;
      _lesson = null;
    });
    game.allowTube = null;
    game.inputEnabled = false;
    final wonMoves = moves;
    final wonTubes = [for (final t in game.board.tubes) t.copy()];
    final lv = _lv;
    final stars = starsFor(wonMoves, lv.par);
    final beans = 10 + stars * 5;
    widget.s.state.completeLevel(level, stars, beans, widget.s.levels.length);
    game.confetti();
    HapticFeedback.heavyImpact();
    // Let the confetti play before the card covers it.
    await Future<void>.delayed(S.resultDelay);
    if (!mounted) return;
    await ads.maybeInterstitial(context, level, restarted: restarted);
    if (!mounted) return;
    final next = await Navigator.push<String>(
      context,
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, a, _) => SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
          child: SweetScreen(
            s: widget.s,
            level: level,
            stars: stars,
            moves: wonMoves,
            par: lv.par,
            beans: beans,
            tubes: wonTubes,
            ads: ads,
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (next == 'retry') {
      _start(restart: true);
    } else if (next == 'next' && level < widget.s.levels.length) {
      level++;
      _start();
    } else {
      Navigator.pop(context);
    }
  }

  void _skipLesson() {
    // Skipping a guided move leaves nothing half-done on the board.
    if (game.selected != null && !game.animating) {
      game.tubeComps[game.selected!].resetLift();
      game.selected = null;
    }
    game.slowNextReveal = false;
    _finishLesson();
  }

  @override
  Widget build(BuildContext context) {
    final lv = _lv;
    final hasPouchNow = _hasPouchNow;
    final showBasic = Boosters.basic(level);
    final showPeek = Boosters.peek(level, lv.hasPouch);
    final coach = _coach;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          key: _rootKey,
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, color: C.text),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              'Scoop $level',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            MoveGoal(moves: moves, par: lv.par),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Restart',
                        onPressed: showingResult
                            ? null
                            : () => _start(restart: true),
                        icon: const Icon(Icons.refresh_rounded, color: C.text),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      // The level's hint stays as the board's accessibility
                      // label; on screen, lessons are coach marks.
                      Semantics(
                        key: _gameKey,
                        label: lv.hint ?? 'Scoop $level board',
                        child: GameWidget(game: game),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 6,
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: _goalChip ? 1 : 0,
                            duration: const Duration(milliseconds: 400),
                            child: const Center(
                              child: InfoChip(
                                leading: Icon(Icons.flag_rounded,
                                    color: C.accentText, size: 18),
                                text: 'Goal: one flavour per tube',
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedOpacity(
                            opacity: refusalVisible ? 1 : 0,
                            duration: S.fade,
                            child: CustomSingleChildLayout(
                              delegate: _AboveTube(
                                refusalTube < game.tubeComps.length &&
                                        game.hasLayout
                                    ? game.tubeRect(refusalTube)
                                    : null,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: C.bubble,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  refusal,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Fixed height: the board (and bean size) is the same
                // whether the bar shows 0, 2 or 3 boosters.
                SizedBox(
                  height: S.boosterH + 2 * S.boosterBarPad,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (showBasic)
                        _Booster(
                          key: _undoKey,
                          icon: Icons.undo_rounded,
                          label: undosLeft > 0 ? 'Undo ($undosLeft)' : 'Undo',
                          ad: undosLeft == 0,
                          price: undosLeft == 0 ? _priceIfAffordable(Booster.undo) : null,
                          onTap: game.board.canUndo && !showingResult ? _undo : null,
                        ),
                      if (showPeek)
                        _Booster(
                          key: _peekKey,
                          icon: Icons.visibility_outlined,
                          label: 'Peek',
                          ad: true,
                          price: _priceIfAffordable(Booster.peek),
                          isNew: !_seen.contains(Lesson.peek),
                          onTap: peekUsed || !hasPouchNow || showingResult
                              ? null
                              : _peek,
                        ),
                      if (showBasic)
                        _Booster(
                          icon: Icons.add_box_outlined,
                          label: 'Extra tube',
                          ad: true,
                          price: _priceIfAffordable(Booster.extra),
                          onTap: extraUsed || showingResult ? null : _extra,
                        ),
                    ],
                  ),
                ),
                BannerSlot(hidden: widget.s.state.removeAds),
              ],
            ),
            if (coach != null && !showingResult)
              Positioned.fill(
                child: CoachOverlay(
                  step: coach,
                  nudge: _nudge,
                  onSkip: _skipLesson,
                  onClose: _finishLesson,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Places the refusal bubble just above a tube, kept on screen.
class _AboveTube extends SingleChildLayoutDelegate {
  final Rect? tube;
  _AboveTube(this.tube);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) =>
      BoxConstraints(maxWidth: c.maxWidth - 16);

  @override
  Offset getPositionForChild(Size size, Size child) {
    final t = tube;
    if (t == null) return Offset((size.width - child.width) / 2, 4);
    return bubbleOrigin(t, size, child);
  }

  @override
  bool shouldRelayout(_AboveTube o) => o.tube != tube;
}

/// Top-left of a bubble of size [child] centred above [tube] in an area of
/// [area], never closer than 8 dp to the sides or 2 dp to the top.
Offset bubbleOrigin(Rect tube, Size area, Size child) {
  final x = (tube.center.dx - child.width / 2)
      .clamp(8.0, max(8.0, area.width - 8 - child.width)).toDouble();
  final y = max(2.0, tube.top - child.height - 4);
  return Offset(x, y);
}

class _Booster extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ad;
  /// Sweets price shown next to the AD badge when affordable.
  final int? price;
  final bool isNew;
  final VoidCallback? onTap;
  const _Booster({
    super.key,
    required this.icon,
    required this.label,
    required this.ad,
    this.price,
    this.isNew = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .4 : 1,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: S.boosterW,
        height: S.boosterH,
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.border, width: 2),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: C.text, size: 30),
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Badges sit on the top edge, clear of the icon.
            if (ad) Positioned(right: -6, top: -10, child: PayBadge(price: price)),
            if (isNew)
              Positioned(
                left: -6,
                top: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                      color: C.newBadge, borderRadius: BorderRadius.circular(5)),
                  child: const Text('NEW',
                      style: TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class SweetScreen extends StatefulWidget {
  final Services s;
  final int level, stars, moves, par, beans;
  final List<Tube> tubes;
  final AdService ads;
  const SweetScreen({
    super.key,
    required this.s,
    required this.level,
    required this.stars,
    required this.moves,
    required this.par,
    required this.beans,
    required this.tubes,
    required this.ads,
  });
  @override
  State<SweetScreen> createState() => _SweetScreenState();
}

/// Sweets or ad? Shows the booster, what it does and the player's sweets.
Future<Pay?> choosePayment(BuildContext context,
        {required String title,
        required String what,
        required int price,
        required int balance}) =>
    showDialog<Pay>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title, textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(what, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          InfoChip(leading: const SweetIcon(), text: 'You have $balance sweets'),
          const SizedBox(height: 16),
          BigButton('Use $price sweets', onTap: () => Navigator.pop(c, Pay.sweets)),
          const SizedBox(height: 12),
          BigButton('Watch ad', reward: true, onTap: () => Navigator.pop(c, Pay.ad)),
          const SizedBox(height: 4),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        ]),
      ),
    );

/// Result line under the jar. No "par": at or under the goal it simply
/// shows the three stars; over it, how many moves ★★★ needs.
String resultLine(int moves, int par) => moves > par
    ? 'Done in $moves moves · ★★★ needs $par or fewer'
    : 'Done in $moves moves · ★★★';

class _SweetScreenState extends State<SweetScreen> {
  bool doubled = false;

  Future<void> _double() async {
    if (doubled) return;
    if (await widget.ads.showRewarded(context, '2x sweets')) {
      widget.s.state.addCoins(widget.beans);
      if (mounted) setState(() => doubled = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final finished = [
      for (final t in widget.tubes)
        if (t.sealed) t.stack.first.type,
    ];
    final over = widget.moves > widget.par;
    return Scaffold(
      backgroundColor: C.resultScrim,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  // Short screens: tighter card, and the jar shrinks to
                  // whatever room is left so every button stays visible.
                  final compact = box.maxHeight < 720;
                  final gap = compact ? 8.0 : 12.0;
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: box.maxHeight),
                      child: Container(
                        margin: EdgeInsets.all(compact ? 12 : 24),
                        padding: EdgeInsets.fromLTRB(
                          24,
                          compact ? 12 : 24,
                          24,
                          compact ? 16 : 24,
                        ),
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: C.border, width: 3),
                        ),
                        child: Stack(
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Sweet!',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    color: C.accent,
                                  ),
                                ),
                                Stars(widget.stars, size: compact ? 40 : 48),
                                const SizedBox(height: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Jar(tubes: finished, width: 170),
                                  ),
                                ),
                                SizedBox(height: gap),
                                Text(
                                  resultLine(widget.moves, widget.par),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: C.text2,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '+${widget.beans * (doubled ? 2 : 1)} sweets',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _DoubleChip(
                                      done: doubled,
                                      onTap: doubled ? null : _double,
                                    ),
                                  ],
                                ),
                                SizedBox(height: compact ? 10 : 16),
                                BigButton(
                                  'Next scoop',
                                  onTap: () => Navigator.pop(context, 'next'),
                                ),
                                if (over) ...[
                                  SizedBox(height: gap + 4),
                                  BigButton(
                                    'Retry for ★★★',
                                    primary: false,
                                    onTap: () => Navigator.pop(context, 'retry'),
                                  ),
                                ],
                              ],
                            ),
                            Positioned(
                              left: 0,
                              top: 0,
                              child: CandyIconButton(
                                Icons.home_rounded,
                                tooltip: 'Home',
                                onTap: () => Navigator.pop(context, 'home'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            BannerSlot(hidden: widget.s.state.removeAds),
          ],
        ),
      ),
    );
  }
}

/// "AD ×2" reward chip next to the beans; 48 dp tall touch target.
class _DoubleChip extends StatelessWidget {
  final bool done;
  final VoidCallback? onTap;
  const _DoubleChip({required this.done, this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: done ? 'Sweets doubled' : 'Watch an ad to double the sweets',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: S.minTouch,
            child: Center(
              child: Container(
                padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                decoration: BoxDecoration(
                  color: C.panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: done ? C.border : C.accent, width: 2),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (done)
                    const Icon(Icons.check_rounded, size: 16, color: C.text2)
                  else
                    const AdBadge(),
                  const SizedBox(width: 4),
                  Text('×2',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: done ? C.text2 : C.accentText)),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// Highest move count that still earns [stars] stars.
int movesForStars(int stars, int par) {
  var m = par;
  while (starsFor(m + 1, par) >= stars) {
    m++;
  }
  return m;
}

/// HUD line: live stars plus the move target for the best stars still on offer.
class MoveGoal extends StatelessWidget {
  final int moves, par;
  const MoveGoal({super.key, required this.moves, required this.par});

  @override
  Widget build(BuildContext context) {
    final stars = starsFor(moves, par);
    final goal = switch (stars) {
      3 => '★★★ within $par moves',
      2 => '★★ within ${movesForStars(2, par)} moves',
      _ => 'Finish for ★',
    };
    return Column(
      children: [
        Stars(stars, size: 22),
        // One line at any font size, so the board never resizes mid-move.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Moves $moves · $goal',
            maxLines: 1,
            style: TextStyle(
              color: stars == 3 ? C.text2 : C.accentText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
