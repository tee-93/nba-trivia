import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_controller.dart';
import '../jersey_widget.dart';
import '../models.dart';
import '../settings.dart';
import '../theme.dart';
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

  Future<void> _confirmQuit() async {
    final wasPaused = c.paused;
    c.pause();
    final quit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quit game?'),
        content: const Text('Your progress in this game will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (quit == true && mounted) {
      Navigator.pop(context);
    } else if (!wasPaused) {
      c.resume();
    }
  }

  void _onBack() {
    if (c.paused) {
      c.resume();
    } else if (!c.waitingForHandoff && !c.revealed) {
      c.pause();
    } else {
      _confirmQuit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (c.finished && !_navigated) {
            _navigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => ResultScreen(controller: c)),
              );
            });
          }
          return Scaffold(
            body: CourtBackground(
              child: SafeArea(
                child: Stack(
                  children: [
                    c.waitingForHandoff
                        ? _handoff(context)
                        : _question(context),
                    if (c.paused) _pauseOverlay(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _handoff(BuildContext context) {
    final i = c.turn;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz, size: 64, color: Court.orange),
            const SizedBox(height: 12),
            Text(
              "${c.currentName}'s turn".toUpperCase(),
              style: Court.display(44),
            ),
            const SizedBox(height: 8),
            Text(
              c.isSurvival
                  ? 'Lives: ${c.lives[i]}  •  Score: ${c.scores[i]}'
                  : 'Question ${c.asked[i] + 1} of ${GameController.questionsPerPlayer}  •  Score: ${c.scores[i]}',
              style: TextStyle(color: Court.line.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () {
                Fx.tap();
                c.startQuestion();
              },
              style: FilledButton.styleFrom(minimumSize: const Size(240, 58)),
              child: const Text("I'M READY"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pauseOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Court.woodDark.withValues(alpha: 0.96),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ListenableBuilder(
            listenable: Settings.instance,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PAUSED', style: Court.display(56)),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: c.resume,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(240, 54),
                  ),
                  child: const Text('RESUME'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: 260,
                  child: SwitchListTile(
                    title: const Text('Sound'),
                    value: Settings.instance.sound,
                    onChanged: Settings.instance.setSound,
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: SwitchListTile(
                    title: const Text('Vibration'),
                    value: Settings.instance.haptics,
                    onChanged: Settings.instance.setHaptics,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _confirmQuit,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(240, 48),
                  ),
                  child: const Text('Quit game'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _question(BuildContext context) {
    final q = c.question;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Column(
        children: [
          _topBar(),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: c.secondsLeft / c.difficulty.seconds,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: Colors.black38,
            color: c.secondsLeft <= 3 ? Court.bad : Court.orange,
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutBack,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0.25, 0),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _card(q),
                ),
              ),
            ),
          ),
          for (var i = 0; i < q.choices.length; i++) _choice(i),
          SizedBox(
            height: 54,
            child: c.revealed
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton(
                      onPressed: () {
                        Fx.tap();
                        c.next();
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: Text(c.gameOverAfterThis ? 'SEE RESULTS' : 'NEXT'),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    final i = c.turn;
    return Row(
      children: [
        IconButton(
          onPressed: c.revealed ? null : c.pause,
          icon: const Icon(Icons.pause_circle_outline),
          tooltip: 'Pause',
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.currentName.toUpperCase(),
                style: Court.display(22),
                overflow: TextOverflow.ellipsis,
              ),
              if (c.isSurvival)
                Row(
                  children: [
                    for (var l = 0; l < GameController.startingLives; l++)
                      Icon(
                        l < c.lives[i] ? Icons.favorite : Icons.favorite_border,
                        color: Court.bad,
                        size: 18,
                      ),
                  ],
                )
              else
                Text(
                  'Question ${c.questionNumber}/${GameController.questionsPerPlayer}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Court.line.withValues(alpha: 0.7),
                  ),
                ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: c.streak[i] >= 2
                    ? Text(
                        '🔥 ${c.streak[i]} streak',
                        key: ValueKey(c.streak[i]),
                        style: const TextStyle(
                          color: Court.amber,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      )
                    : const SizedBox(key: ValueKey(0), height: 15),
              ),
            ],
          ),
        ),
        ScoreBoard(label: 'Score', value: '${c.scores[i]}', width: 84),
        const SizedBox(width: 8),
        ScoreBoard(
          label: 'Time',
          value: '${c.secondsLeft}',
          alert: c.secondsLeft <= 3,
          width: 64,
        ),
      ],
    );
  }

  Widget _card(Question q) {
    return Column(
      key: ValueKey(q),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (q.showsJersey) ...[
          JerseyWidget(team: q.team, number: q.player.number, size: 160),
          if (q.type == QType.jerseyToPlayer && c.difficulty == Difficulty.easy)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                q.team.name.toUpperCase(),
                style: Court.display(22, color: Court.amber),
              ),
            ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              q.player.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: Court.display(46),
            ),
          ),
        const SizedBox(height: 8),
        Text(
          q.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _choice(int i) {
    final q = c.question;
    final isCorrect = c.revealed && i == q.correct;
    final isWrongPick = c.revealed && i == c.picked && i != q.correct;
    final bg = isCorrect
        ? Court.good
        : isWrongPick
        ? Court.bad
        : Colors.black.withValues(alpha: 0.4);

    Widget button = Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: c.revealed || c.paused
            ? null
            : () {
                Fx.tap();
                c.answer(i);
              },
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Court.line.withValues(
                alpha: isCorrect || isWrongPick ? 0.0 : 0.22,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  String.fromCharCode(65 + i),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  q.choices[i],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCorrect) const Icon(Icons.check_circle, size: 22),
              if (isWrongPick) const Icon(Icons.cancel, size: 22),
            ],
          ),
        ),
      ),
    );

    // Wrong pick shakes, correct answer pops.
    if (isWrongPick) {
      button = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        builder: (_, t, child) => Transform.translate(
          offset: Offset(math.sin(t * math.pi * 8) * 10 * (1 - t), 0),
          child: child,
        ),
        child: button,
      );
    } else if (isCorrect) {
      button = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        builder: (_, t, child) => Transform.scale(
          scale: 1 + 0.05 * math.sin(t * math.pi),
          child: child,
        ),
        child: button,
      );
    }
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: button);
  }
}
