import 'package:flutter/material.dart';

enum Difficulty { easy, medium, hard }

extension DifficultyX on Difficulty {
  String get label => name[0].toUpperCase() + name.substring(1);
  int get seconds => switch (this) {
    Difficulty.easy => 20,
    Difficulty.medium => 12,
    Difficulty.hard => 8,
  };
}

enum GameMode { round, survival, daily }

enum QType { jerseyToPlayer, jerseyToTeam, nameToNumber, nameToTeam }

extension QTypeX on QType {
  String get label => switch (this) {
    QType.jerseyToPlayer => 'Jersey → player',
    QType.jerseyToTeam => 'Jersey → team',
    QType.nameToNumber => 'Player → number',
    QType.nameToTeam => 'Player → team',
  };
}

Color colorFromHex(String? hex, Color fallback) {
  if (hex == null || hex.length != 6) return fallback;
  final v = int.tryParse(hex, radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

class Team {
  Team({
    required this.id,
    required this.name,
    required this.abbr,
    required this.color,
    required this.alt,
  });

  final String id;
  final String name;
  final String abbr;
  final Color color;
  final Color alt;

  /// Colour for the jersey number: the team's alternate colour if it
  /// contrasts with the jersey, otherwise white or black.
  Color get numberColor {
    double d(Color a, Color b) =>
        (a.computeLuminance() - b.computeLuminance()).abs();
    if (d(color, alt) > 0.3) return alt;
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'abbr': abbr,
    'color': color.toARGB32(),
    'alt': alt.toARGB32(),
  };

  factory Team.fromJson(Map<String, dynamic> j) => Team(
    id: j['id'],
    name: j['name'],
    abbr: j['abbr'],
    color: Color(j['color']),
    alt: Color(j['alt']),
  );
}

class Player {
  Player({
    required this.id,
    required this.name,
    required this.teamId,
    required this.number,
    required this.draftYear,
    required this.tier,
  });

  final String id;
  final String name;
  final String teamId;
  final String number;
  final int draftYear;

  /// 0 = easy (well known), 1 = medium, 2 = hard.
  final int tier;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teamId': teamId,
    'number': number,
    'draftYear': draftYear,
    'tier': tier,
  };

  factory Player.fromJson(Map<String, dynamic> j) => Player(
    id: j['id'],
    name: j['name'],
    teamId: j['teamId'],
    number: j['number'],
    draftYear: j['draftYear'],
    tier: j['tier'],
  );
}

class GameData {
  GameData(this.teams, this.players);
  final Map<String, Team> teams;
  final List<Player> players;
}

class Question {
  Question({
    required this.type,
    required this.player,
    required this.team,
    required this.prompt,
    required this.choices,
    required this.correct,
  });

  final QType type;
  final Player player;
  final Team team;
  final String prompt;
  final List<String> choices;
  final int correct;

  bool get showsJersey =>
      type == QType.jerseyToPlayer || type == QType.jerseyToTeam;
}
