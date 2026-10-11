import 'dart:async';

import 'package:flutter/foundation.dart';

import 'leaderboard.dart';
import 'lifeline_service.dart';
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
    int startingCredits = 0,
    int startingProgress = 0,
  }) : _factory = QuestionFactory(
         data,
         difficulty,
         seed: mode == GameMode.daily ? DailyService.seedFor() : null,
       ),
       // Saved credits belong to the phone's single player; in two-player
       // games each player earns credits for that game only.
       freeLeft = List.filled(
         names.length,
         mode == GameMode.daily ? 0 : LifelineService.freePerGame,
       ),
       credits = [
         for (var i = 0; i < names.length; i++)
           (i == 0 && names.length == 1 && mode != GameMode.daily)
               ? startingCredits
               : 0,
       ],
       creditProgress = [
         for (var i = 0; i < names.length; i++)
           (i == 0 && names.length == 1 && mode != GameMode.daily)
               ? startingProgress
               : 0,
       ],
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

  // 50/50 lifelines, per player.
  final List<int> freeLeft;
  final List<int> credits;
  final List<int> creditProgress;

  /// Answer indexes removed by a 50/50 on the current question.
  final Set<int> eliminated = {};
  bool usedLifeline = false;

  /// True when the last answer earned a 50/50 credit.
  bool creditEarned = false;

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

  /// The Daily Challenge stays a pure test, so there are no lifelines there.
  bool get lifelinesEnabled => !isDaily;

  /// Whether the current player can use a 50/50 right now.
  bool get canUseLifeline =>
      lifelinesEnabled &&
      !revealed &&
      !waitingForHandoff &&
      !paused &&
      !finished &&
      !usedLifeline &&
      (freeLeft[turn] > 0 || credits[turn] > 0);

  /// Whether lifeline credits earned here are saved on the phone.
  bool get _savesCredits => playerCount == 1 && lifelinesEnabled;

  /// Removes wrong answers, leaving the right one and one wrong one.
  void useLifeline() {
    if (!canUseLifeline) return;
    if (freeLeft[turn] > 0) {
      freeLeft[turn]--;
    } else {
      credits[turn]--;
    }
    usedLifeline = true;
    final wrong = [
      for (var i = 0; i < question.choices.length; i++)
        if (i != question.correct) i,
    ]..shuffle();
    // 4 answers: remove 2 wrong ones. 3 answers (Very Easy): remove 1.
    eliminated.addAll(wrong.take(question.choices.length - 2));
    Fx.play(Sfx.lifeline);
    Fx.tap();
    _saveCredits();
    notifyListeners();
  }

  void _saveCredits() {
    if (_savesCredits) {
      LifelineService().save(credits[0], creditProgress[0]);
    }
  }

  /// Question number for the current player (1-based).
  int get questionNumber => asked[turn] + (revealed ? 0 : 1);

  void _beginTurn() {
    question = _factory.next();
    picked = null;
    revealed = false;
    eliminated.clear();
    usedLifeline = false;
    creditEarned = false;
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
        usedLifeline: usedLifeline,
      ),
    );

    if (ok) {
      correctCount[turn]++;
      if (usedLifeline) {
        // Half points, and the answer keeps the streak alive without
        // extending it or earning a credit.
        lastPoints = (100 + secondsLeft * 5) ~/ 2;
      } else {
        streak[turn]++;
        if (streak[turn] > bestStreak[turn]) bestStreak[turn] = streak[turn];
        lastPoints =
            100 + secondsLeft * 5 + (streak[turn] - 1).clamp(0, 10) * 10;
        if (lifelinesEnabled) {
          creditProgress[turn]++;
          if (creditProgress[turn] >= LifelineService.answersPerCredit) {
            creditProgress[turn] = 0;
            credits[turn]++;
            creditEarned = true;
          }
          _saveCredits();
        }
      }
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
