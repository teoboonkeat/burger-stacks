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
  bool showingResult = false;

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
    game.reset(_board());
  }

  String? refusal;
  int _refusalId = 0;

  void _onRefuse(String reason) {
    final id = ++_refusalId;
    setState(() => refusal = reason);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && id == _refusalId) setState(() => refusal = null);
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

  Future<void> _undo() async {
    if (!game.board.canUndo) return;
    if (undosLeft == 0) {
      if (!await ads.showRewarded(context, 'undo')) return;
      undosLeft = 3;
    }
    setState(() {
      undosLeft--;
      undosUsed++;
    });
    game.doUndo();
  }

  Future<void> _peek() async {
    if (peekUsed || !await ads.showRewarded(context, 'peek')) return;
    setState(() => peekUsed = true);
    game.board.revealAll();
  }

  Future<void> _extra() async {
    if (extraUsed || !await ads.showRewarded(context, 'extra tube')) return;
    setState(() => extraUsed = true);
    game.addTube();
  }

  Future<void> _stuck() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
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
            const Text('No moves left.', style: TextStyle(color: C.text2)),
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
    if (!mounted) return;
    switch (choice) {
      case 'undo':
        undosLeft = 0;
        await _undo();
      case 'extra':
        await _extra();
      default:
        _start(restart: true);
    }
    if (game.board.isStuck) _stuck();
  }

  Future<void> _won() async {
    if (showingResult) return;
    showingResult = true;
    final lv = widget.s.levels[level - 1];
    final stars = starsFor(moves, lv.par);
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
            moves: moves,
            par: lv.par,
            beans: beans,
            tubes: game.board.tubes,
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
                    onPressed: () => _start(restart: true),
                    icon: const Icon(Icons.refresh_rounded, color: C.text),
                  ),
                ],
              ),
            ),
            if (lv.hint != null)
              Padding(
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
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            Expanded(
              child: Stack(children: [
                GameWidget(game: game),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 4,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: refusal == null ? 0 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xE6453044),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            refusal ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
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
                    onTap: game.board.canUndo ? _undo : null,
                  ),
                  _Booster(
                    icon: Icons.visibility_rounded,
                    label: 'Peek',
                    ad: true,
                    onTap: peekUsed || !hasPouch ? null : _peek,
                  ),
                  _Booster(
                    icon: Icons.add_box_rounded,
                    label: 'Extra tube',
                    ad: true,
                    onTap: extraUsed ? null : _extra,
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
              child: Center(
                child: SingleChildScrollView(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(24),
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
                        Stars(widget.stars, size: 48),
                        const SizedBox(height: 8),
                        Jar(tubes: finished, width: 170),
                        const SizedBox(height: 12),
                        Text(
                          widget.moves > widget.par
                              ? 'Done in ${widget.moves} moves · ★★★ needs ${widget.par} or fewer'
                              : 'Done in ${widget.moves} moves · best possible!',
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
                        const SizedBox(height: 20),
                        BigButton(
                          'Next scoop',
                          onTap: () => Navigator.pop(context, 'next'),
                        ),
                        if (widget.moves > widget.par) ...[
                          const SizedBox(height: 12),
                          BigButton(
                            'Retry for ★★★',
                            primary: false,
                            onTap: () => Navigator.pop(context, 'retry'),
                          ),
                        ],
                        const SizedBox(height: 12),
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
