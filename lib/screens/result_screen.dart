import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../models.dart';
import '../stats_service.dart';
import '../theme.dart';
import 'leaderboard_screen.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 4));

  GameController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    if (c.anyPerfect) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multi = c.playerCount > 1;
    final winners = c.winners;

    final headline = c.anyPerfect
        ? 'PERFECT ROUND!'
        : !multi
        ? (c.isSurvival
              ? 'GAME OVER'
              : (c.isDaily ? 'DAILY COMPLETE' : 'FINAL BUZZER'))
        : (winners.length > 1
              ? "IT'S A TIE!"
              : '${c.names[winners.first].toUpperCase()} WINS!');

    return Scaffold(
      body: CourtBackground(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 8),
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: Court.display(48, color: Court.orange),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < c.playerCount; i++)
                    _playerCard(i, multi, winners),
                  _accuracyByType(),
                  const SizedBox(height: 8),
                  _review(),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (r) => r.isFirst),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: const Text('PLAY AGAIN'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.emoji_events),
                    label: const Text('Leaderboards'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirection: math.pi / 2,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.06,
                numberOfParticles: 18,
                gravity: 0.2,
                shouldLoop: false,
                colors: const [
                  Court.orange,
                  Court.amber,
                  Court.line,
                  Colors.white,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerCard(int i, bool multi, List<int> winners) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (multi && winners.length == 1 && winners.contains(i))
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.emoji_events, color: Court.amber),
                  ),
                Expanded(
                  child: Text(
                    c.names[i].toUpperCase(),
                    style: Court.display(28),
                  ),
                ),
                ScoreBoard(label: 'Score', value: '${c.scores[i]}'),
              ],
            ),
            const SizedBox(height: 8),
            Text('Correct: ${c.correctCount[i]} of ${c.asked[i]}'),
            Text('Best streak: ${c.bestStreak[i]}'),
            if (c.history.any((r) => r.playerIndex == i && r.usedLifeline))
              Text(
                '50/50s used: '
                '${c.history.where((r) => r.playerIndex == i && r.usedLifeline).length}',
              ),
            if (!c.isSurvival)
              Text(
                'Total answer time: ${(c.timeMs[i] / 1000).toStringAsFixed(1)}s',
              ),
            if (c.mode == GameMode.round && c.isPerfect(i))
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '⭐ Perfect round, added to the Fastest Perfect board',
                  style: TextStyle(color: Court.amber),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _accuracyByType() {
    final correct = <QType, int>{}, total = <QType, int>{};
    for (final r in c.history) {
      final t = r.question.type;
      total[t] = (total[t] ?? 0) + 1;
      if (r.correct) correct[t] = (correct[t] ?? 0) + 1;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ACCURACY BY QUESTION TYPE', style: Court.display(20)),
            const SizedBox(height: 8),
            for (final t in QType.values)
              if ((total[t] ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(
                          t.label,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (correct[t] ?? 0) / total[t]!,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                          backgroundColor: Colors.black38,
                          color: Court.good,
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${correct[t] ?? 0}/${total[t]}',
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _review() {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text('REVIEW ANSWERS', style: Court.display(20)),
          children: [
            for (var n = 0; n < c.history.length; n++)
              _reviewRow(n, c.history[n]),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(int n, AnswerRecord r) {
    final q = r.question;
    final subject = q.showsJersey
        ? '#${q.player.number} ${q.team.abbr} jersey'
        : q.player.name;
    final yours = r.picked == null ? 'Time ran out' : q.choices[r.picked!];
    return ListTile(
      dense: true,
      leading: Icon(
        r.correct ? Icons.check_circle : Icons.cancel,
        color: r.correct ? Court.good : Court.bad,
      ),
      title: Text('${n + 1}. ${q.prompt}'),
      subtitle: Text(
        '$subject\n'
        '${c.playerCount > 1 ? '${c.names[r.playerIndex]}: ' : ''}$yours'
        '${r.correct ? '' : '  →  ${q.choices[q.correct]}'}'
        '${r.usedLifeline ? '  (50/50)' : ''}',
      ),
      isThreeLine: true,
    );
  }
}
