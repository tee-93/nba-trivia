import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Loads teams, rosters and draft years from ESPN's public NBA API and
/// caches the processed result on the device.
class DataService {
  static const _site =
      'https://site.api.espn.com/apis/site/v2/sports/basketball/nba';
  static const _core =
      'https://sports.core.api.espn.com/v2/sports/basketball/leagues/nba/athletes';

  static const minDraft = 2020;
  static const maxDraft = 2024;

  /// Well-known players always placed in the Easy tier.
  static const _stars = {
    'Anthony Edwards',
    'LaMelo Ball',
    'Tyrese Haliburton',
    'Cade Cunningham',
    'Scottie Barnes',
    'Evan Mobley',
    'Paolo Banchero',
    'Victor Wembanyama',
    'Chet Holmgren',
    'Jalen Williams',
    'Jalen Green',
    'Alperen Sengun',
    'Franz Wagner',
    'Tyrese Maxey',
    'Desmond Bane',
    'Josh Giddey',
    'Jaden Ivey',
    'Bronny James',
    'Jabari Smith Jr.',
    'Keegan Murray',
    'Isaiah Stewart',
    'Immanuel Quickley',
    'Jalen Suggs',
    'Anfernee Simons',
    'Tyrese Proctor',
  };

  Future<GameData> load({
    void Function(String)? onStatus,
    bool force = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('data_v1');
    final ts = prefs.getInt('data_ts') ?? 0;
    final fresh =
        DateTime.now().millisecondsSinceEpoch - ts <
        const Duration(hours: 24).inMilliseconds;
    if (cached != null && fresh && !force) return _decode(cached);

    try {
      final data = await _fetch(prefs, onStatus);
      await prefs.setString('data_v1', _encode(data));
      await prefs.setInt('data_ts', DateTime.now().millisecondsSinceEpoch);
      return data;
    } catch (_) {
      if (cached != null) return _decode(cached);
      rethrow;
    }
  }

  Future<GameData> _fetch(
    SharedPreferences prefs,
    void Function(String)? onStatus,
  ) async {
    onStatus?.call('Loading teams…');
    final tj = jsonDecode(await _get('$_site/teams'));
    final teamList = tj['sports'][0]['leagues'][0]['teams'] as List;
    final teams = <String, Team>{};
    for (final t in teamList) {
      final x = t['team'];
      teams[x['id']] = Team(
        id: x['id'],
        name: x['displayName'],
        abbr: x['abbreviation'] ?? '',
        color: colorFromHex(x['color'], const Color(0xFF444444)),
        alt: colorFromHex(x['alternateColor'], const Color(0xFFFFFFFF)),
      );
    }

    onStatus?.call('Loading rosters…');
    final rosters = await Future.wait(
      teams.keys.map((id) async {
        final body = await _get('$_site/teams/$id/roster');
        return MapEntry(id, jsonDecode(body));
      }),
    );

    // Roster entries with a jersey number and plausible NBA experience.
    final candidates = <Map<String, dynamic>>[];
    for (final r in rosters) {
      for (final a in (r.value['athletes'] as List? ?? [])) {
        final jersey = (a['jersey'] ?? '').toString();
        final exp = (a['experience']?['years'] as num?)?.toInt() ?? 0;
        if (jersey.isEmpty || exp < 1 || exp > 9) continue;
        final salary = (a['contract']?['salary'] as num?)?.toInt() ?? 0;
        candidates.add({
          'id': a['id'].toString(),
          'name': a['displayName'],
          'teamId': r.key,
          'number': jersey,
          'salary': salary,
        });
      }
    }

    // Draft years are cached permanently (they never change).
    final draftCache = <String, int>{
      for (final e
          in (jsonDecode(prefs.getString('draft_v1') ?? '{}') as Map).entries)
        e.key as String: e.value as int,
    };
    final missing = candidates
        .map((c) => c['id'] as String)
        .where((id) => !draftCache.containsKey(id))
        .toList();
    for (var i = 0; i < missing.length; i += 20) {
      onStatus?.call(
        'Checking draft classes… ${i.clamp(0, missing.length)}/${missing.length}',
      );
      final batch = missing.skip(i).take(20);
      final results = await Future.wait(
        batch.map((id) async {
          try {
            final j = jsonDecode(await _get('$_core/$id'));
            return MapEntry(id, (j['draft']?['year'] as num?)?.toInt() ?? 0);
          } catch (_) {
            return null; // retry next load
          }
        }),
      );
      for (final r in results) {
        if (r != null) draftCache[r.key] = r.value;
      }
    }
    await prefs.setString('draft_v1', jsonEncode(draftCache));

    final players = <Player>[];
    for (final c in candidates) {
      final year = draftCache[c['id']] ?? 0;
      if (year < minDraft || year > maxDraft) continue;
      final salary = c['salary'] as int;
      final tier = (_stars.contains(c['name']) || salary >= 35000000)
          ? 0
          : (salary >= 12000000 ? 1 : 2);
      players.add(
        Player(
          id: c['id'],
          name: c['name'],
          teamId: c['teamId'],
          number: c['number'],
          draftYear: year,
          tier: tier,
        ),
      );
    }
    if (players.length < 12) {
      throw Exception('Not enough player data returned (${players.length}).');
    }
    return GameData(teams, players);
  }

  Future<String> _get(String url) async {
    final res = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} for $url');
    }
    return res.body;
  }

  String _encode(GameData d) => jsonEncode({
    'teams': d.teams.values.map((t) => t.toJson()).toList(),
    'players': d.players.map((p) => p.toJson()).toList(),
  });

  GameData _decode(String s) {
    final j = jsonDecode(s);
    final teams = {
      for (final t in (j['teams'] as List)) ...{
        (t['id'] as String): Team.fromJson(t),
      },
    };
    final players = (j['players'] as List)
        .map((p) => Player.fromJson(p))
        .toList();
    return GameData(teams, players);
  }
}
