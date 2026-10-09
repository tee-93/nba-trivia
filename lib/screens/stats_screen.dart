import 'package:flutter/material.dart';

import '../models.dart';
import '../stats_service.dart';
import '../theme.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YOUR STATS')),
      body: CourtBackground(
        child: SafeArea(
          child: FutureBuilder<LifetimeStats>(
            future: StatsService().load(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final s = snap.data!;
              if (s.games == 0) {
                return const Center(
                  child: Text('Play a game to start tracking stats.'),
                );
              }
              final pct = s.totalAnswered == 0
                  ? 0
                  : (100 * s.totalCorrect / s.totalAnswered).round();
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ScoreBoard(label: 'Games', value: '${s.games}'),
                      ScoreBoard(label: 'Accuracy', value: '$pct%'),
                      ScoreBoard(label: 'Perfect', value: '${s.perfectRounds}'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ACCURACY BY QUESTION TYPE',
                            style: Court.display(20),
                          ),
                          const SizedBox(height: 10),
                          for (final t in QType.values) _row(t, s.perType[t]!),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _row(QType t, List<int> v) {
    final frac = v[1] == 0 ? 0.0 : v[0] / v[1];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(t.label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: frac,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.black38,
              color: Court.good,
            ),
          ),
          SizedBox(
            width: 78,
            child: Text(
              '${v[0]}/${v[1]}  ${(frac * 100).round()}%',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
