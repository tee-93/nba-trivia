import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

enum Board { fastest, streak, survival }

extension BoardX on Board {
  String get title => switch (this) {
    Board.fastest => 'Fastest perfect',
    Board.streak => 'Best streak',
    Board.survival => 'Survival score',
  };

  /// Fastest is lower-is-better; the others are higher-is-better.
  bool get lowerIsBetter => this == Board.fastest;

  String format(int v) => switch (this) {
    Board.fastest => '${(v / 1000).toStringAsFixed(1)}s',
    Board.streak => '$v in a row',
    Board.survival => '$v pts',
  };
}

class LbEntry {
  LbEntry(this.board, this.name, this.difficulty, this.value, this.ts);
  final Board board;
  final String name;
  final Difficulty difficulty;
  final int value;
  final int ts;

  Map<String, dynamic> toJson() => {
    'b': board.name,
    'n': name,
    'd': difficulty.name,
    'v': value,
    't': ts,
  };

  factory LbEntry.fromJson(Map<String, dynamic> j) => LbEntry(
    Board.values.byName(j['b']),
    j['n'],
    Difficulty.values.byName(j['d']),
    j['v'],
    j['t'],
  );
}

/// On-device leaderboards, shared by everyone who plays on this phone.
class LeaderboardService {
  static const _key = 'lb_v1';

  Future<List<LbEntry>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => LbEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> record(
    Board board,
    String name,
    Difficulty diff,
    int value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _all();
    all.add(
      LbEntry(board, name, diff, value, DateTime.now().millisecondsSinceEpoch),
    );
    await prefs.setString(
      _key,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<LbEntry>> top(Board board, Difficulty diff, {int n = 10}) async {
    final list = (await _all())
        .where((e) => e.board == board && e.difficulty == diff)
        .toList();
    list.sort(
      (a, b) => board.lowerIsBetter
          ? a.value.compareTo(b.value)
          : b.value.compareTo(a.value),
    );
    return list.take(n).toList();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
