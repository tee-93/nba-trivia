import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nba_trivia/models.dart';
import 'package:nba_trivia/question_factory.dart';

GameData _data() {
  final teams = {
    for (var i = 1; i <= 8; i++)
      '$i': Team(
        id: '$i',
        name: 'Team $i',
        abbr: 'T$i',
        color: Color(0xFF000000 + i * 0x101010),
        alt: Colors.white,
      ),
  };
  final players = [
    for (var i = 0; i < 40; i++)
      Player(
        id: '${1000 + i}',
        name: 'Player $i',
        teamId: '${(i % 8) + 1}',
        number: '${i + 1}',
        draftYear: 2020 + (i % 5),
        tier: i % 3,
      ),
  ];
  return GameData(teams, players);
}

List<String> _sequence(int? seed) {
  final f = QuestionFactory(_data(), Difficulty.medium, seed: seed);
  return [
    for (var i = 0; i < 10; i++)
      () {
        final q = f.next();
        return '${q.type.name}|${q.player.id}|${q.choices.join(',')}|${q.correct}';
      }(),
  ];
}

void main() {
  test('same seed gives the same questions (daily challenge)', () {
    expect(_sequence(20261009), _sequence(20261009));
  });

  test('different seeds give different questions', () {
    expect(_sequence(20261009), isNot(_sequence(20261010)));
  });

  test('every question has 4 unique choices containing the answer', () {
    for (final d in Difficulty.values) {
      final f = QuestionFactory(_data(), d);
      for (var i = 0; i < 60; i++) {
        final q = f.next();
        expect(q.choices.length, 4, reason: '${d.name} ${q.type.name}');
        expect(q.choices.toSet().length, 4, reason: '${d.name} ${q.type.name}');
        expect(q.correct, inInclusiveRange(0, 3));
      }
    }
  });
}
