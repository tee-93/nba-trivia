import 'dart:async';

import 'package:flutter/foundation.dart';

import 'leaderboard.dart';
import 'models.dart';
import 'question_factory.dart';
import 'settings.dart';
import 'stats_service.dart';

class GameController extends ChangeNotifier {
  GameController({
    required GameData data,
    required this.mode,
    required this.difficulty,
    required this.names,
  }) : _factory = QuestionFactory(
         data,
         difficulty,
         seed: mode == GameMode.daily ? DailyService.seedFor() : null,
       ),
       scores = List.filled(names.length, 0),
       correctCount = List.filled(names.length, 0),
       streak = List.filled(names.length, 0),
       bestStreak = List.filled(names.length, 0),
       lives = List.filled(names.length, startingLives),
       asked = List.filled(names.length, 0),
       timeMs = List.filled(names.length, 0) {
    _beginTurn();
  }

  static const questionsPerPlayer = 10;
  static const startingLives = 3;

  final GameMode mode;
  final Difficulty difficulty;
  final List<String> names;
  final QuestionFactory _factory;

  final List<int> scores;
  final List<int> correctCount;
  final List<int> streak;
  final List<int> bestStreak;
  final List<int> lives;
  final List<int> asked;
  final List<int> timeMs;
  final List<AnswerRecord> history = [];

  int turn = 0;
  late Question question;
  int? picked;
  bool revealed = false;
  bool waitingForHandoff = false;
  bool paused = false;
  bool finished = false;
  int secondsLeft = 0;
  int lastPoints = 0;

  Timer? _timer;
  final Stopwatch _sw = Stopwatch();

  int get playerCount => names.length;
  String get currentName => names[turn];
  bool get isSurvival => mode == GameMode.survival;
  bool get isDaily => mode == GameMode.daily;

  /// Question number for the current player (1-based).
  int get questionNumber => asked[turn] + (revealed ? 0 : 1);

  void _beginTurn() {
    question = _factory.next();
    picked = null;
    revealed = false;
    secondsLeft = difficulty.seconds;
    waitingForHandoff = playerCount > 1;
    _sw
      ..stop()
      ..reset();
    if (!waitingForHandoff) _startTimer();
    notifyListeners();
  }

  /// Called when the next player taps "I'm ready" in pass-and-play.
  void startQuestion() {
    if (!waitingForHandoff) return;
    waitingForHandoff = false;
    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _sw.start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      secondsLeft--;
      if (secondsLeft <= 0) {
        secondsLeft = 0;
        _resolve(null);
      } else {
        if (secondsLeft <= 3) Fx.play(Sfx.tick);
        notifyListeners();
      }
    });
  }

  void pause() {
    if (paused || revealed || waitingForHandoff || finished) return;
    paused = true;
    _timer?.cancel();
    _sw.stop();
    notifyListeners();
  }

  void resume() {
    if (!paused) return;
    paused = false;
    _startTimer();
    notifyListeners();
  }

  void answer(int index) {
    if (revealed || waitingForHandoff || paused) return;
    _resolve(index);
  }

  void _resolve(int? index) {
    if (revealed) return;
    _timer?.cancel();
    _sw.stop();
    revealed = true;
    picked = index;
    asked[turn]++;
    final ok = index == question.correct;
    final ms = index == null
        ? difficulty.seconds * 1000
        : _sw.elapsedMilliseconds.clamp(0, difficulty.seconds * 1000);
    timeMs[turn] += ms;
    history.add(
      AnswerRecord(
        playerIndex: turn,
        question: question,
        picked: index,
        ms: ms,
      ),
    );

    if (ok) {
      correctCount[turn]++;
      streak[turn]++;
      if (streak[turn] > bestStreak[turn]) bestStreak[turn] = streak[turn];
      lastPoints = 100 + secondsLeft * 5 + (streak[turn] - 1).clamp(0, 10) * 10;
      scores[turn] += lastPoints;
      Fx.play(Sfx.correct);
      Fx.good();
    } else {
      lastPoints = 0;
      streak[turn] = 0;
      if (isSurvival) lives[turn]--;
      Fx.play(index == null ? Sfx.buzzer : Sfx.wrong);
      Fx.bad();
    }
    notifyListeners();
  }

  bool _canPlay(int p) =>
      isSurvival ? lives[p] > 0 : asked[p] < questionsPerPlayer;

  /// True if nobody has questions/lives left after the current answer.
  bool get gameOverAfterThis {
    for (var i = 0; i < playerCount; i++) {
      if (_canPlay(i)) return false;
    }
    return true;
  }

  void next() {
    if (!revealed || finished) return;
    for (var i = 1; i <= playerCount; i++) {
      final cand = (turn + i) % playerCount;
      if (_canPlay(cand)) {
        turn = cand;
        _beginTurn();
        return;
      }
    }
    _finish();
  }

  bool isPerfect(int p) => !isSurvival && correctCount[p] == questionsPerPlayer;
  bool get anyPerfect => List.generate(playerCount, isPerfect).any((x) => x);

  Future<void> _finish() async {
    finished = true;
    _timer?.cancel();
    Fx.play(anyPerfect ? Sfx.perfect : Sfx.gameover);
    notifyListeners();
    final lb = LeaderboardService();
    for (var p = 0; p < playerCount; p++) {
      if (!isDaily && bestStreak[p] > 0) {
        await lb.record(Board.streak, names[p], difficulty, bestStreak[p]);
      }
      if (isSurvival && scores[p] > 0) {
        await lb.record(Board.survival, names[p], difficulty, scores[p]);
      }
      if (mode == GameMode.round && isPerfect(p)) {
        await lb.record(Board.fastest, names[p], difficulty, timeMs[p]);
      }
    }
    if (isDaily) {
      await DailyService().recordIfFirst(
        score: scores[0],
        correct: correctCount[0],
      );
    }
    await StatsService().recordGame(
      history,
      perfectRounds: List.generate(
        playerCount,
        (p) => isPerfect(p) ? 1 : 0,
      ).fold(0, (a, b) => a + b),
    );
  }

  /// Indices of the winning player(s) by score.
  List<int> get winners {
    final best = scores.reduce((a, b) => a > b ? a : b);
    return [
      for (var i = 0; i < playerCount; i++)
        if (scores[i] == best) i,
    ];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
