import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../jersey_widget.dart';
import '../models.dart';
import 'result_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _navigated = false;

  GameController get c => widget.controller;

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Future<bool> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit game?'),
        content: const Text('Your progress in this game will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep playing')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quit')),
        ],
      ),
    );
    return quit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmQuit() && context.mounted) Navigator.pop(context);
      },
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (c.finished && !_navigated) {
            _navigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => ResultScreen(controller: c)));
            });
          }
          return Scaffold(
            body: SafeArea(
              child: c.waitingForHandoff ? _handoff(context) : _question(context),
            ),
          );
        },
      ),
    );
  }

  Widget _handoff(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz, size: 64),
            const SizedBox(height: 12),
            Text("${c.currentName}'s turn",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_statusLine(), style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: c.startQuestion,
              style: FilledButton.styleFrom(minimumSize: const Size(220, 56)),
              child: const Text("I'm ready"),
            ),
          ],
        ),
      ),
    );
  }

  String _statusLine() {
    final i = c.turn;
    return c.isSurvival
        ? 'Lives: ${c.lives[i]}  •  Score: ${c.scores[i]}'
        : 'Question ${c.asked[i] + 1} of ${GameController.questionsPerPlayer}  •  Score: ${c.scores[i]}';
  }

  Widget _question(BuildContext context) {
    final q = c.question;
    final total = c.difficulty.seconds;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.currentName,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              if (c.isSurvival)
                Row(children: [
                  for (var i = 0; i < GameController.startingLives; i++)
                    Icon(i < c.lives[c.turn] ? Icons.favorite : Icons.favorite_border,
                        color: Colors.redAccent, size: 22),
                ])
              else
                Text('Q ${c.questionNumber}/${GameController.questionsPerPlayer}'),
              const SizedBox(width: 16),
              Text('${c.scores[c.turn]} pts',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          if (c.streak[c.turn] >= 2)
            Text('🔥 ${c.streak[c.turn]} streak',
                style: const TextStyle(color: Colors.orangeAccent)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: c.secondsLeft / total,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: c.secondsLeft <= 3 ? Colors.redAccent : null,
          ),
          const SizedBox(height: 2),
          Align(alignment: Alignment.centerRight, child: Text('${c.secondsLeft}s', style: const TextStyle(fontSize: 12, color: Colors.white54))),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (q.showsJersey)
                      JerseyWidget(team: q.team, number: q.player.number, size: 170)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(q.player.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                      ),
                    const SizedBox(height: 8),
                    Text(q.prompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          for (var i = 0; i < q.choices.length; i++) _choice(i),
          SizedBox(
            height: 52,
            child: c.revealed
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton(
                      onPressed: c.next,
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                      child: Text(c.gameOverAfterThis ? 'See results' : 'Next'),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _choice(int i) {
    final q = c.question;
    Color? bg;
    if (c.revealed) {
      if (i == q.correct) {
        bg = Colors.green.shade700;
      } else if (i == c.picked) {
        bg = Colors.red.shade700;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.tonal(
        onPressed: c.revealed ? null : () => c.answer(i),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: bg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: bg != null ? Colors.white : null,
        ),
        child: Text(q.choices[i], style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
