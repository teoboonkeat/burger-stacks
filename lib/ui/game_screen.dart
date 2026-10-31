import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ads/ad_service.dart';
import '../app/theme.dart';
import '../game/burger_game.dart';
import '../game/ingredient_painter.dart';
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
  late BurgerGame game;
  late AdService ads = AdService(widget.s.state);
  int moves = 0;
  int undosLeft = 1;
  int undosUsed = 0;
  bool peekUsed = false, extraUsed = false, restarted = false;
  bool showingResult = false;

  @override
  void initState() {
    super.initState();
    game = BurgerGame(_board(),
        onEvent: _onEvent, haptics: widget.s.state.haptics);
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

  void _onEvent(GameEvent e) {
    if (widget.s.state.sound) {
      switch (e) {
        case GameEvent.pick || GameEvent.drop:
          SystemSound.play(SystemSoundType.click);
        default:
      }
    }
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
    if (extraUsed || !await ads.showRewarded(context, 'extra plate')) return;
    setState(() => extraUsed = true);
    game.addPlate();
  }

  Future<void> _stuck() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      backgroundColor: C.bg,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Kitchen jam!',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const Text('No moves left.', style: TextStyle(color: C.text2)),
          const SizedBox(height: 20),
          BigButton('Undo', reward: true, onTap: () => Navigator.pop(c, 'undo')),
          const SizedBox(height: 12),
          if (!extraUsed)
            BigButton('Extra plate', reward: true, onTap: () => Navigator.pop(c, 'extra')),
          if (!extraUsed) const SizedBox(height: 12),
          BigButton('Restart', onTap: () => Navigator.pop(c, 'restart')),
        ]),
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
    final tips = 10 + stars * 5;
    widget.s.state.completeLevel(level, stars, tips, widget.s.levels.length);
    game.confetti();
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    await ads.maybeInterstitial(context, level, restarted: restarted);
    if (!mounted) return;
    final next = await Navigator.push<bool>(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, a, _) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
            child: OrderUpScreen(
                s: widget.s,
                level: level,
                stars: stars,
                moves: moves,
                par: lv.par,
                tips: tips,
                plates: game.board.plates,
                ads: ads),
          ),
        ));
    if (!mounted) return;
    if (next == true && level < widget.s.levels.length) {
      level++;
      _start();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lv = widget.s.levels[level - 1];
    final hasCloche = game.board.plates.any((p) => p.stack.any((x) => x.hidden));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(children: [
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded, color: C.text)),
              Expanded(
                child: Column(children: [
                  Text('Order $level',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  Text('Moves $moves · Par ${lv.par}',
                      style: const TextStyle(color: C.text2, fontWeight: FontWeight.w700)),
                ]),
              ),
              IconButton(
                  onPressed: () => _start(restart: true),
                  icon: const Icon(Icons.refresh_rounded, color: C.text)),
            ]),
          ),
          if (lv.hint != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: C.panel,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: C.border)),
                child: Text(lv.hint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          Expanded(child: GameWidget(game: game)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _Booster(
                  icon: Icons.undo_rounded,
                  label: undosLeft > 0 ? 'Undo ($undosLeft)' : 'Undo',
                  ad: undosLeft == 0,
                  onTap: game.board.canUndo ? _undo : null),
              _Booster(
                  icon: Icons.visibility_rounded,
                  label: 'Peek',
                  ad: true,
                  onTap: peekUsed || !hasCloche ? null : _peek),
              _Booster(
                  icon: Icons.add_box_rounded,
                  label: 'Extra plate',
                  ad: true,
                  onTap: extraUsed ? null : _extra),
            ]),
          ),
          BannerSlot(hidden: widget.s.state.removeAds),
        ]),
      ),
    );
  }
}

class _Booster extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ad;
  final VoidCallback? onTap;
  const _Booster({required this.icon, required this.label, required this.ad, this.onTap});

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
                border: Border.all(color: C.border, width: 2)),
            child: Column(children: [
              Stack(clipBehavior: Clip.none, children: [
                Icon(icon, color: C.text, size: 30),
                if (ad) const Positioned(right: -22, top: -4, child: AdBadge()),
              ]),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
          ),
        ),
      );
}

class OrderUpScreen extends StatefulWidget {
  final Services s;
  final int level, stars, moves, par, tips;
  final List<Plate> plates;
  final AdService ads;
  const OrderUpScreen(
      {super.key,
      required this.s,
      required this.level,
      required this.stars,
      required this.moves,
      required this.par,
      required this.tips,
      required this.plates,
      required this.ads});
  @override
  State<OrderUpScreen> createState() => _OrderUpScreenState();
}

class _OrderUpScreenState extends State<OrderUpScreen> {
  bool doubled = false;

  @override
  Widget build(BuildContext context) {
    final burgers = widget.plates.where((p) => p.sealed).toList();
    return Scaffold(
      backgroundColor: const Color(0xCC3B2A1E),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: C.bg,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: C.border, width: 3)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Order up!',
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
                  Stars(widget.stars, size: 48),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final p in burgers)
                      CustomPaint(
                          size: const Size(48, 56),
                          painter: _BurgerIcon(p.stack.first.type)),
                  ]),
                  const SizedBox(height: 12),
                  Text('Order #${widget.level} · ${widget.moves} moves (par ${widget.par})',
                      style: const TextStyle(color: C.text2, fontWeight: FontWeight.w700)),
                  Text('🪙 +${widget.tips * (doubled ? 2 : 1)} tips',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 20),
                  BigButton('Next order', onTap: () => Navigator.pop(context, true)),
                  const SizedBox(height: 12),
                  BigButton('2× tips',
                      reward: true,
                      onTap: doubled
                          ? null
                          : () async {
                              if (await widget.ads.showRewarded(context, '2x tips')) {
                                widget.s.state.addCoins(widget.tips);
                                setState(() => doubled = true);
                              }
                            }),
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Home', style: TextStyle(color: C.text2))),
                ]),
              ),
            ),
          ),
          BannerSlot(hidden: widget.s.state.removeAds),
        ]),
      ),
    );
  }
}

class _BurgerIcon extends CustomPainter {
  final Ingredient type;
  _BurgerIcon(this.type);
  @override
  void paint(Canvas c, Size s) {
    paintBun(c, Rect.fromLTWH(0, 0, s.width, s.height * .4));
    paintIngredient(c, Rect.fromLTWH(2, s.height * .4, s.width - 4, s.height * .3), type);
    c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, s.height * .72, s.width, s.height * .25),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFFE8A04A));
  }

  @override
  bool shouldRepaint(_BurgerIcon o) => o.type != type;
}
