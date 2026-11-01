import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app_state.dart';
import 'app/sfx.dart';
import 'app/theme.dart';
import 'levels/level.dart';
import 'ui/screens.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState();
  await state.load();
  await Sfx.preload();
  final levels = parseLevels(
      jsonDecode(await rootBundle.loadString('assets/levels/levels.json')) as List);
  runApp(JellyApp(Services(state, levels)));
}

class JellyApp extends StatefulWidget {
  final Services s;
  const JellyApp(this.s, {super.key});
  @override
  State<JellyApp> createState() => _JellyAppState();
}

class _JellyAppState extends State<JellyApp> with WidgetsBindingObserver {
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
        title: 'Jelly Beans',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) =>
            ColoredBox(color: C.bg, child: Dotted(child: child!)),
        home: HomeScreen(widget.s),
      );
}
