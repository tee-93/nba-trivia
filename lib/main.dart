import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() => runApp(const NbaTriviaApp());

class NbaTriviaApp extends StatelessWidget {
  const NbaTriviaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NBA Jersey Trivia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7A1A),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF12141A),
      ),
      home: const HomeScreen(),
    );
  }
}
