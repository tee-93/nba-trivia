import 'package:flutter/material.dart';

import '../game_controller.dart';
import 'leaderboard_screen.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.controller});
  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final multi = c.playerCount > 1;
    final winners = c.winners;
    final theme = Theme.of(context);

    final headline = !multi
        ? (c.isSurvival ? 'Game over' : 'Round complete')
        : (winners.length > 1 ? "It's a tie!" : '${c.names[winners.first]} wins!');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            Text(headline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900, color: theme.colorScheme.primary)),
            const SizedBox(height: 20),
            for (var i = 0; i < c.playerCount; i++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        if (multi && winners.contains(i) && winners.length == 1)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.emoji_events, color: Colors.amber),
                          ),
                        Expanded(
                          child: Text(c.names[i],
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                        ),
                        Text('${c.scores[i]} pts',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                      ]),
                      const SizedBox(height: 8),
                      Text('Correct: ${c.correctCount[i]} of ${c.asked[i]}'),
                      Text('Best streak: ${c.bestStreak[i]}'),
                      if (!c.isSurvival)
                        Text('Total answer time: ${(c.timeMs[i] / 1000).toStringAsFixed(1)}s'),
                      if (!c.isSurvival && c.correctCount[i] == GameController.questionsPerPlayer)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('⭐ Perfect round — added to Fastest Perfect board',
                              style: TextStyle(color: Colors.amber)),
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Play again'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
              icon: const Icon(Icons.emoji_events),
              label: const Text('Leaderboards'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            ),
          ],
        ),
      ),
    );
  }
}
