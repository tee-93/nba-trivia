import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nba_trivia/game_controller.dart';
import 'package:nba_trivia/lifeline_service.dart';
import 'package:nba_trivia/models.dart';
import 'package:nba_trivia/question_factory.dart';
import 'package:nba_trivia/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

GameData _data() {
  final teams = {
    for (var i = 1; i <= 10; i++)
      '$i': Team(
        id: '$i',
        name: 'Team $i',
        abbr: 'T$i',
        color: Color(0xFF000000 + i * 0x181818),
        alt: Colors.white,
      ),
  };
  final players = [
    for (var i = 0; i < 40; i++)
      Player(
        id: '${1000 + i}',
        name: 'Player $i',
        teamId: '${(i % 10) + 1}',
        number: '${i + 1}',
        draftYear: 2020 + (i % 5),
        tier: i % 3,
      ),
  ];
  return GameData(teams, players);
}

GameController _game({
  GameMode mode = GameMode.round,
  Difficulty difficulty = Difficulty.medium,
  List<String> names = const ['Solo'],
  int credits = 0,
  int progress = 0,
}) => GameController(
  data: _data(),
  mode: mode,
  difficulty: difficulty,
  names: names,
  startingCredits: credits,
  startingProgress: progress,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // The audio plugin isn't available in unit tests.
    Settings.instance.sound = false;
    Settings.instance.haptics = false;
  });

  group('Very Easy', () {
    test('uses 3 unique choices and only the easy question types', () {
      final f = QuestionFactory(_data(), Difficulty.veryEasy);
      for (var i = 0; i < 80; i++) {
        final q = f.next();
        expect(q.choices.length, 3);
        expect(q.choices.toSet().length, 3);
        expect(q.type, isNot(QType.nameToNumber));
        expect(q.player.tier, 0, reason: 'only well-known players');
      }
    });
  });

  group('50/50', () {
    test('every game starts with one free 50/50', () {
      final c = _game();
      expect(c.freeLeft[0], 1);
      expect(c.canUseLifeline, isTrue);
      c.dispose();
    });

    test('removes two wrong answers and keeps the right one (4 choices)', () {
      final c = _game();
      c.useLifeline();
      expect(c.eliminated.length, 2);
      expect(c.eliminated.contains(c.question.correct), isFalse);
      expect(c.freeLeft[0], 0);
      expect(c.canUseLifeline, isFalse, reason: 'one per question');
      c.dispose();
    });

    test('removes one wrong answer on Very Easy (3 choices)', () {
      final c = _game(difficulty: Difficulty.veryEasy);
      c.useLifeline();
      expect(c.eliminated.length, 1);
      expect(c.eliminated.contains(c.question.correct), isFalse);
      c.dispose();
    });

    test('a 50/50 answer scores half and does not extend the streak', () {
      final c = _game();
      c.useLifeline();
      final secondsLeft = c.secondsLeft;
      c.answer(c.question.correct);
      expect(c.lastPoints, (100 + secondsLeft * 5) ~/ 2);
      expect(c.streak[0], 0);
      expect(c.bestStreak[0], 0);
      expect(c.correctCount[0], 1);
      expect(c.creditProgress[0], 0, reason: 'assisted answers earn nothing');
      c.dispose();
    });

    test('3 unassisted correct answers earn a credit', () {
      final c = _game();
      for (var i = 0; i < 3; i++) {
        c.answer(c.question.correct);
        if (i < 2) c.next();
      }
      expect(c.credits[0], 1);
      expect(c.creditProgress[0], 0);
      expect(c.creditEarned, isTrue);
      c.dispose();
    });

    test('credits are spent after the free one is used', () {
      final c = _game(credits: 2);
      c.useLifeline();
      expect(c.freeLeft[0], 0);
      expect(c.credits[0], 2, reason: 'free one is spent first');
      c.answer(c.question.correct);
      c.next();
      c.useLifeline();
      expect(c.credits[0], 1);
      c.dispose();
    });

    test('credits are saved for single-player games', () async {
      final c = _game(credits: 1, progress: 1);
      c.useLifeline(); // free
      c.answer(c.question.correct);
      c.next();
      c.useLifeline(); // spends the saved credit
      await pumpEventQueue(); // let the async save finish
      final saved = await LifelineService().load();
      expect(saved.credits, 0);
      c.dispose();
    });

    test('two-player games do not touch saved credits', () async {
      await LifelineService().save(5, 1);
      final c = _game(names: const ['A', 'B'], credits: 5, progress: 1);
      expect(c.credits, [0, 0]);
      expect(c.freeLeft, [1, 1]);
      c.dispose();
      final saved = await LifelineService().load();
      expect(saved.credits, 5);
    });

    test('Daily Challenge has no lifelines', () {
      final c = _game(mode: GameMode.daily, credits: 3);
      expect(c.lifelinesEnabled, isFalse);
      expect(c.canUseLifeline, isFalse);
      c.useLifeline();
      expect(c.eliminated, isEmpty);
      c.dispose();
    });
  });
}
