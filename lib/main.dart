import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'settings.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.instance.load();
  runApp(const NbaTriviaApp());
}

class NbaTriviaApp extends StatelessWidget {
  const NbaTriviaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NBA Jersey Trivia',
      debugShowCheckedModeBanner: false,
      theme: Court.theme(),
      home: const HomeScreen(),
    );
  }
}
