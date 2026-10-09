import 'dart:math';

import 'models.dart';

class QuestionFactory {
  /// With a [seed] the question sequence is reproducible (daily challenge).
  QuestionFactory(this.data, this.difficulty, {int? seed})
    : _rng = seed == null ? Random() : Random(seed) {
    // Sorting makes the pool order independent of how rosters were fetched.
    final all = [...data.players]..sort((a, b) => a.id.compareTo(b.id));
    final p = switch (difficulty) {
      Difficulty.easy => all.where((x) => x.tier == 0).toList(),
      Difficulty.medium => all.where((x) => x.tier <= 1).toList(),
      Difficulty.hard => all,
    };
    pool = p.length < 8 ? all : p;
    _sorted = all;
  }

  final GameData data;
  final Difficulty difficulty;
  final Random _rng;
  late final List<Player> _sorted;
  final _used = <String>{};
  late final List<Player> pool;

  Question next() {
    var avail = pool.where((p) => !_used.contains(p.id)).toList();
    if (avail.isEmpty) {
      _used.clear();
      avail = pool;
    }
    final player = avail[_rng.nextInt(avail.length)];
    _used.add(player.id);
    final team = data.teams[player.teamId]!;
    final type = QType.values[_rng.nextInt(QType.values.length)];

    switch (type) {
      case QType.jerseyToPlayer:
        return _build(
          type,
          player,
          team,
          'Whose jersey is this?',
          player.name,
          _playerDistractors(player).map((p) => p.name),
        );
      case QType.nameToNumber:
        return _build(
          type,
          player,
          team,
          'What number does ${player.name} wear?',
          '#${player.number}',
          _numberDistractors(player).map((n) => '#$n'),
        );
      case QType.jerseyToTeam:
        return _build(
          type,
          player,
          team,
          'Which team does this player play for?',
          team.name,
          _teamDistractors(team),
        );
      case QType.nameToTeam:
        return _build(
          type,
          player,
          team,
          'Which team does ${player.name} play for?',
          team.name,
          _teamDistractors(team),
        );
    }
  }

  Question _build(
    QType type,
    Player player,
    Team team,
    String prompt,
    String answer,
    Iterable<String> distractors,
  ) {
    final choices = <String>[answer, ...distractors.take(3)]..shuffle(_rng);
    return Question(
      type: type,
      player: player,
      team: team,
      prompt: prompt,
      choices: choices,
      correct: choices.indexOf(answer),
      teamByChoice: (type == QType.jerseyToTeam || type == QType.nameToTeam)
          ? {for (final t in data.teams.values) t.name: t}
          : null,
    );
  }

  List<Player> _playerDistractors(Player p) {
    final others =
        _sorted.where((x) => x.id != p.id && x.name != p.name).toList()
          ..shuffle(_rng);
    final out = <Player>[];
    void take(bool Function(Player) test) {
      for (final o in others) {
        if (out.length == 3) return;
        if (!out.contains(o) && test(o)) out.add(o);
      }
    }

    switch (difficulty) {
      case Difficulty.easy:
        // Different teams, so the jersey colour gives a fair hint.
        final seen = <String>{p.teamId};
        take((o) => seen.add(o.teamId));
      case Difficulty.medium:
        break;
      case Difficulty.hard:
        // Teammates first: same jersey colour, only the number helps.
        take((o) => o.teamId == p.teamId);
    }
    take((_) => true);
    return out;
  }

  Iterable<String> _teamDistractors(Team t) {
    final others = data.teams.values.where((x) => x.id != t.id).toList()
      ..sort((a, b) => a.id.compareTo(b.id))
      ..shuffle(_rng);
    if (difficulty == Difficulty.hard) {
      // Similar-coloured teams are the most confusable.
      double dist(Team x) {
        final a = x.color, b = t.color;
        return (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
      }

      others.sort((a, b) => dist(a).compareTo(dist(b)));
    }
    return others.take(3).map((x) => x.name);
  }

  Iterable<String> _numberDistractors(Player p) {
    final real = int.tryParse(p.number);
    final out = <String>{};
    if (difficulty == Difficulty.hard && real != null) {
      final near = [
        for (var d = -6; d <= 6; d++)
          if (d != 0) real + d,
      ].where((n) => n >= 0 && n <= 99).toList()..shuffle(_rng);
      out.addAll(near.take(3).map((n) => '$n'));
    }
    final others = _sorted.map((x) => x.number).toSet()..remove(p.number);
    final list = others.toList()..shuffle(_rng);
    for (final n in list) {
      if (out.length >= 3) break;
      out.add(n);
    }
    return out;
  }
}
