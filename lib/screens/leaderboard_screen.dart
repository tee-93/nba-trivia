import 'package:flutter/material.dart';

import '../leaderboard.dart';
import '../models.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _service = LeaderboardService();
  Difficulty _difficulty = Difficulty.easy;

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all scores?'),
        content: const Text('This removes every leaderboard entry on this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      await _service.clear();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: Board.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboards'),
          actions: [
            IconButton(
              tooltip: 'Clear scores',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmClear,
            ),
          ],
          bottom: TabBar(tabs: [for (final b in Board.values) Tab(text: b.title)]),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<Difficulty>(
                segments: [
                  for (final d in Difficulty.values)
                    ButtonSegment(value: d, label: Text(d.label)),
                ],
                selected: {_difficulty},
                onSelectionChanged: (s) => setState(() => _difficulty = s.first),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final b in Board.values) _BoardList(board: b, difficulty: _difficulty, service: _service),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoardList extends StatelessWidget {
  const _BoardList({required this.board, required this.difficulty, required this.service});
  final Board board;
  final Difficulty difficulty;
  final LeaderboardService service;

  String get _hint => switch (board) {
        Board.fastest => 'Finish a 10-question round with every answer right.',
        Board.streak => 'Most correct answers in a row in a single game.',
        Board.survival => 'Highest score in Survival mode (3 lives).',
      };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LbEntry>>(
      future: service.top(board, difficulty),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No ${difficulty.label} scores yet.\n$_hint',
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
            ),
          );
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = list[i];
            final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';
            final d = DateTime.fromMillisecondsSinceEpoch(e.ts);
            return ListTile(
              leading: SizedBox(width: 32, child: Center(child: Text(medal, style: const TextStyle(fontSize: 20)))),
              title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${d.day}/${d.month}/${d.year}'),
              trailing: Text(board.format(e.value),
                  style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
            );
          },
        );
      },
    );
  }
}
