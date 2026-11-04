import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/ad_service.dart';
import '../app/sfx.dart';
import '../app/theme.dart';
import '../game/jelly_game.dart';
import '../logic/board.dart';
import 'screens.dart';
import 'widgets.dart';

class GameScreen extends StatefulWidget {
  final Services s;
  final int level;
  const GameScreen(this.s, this.level, {super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
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
  }

  Board _board() => widget.s.levels[level - 1].toBoard();

  void _start({bool restart = false}) {
    setState(() {
      moves = 0;
      undosLeft = 1;
      undosUsed = 0;
      peekUsed = false;
      extraUsed = false;
      restarted = restart;
      showingResult = false;
    });
    game.inputEnabled = true;
    game.reset(_board());
  }

  /// Last refusal text; kept while the bubble fades out.
  String refusal = '';
  bool refusalVisible = false;
  int _refusalId = 0;

  void _onRefuse(String reason) {
    final id = ++_refusalId;
    setState(() {
      refusal = reason;
      refusalVisible = true;
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && id == _refusalId) setState(() => refusalVisible = false);
    });
  }

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
  }

  /// Undo is possible right now: something to undo, no beans in the air
  /// (their move can't be taken back mid-flight) and the level not over.
  bool get _canUndoNow =>
      game.board.canUndo && !game.animating && !showingResult;

  Future<void> _undo() async {
    if (!_canUndoNow) return;
    if (undosLeft == 0) {
      if (!await ads.showRewarded(context, 'undo')) return;
      if (!mounted) return;
      undosLeft = 3;
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

  Future<void> _peek() async {
    if (peekUsed || showingResult) return;
    if (!await ads.showRewarded(context, 'peek')) return;
    if (!mounted || showingResult) return;
    setState(() => peekUsed = true);
    game.board.revealAll();
  }

  Future<void> _extra() async {
    if (extraUsed || showingResult) return;
    if (!await ads.showRewarded(context, 'extra tube')) return;
    if (!mounted || showingResult) return;
    setState(() => extraUsed = true);
    game.addTube();
  }

  Future<void> _stuck() async {
    // One sheet at a time, and never once the level is won.
    if (_stuckOpen || showingResult || !mounted) return;
    _stuckOpen = true;
    final noMoves = !game.board.hasValidMove;
    final choice = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: C.bg,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sticky jam!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            Text(
              noMoves
                  ? 'No moves left.'
                  : "This jar can't be finished from here.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: C.text2),
            ),
            const SizedBox(height: 20),
            BigButton(
              'Undo',
              reward: true,
              onTap: () => Navigator.pop(c, 'undo'),
            ),
            const SizedBox(height: 12),
            if (!extraUsed)
              BigButton(
                'Extra tube',
                reward: true,
                onTap: () => Navigator.pop(c, 'extra'),
              ),
            if (!extraUsed) const SizedBox(height: 12),
            BigButton('Restart', onTap: () => Navigator.pop(c, 'restart')),
          ],
        ),
      ),
    );
    _stuckOpen = false;
    if (!mounted) return;
    switch (choice) {
      case 'undo':
        undosLeft = 0;
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
    setState(() => showingResult = true);
    game.inputEnabled = false;
    final wonMoves = moves;
    final wonTubes = [for (final t in game.board.tubes) t.copy()];
    final lv = widget.s.levels[level - 1];
    final stars = starsFor(wonMoves, lv.par);
    final beans = 10 + stars * 5;
    widget.s.state.completeLevel(level, stars, beans, widget.s.levels.length);
    game.confetti();
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 700));
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

  @override
  Widget build(BuildContext context) {
    final lv = widget.s.levels[level - 1];
    final hasPouch = game.board.tubes.any((p) => p.stack.any((x) => x.hidden));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
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
                  GameWidget(game: game),
                  // Overlaid so the board (and bean size) is the same with or
                  // without a hint; a two-row board needs the room, so it hides.
                  if (lv.hint != null && game.board.tubes.length <= maxPerRow)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 6,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: C.panel,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: C.border),
                            ),
                            child: Text(
                              lv.hint!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 4,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: refusalVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xE6453044),
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Booster(
                    icon: Icons.undo_rounded,
                    label: undosLeft > 0 ? 'Undo ($undosLeft)' : 'Undo',
                    ad: undosLeft == 0,
                    onTap: game.board.canUndo && !showingResult ? _undo : null,
                  ),
                  _Booster(
                    icon: Icons.visibility_rounded,
                    label: 'Peek',
                    ad: true,
                    onTap: peekUsed || !hasPouch || showingResult
                        ? null
                        : _peek,
                  ),
                  _Booster(
                    icon: Icons.add_box_rounded,
                    label: 'Extra tube',
                    ad: true,
                    onTap: extraUsed || showingResult ? null : _extra,
                  ),
                ],
              ),
            ),
            BannerSlot(hidden: widget.s.state.removeAds),
          ],
        ),
      ),
    );
  }
}

class _Booster extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ad;
  final VoidCallback? onTap;
  const _Booster({
    required this.icon,
    required this.label,
    required this.ad,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? .4 : 1,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: C.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: C.border, width: 2),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: C.text, size: 30),
                if (ad) const Positioned(right: -22, top: -4, child: AdBadge()),
              ],
            ),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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

class _SweetScreenState extends State<SweetScreen> {
  bool doubled = false;

  @override
  Widget build(BuildContext context) {
    final finished = [
      for (final t in widget.tubes)
        if (t.sealed) t.stack.first.type,
    ];
    return Scaffold(
      backgroundColor: const Color(0xCC4A2E2A),
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
                          compact ? 4 : 24,
                        ),
                        decoration: BoxDecoration(
                          color: C.bg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: C.border, width: 3),
                        ),
                        child: Column(
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
                              widget.moves > widget.par
                                  ? 'Done in ${widget.moves} moves · ★★★ needs ${widget.par} or fewer'
                                  : 'Done in ${widget.moves} moves · ★★★ — par!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: C.text2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '+${widget.beans * (doubled ? 2 : 1)} beans',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: compact ? 12 : 20),
                            BigButton(
                              'Next scoop',
                              onTap: () => Navigator.pop(context, 'next'),
                            ),
                            if (widget.moves > widget.par) ...[
                              SizedBox(height: gap),
                              BigButton(
                                'Retry for ★★★',
                                primary: false,
                                onTap: () => Navigator.pop(context, 'retry'),
                              ),
                            ],
                            SizedBox(height: gap),
                            BigButton(
                              '2× beans',
                              reward: true,
                              onTap: doubled
                                  ? null
                                  : () async {
                                      if (await widget.ads.showRewarded(
                                        context,
                                        '2x beans',
                                      )) {
                                        widget.s.state.addCoins(widget.beans);
                                        setState(() => doubled = true);
                                      }
                                    },
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, 'home'),
                              child: const Text(
                                'Home',
                                style: TextStyle(color: C.text2),
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
              color: stars == 3 ? C.text2 : C.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
