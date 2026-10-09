import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AnswerRecord {
  AnswerRecord({
    required this.playerIndex,
    required this.question,
    required this.picked,
    required this.ms,
  });

  final int playerIndex;
  final Question question;
  final int? picked; // null = ran out of time
  final int ms;

  bool get correct => picked == question.correct;
}

class LifetimeStats {
  LifetimeStats(this.games, this.perfectRounds, this.perType);
  final int games;
  final int perfectRounds;

  /// Per question type: [correct, total].
  final Map<QType, List<int>> perType;

  int get totalAnswered => perType.values.fold(0, (a, b) => a + b[1]);
  int get totalCorrect => perType.values.fold(0, (a, b) => a + b[0]);
}

class StatsService {
  static const _key = 'stats_v1';

  Future<Map<String, dynamic>> _raw() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_key);
    return s == null ? {} : jsonDecode(s) as Map<String, dynamic>;
  }

  Future<void> recordGame(
    List<AnswerRecord> history, {
    required int perfectRounds,
  }) async {
    final p = await SharedPreferences.getInstance();
    final raw = await _raw();
    raw['games'] = ((raw['games'] as int?) ?? 0) + 1;
    raw['perfect'] = ((raw['perfect'] as int?) ?? 0) + perfectRounds;
    final types = (raw['types'] as Map<String, dynamic>?) ?? {};
    for (final r in history) {
      final cur = (types[r.question.type.name] as List?)?.cast<int>() ?? [0, 0];
      types[r.question.type.name] = [cur[0] + (r.correct ? 1 : 0), cur[1] + 1];
    }
    raw['types'] = types;
    await p.setString(_key, jsonEncode(raw));
  }

  Future<LifetimeStats> load() async {
    final raw = await _raw();
    final types = (raw['types'] as Map<String, dynamic>?) ?? {};
    return LifetimeStats(
      (raw['games'] as int?) ?? 0,
      (raw['perfect'] as int?) ?? 0,
      {
        for (final t in QType.values)
          t: ((types[t.name] as List?)?.cast<int>()) ?? [0, 0],
      },
    );
  }

  Future<void> clear() async {
    (await SharedPreferences.getInstance()).remove(_key);
  }
}

class DailyStatus {
  DailyStatus({
    required this.streak,
    required this.playedToday,
    this.score,
    this.correct,
  });
  final int streak;
  final bool playedToday;
  final int? score;
  final int? correct;
}

/// One fixed question set per day; tracks a streak of consecutive days played.
class DailyService {
  static const _key = 'daily_v1';

  static String dateKey([DateTime? d]) {
    final n = d ?? DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Deterministic seed for a date, the same on every phone.
  static int seedFor([DateTime? d]) {
    final n = d ?? DateTime.now();
    return n.year * 10000 + n.month * 100 + n.day;
  }

  Future<Map<String, dynamic>> _raw() async {
    final s = (await SharedPreferences.getInstance()).getString(_key);
    return s == null ? {} : jsonDecode(s) as Map<String, dynamic>;
  }

  Future<DailyStatus> status() async {
    final raw = await _raw();
    final last = raw['last'] as String?;
    final today = dateKey();
    final yesterday = dateKey(DateTime.now().subtract(const Duration(days: 1)));
    var streak = (raw['streak'] as int?) ?? 0;
    if (last != today && last != yesterday) streak = 0; // streak broken
    final played = last == today;
    return DailyStatus(
      streak: streak,
      playedToday: played,
      score: played ? raw['score'] as int? : null,
      correct: played ? raw['correct'] as int? : null,
    );
  }

  /// Records today's result; later replays the same day don't count.
  Future<void> recordIfFirst({required int score, required int correct}) async {
    final st = await status();
    if (st.playedToday) return;
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _key,
      jsonEncode({
        'last': dateKey(),
        'streak': st.streak + 1,
        'score': score,
        'correct': correct,
      }),
    );
  }
}
