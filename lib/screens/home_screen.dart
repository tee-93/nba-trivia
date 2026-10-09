import 'package:flutter/material.dart';

import '../config.dart';
import '../data_service.dart';
import '../game_controller.dart';
import '../models.dart';
import '../settings.dart';
import '../stats_service.dart';
import '../theme.dart';
import '../update_service.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = DataService();
  final _updates = UpdateService();
  final _daily = DailyService();
  String? _version;
  GameData? _data;
  DailyStatus? _dailyStatus;
  String _status = 'Starting…';
  String? _error;

  GameMode _mode = GameMode.round;
  Difficulty _difficulty = Difficulty.easy;
  int _players = 1;
  final _names = [
    TextEditingController(text: 'Player 1'),
    TextEditingController(text: 'Player 2'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _refreshDaily();
    _updates
        .currentVersion()
        .then((v) {
          if (mounted) setState(() => _version = v);
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _refreshDaily() async {
    final s = await _daily.status();
    if (mounted) setState(() => _dailyStatus = s);
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _error = null;
      if (force) _data = null;
    });
    try {
      final d = await _service.load(
        force: force,
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load NBA data. Check your '
              'connection and try again.\n\n$e',
        );
      }
    }
  }

  Future<void> _start(
    GameMode mode,
    Difficulty diff,
    List<String> names,
  ) async {
    Fx.tap();
    final controller = GameController(
      data: _data!,
      mode: mode,
      difficulty: diff,
      names: names,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(controller: controller)),
    );
    _refreshDaily();
  }

  void _play() {
    final names = <String>[];
    for (var i = 0; i < _players; i++) {
      final t = _names[i].text.trim();
      names.add(t.isEmpty ? 'Player ${i + 1}' : t);
    }
    _start(_mode, _difficulty, names);
  }

  void _playDaily() {
    final t = _names[0].text.trim();
    _start(GameMode.daily, Difficulty.medium, [t.isEmpty ? 'Player 1' : t]);
  }

  void _open(Widget screen) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => screen),
  ).then((_) => _refreshDaily());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CourtBackground(child: SafeArea(child: _body(context))),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NBA JERSEY\nTRIVIA',
              textAlign: TextAlign.center,
              style: Court.display(56, color: Court.orange),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(color: Court.orange),
            const SizedBox(height: 16),
            Text(_status),
            const SizedBox(height: 4),
            Text(
              'First launch can take a minute.',
              style: TextStyle(color: Court.line.withValues(alpha: 0.55)),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Stats',
              icon: const Icon(Icons.bar_chart),
              onPressed: () => _open(const StatsScreen()),
            ),
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings),
              onPressed: () => _open(const SettingsScreen()),
            ),
          ],
        ),
        Text(
          'NBA JERSEY\nTRIVIA',
          textAlign: TextAlign.center,
          style: Court.display(64, color: Court.orange),
        ),
        const SizedBox(height: 4),
        Text(
          '${_data!.players.length} players from the 2020–2024 drafts',
          textAlign: TextAlign.center,
          style: TextStyle(color: Court.line.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 20),
        _dailyCard(),
        const SizedBox(height: 20),
        _label('Mode'),
        SegmentedButton<GameMode>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: GameMode.round,
              label: Text('10-question round'),
            ),
            ButtonSegment(
              value: GameMode.survival,
              label: Text('Survival (3 lives)'),
            ),
          ],
          selected: {_mode == GameMode.daily ? GameMode.round : _mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 16),
        _label('Difficulty'),
        SegmentedButton<Difficulty>(
          showSelectedIcon: false,
          segments: [
            for (final d in Difficulty.values)
              ButtonSegment(value: d, label: Text(d.label)),
          ],
          selected: {_difficulty},
          onSelectionChanged: (s) => setState(() => _difficulty = s.first),
        ),
        const SizedBox(height: 4),
        Text(
          '${_difficulty.seconds} seconds per question',
          style: TextStyle(
            color: Court.line.withValues(alpha: 0.55),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),
        _label('Players'),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 1, label: Text('1 player')),
            ButtonSegment(value: 2, label: Text('2 players')),
          ],
          selected: {_players},
          onSelectionChanged: (s) => setState(() => _players = s.first),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _players; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: _names[i],
              maxLength: 14,
              decoration: InputDecoration(
                labelText: 'Name, player ${i + 1}',
                border: const OutlineInputBorder(),
                counterText: '',
                filled: true,
                fillColor: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _play,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
          child: Text('PLAY', style: Court.display(28, color: Colors.black)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _open(const LeaderboardScreen()),
          icon: const Icon(Icons.emoji_events),
          label: const Text('Leaderboards'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () => _load(force: true),
              child: const Text('Refresh rosters'),
            ),
            // Personal builds are shared directly; the public release is
            // logo-free, so updating from it would remove the logos.
            if (!kPersonal)
              TextButton.icon(
                onPressed: _checkUpdate,
                icon: const Icon(Icons.system_update, size: 18),
                label: Text(
                  _version == null
                      ? 'Check for updates'
                      : 'Update (v$_version)',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _dailyCard() {
    final st = _dailyStatus;
    final done = st?.playedToday ?? false;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Court.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DAILY CHALLENGE', style: Court.display(22)),
                  Text(
                    done
                        ? "Done today: ${st!.correct ?? 0}/10 • ${st.score ?? 0} pts"
                        : 'Same 10 questions for everyone today',
                    style: TextStyle(
                      fontSize: 12,
                      color: Court.line.withValues(alpha: 0.7),
                    ),
                  ),
                  if ((st?.streak ?? 0) > 0)
                    Text(
                      '🔥 ${st!.streak}-day streak',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Court.amber,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _playDaily,
              child: Text(done ? 'Replay' : 'Play'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkUpdate() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Checking for updates…')),
    );
    try {
      final info = await _updates.check();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (!info.isNewer) {
        messenger.showSnackBar(
          SnackBar(content: Text("You're up to date (v${info.current}).")),
        );
        return;
      }
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Update available: v${info.latest}'),
          content: SingleChildScrollView(
            child: Text(
              'You have v${info.current}.'
              '${info.notes.trim().isEmpty ? '' : '\n\n${info.notes.trim()}'}'
              '${info.apkUrl == null ? '\n\nThis release has no APK attached.' : ''}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Later'),
            ),
            if (info.apkUrl != null)
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Download'),
              ),
          ],
        ),
      );
      if (go == true && info.apkUrl != null) {
        final ok = await _updates.download(info.apkUrl!);
        if (!ok && mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Could not open the download link.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Update check failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      t.toUpperCase(),
      style: TextStyle(
        letterSpacing: 1.6,
        fontSize: 12,
        color: Court.line.withValues(alpha: 0.6),
      ),
    ),
  );
}
