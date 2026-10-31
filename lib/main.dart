import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_state.dart';
import 'app/theme.dart';
import 'levels/level.dart';
import 'ui/screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState();
  await state.load();
  final levels = parseLevels(
      jsonDecode(await rootBundle.loadString('assets/levels/levels.json')) as List);
  runApp(BurgerApp(Services(state, levels)));
}

class BurgerApp extends StatefulWidget {
  final Services s;
  const BurgerApp(this.s, {super.key});
  @override
  State<BurgerApp> createState() => _BurgerAppState();
}

class _BurgerAppState extends State<BurgerApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) widget.s.state.save();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Burger Stacks',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: HomeScreen(widget.s),
      );
}
