import 'package:flutter/material.dart';

import '../data_service.dart';
import '../game_controller.dart';
import '../models.dart';
import '../update_service.dart';
import 'game_screen.dart';
import 'leaderboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = DataService();
  final _updates = UpdateService();
  String? _version;
  GameData? _data;
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
    _updates.currentVersion().then((v) {
      if (mounted) setState(() => _version = v);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
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
        setState(() => _error = 'Could not load NBA data. Check your '
            'connection and try again.\n\n$e');
      }
    }
  }

  void _play() {
    final data = _data!;
    final names = <String>[];
    for (var i = 0; i < _players; i++) {
      final t = _names[i].text.trim();
      names.add(t.isEmpty ? 'Player ${i + 1}' : t);
    }
    final controller = GameController(
      data: data,
      mode: _mode,
      difficulty: _difficulty,
      names: names,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GameScreen(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(child: _body(context)),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_data == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(_status),
          const SizedBox(height: 4),
          const Text('First launch can take a minute.',
              style: TextStyle(color: Colors.white54)),
        ],
      );
    }

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        Text('NBA JERSEY\nTRIVIA',
            textAlign: TextAlign.center,
            style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.primary,
                height: 1.05)),
        const SizedBox(height: 4),
        Text('${_data!.players.length} players from the 2020–2024 drafts',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 24),
        _label('Mode'),
        SegmentedButton<GameMode>(
          segments: const [
            ButtonSegment(value: GameMode.round, label: Text('10-question round')),
            ButtonSegment(value: GameMode.survival, label: Text('Survival (3 lives)')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 16),
        _label('Difficulty'),
        SegmentedButton<Difficulty>(
          segments: [
            for (final d in Difficulty.values)
              ButtonSegment(value: d, label: Text(d.label)),
          ],
          selected: {_difficulty},
          onSelectionChanged: (s) => setState(() => _difficulty = s.first),
        ),
        const SizedBox(height: 4),
        Text('${_difficulty.seconds} seconds per question',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 16),
        _label('Players'),
        SegmentedButton<int>(
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
                labelText: 'Name — player ${i + 1}',
                border: const OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _play,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          child: const Text('PLAY', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen())),
          icon: const Icon(Icons.emoji_events),
          label: const Text('Leaderboards'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
        TextButton(
          onPressed: () => _load(force: true),
          child: const Text('Refresh rosters'),
        ),
        TextButton.icon(
          onPressed: _checkUpdate,
          icon: const Icon(Icons.system_update),
          label: Text(_version == null
              ? 'Check for updates'
              : 'Check for updates (v$_version)'),
        ),
      ],
    );
  }

  Future<void> _checkUpdate() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('Checking for updates…')));
    try {
      final info = await _updates.check();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      if (!info.isNewer) {
        messenger.showSnackBar(SnackBar(
            content: Text("You're up to date (v${info.current}).")));
        return;
      }
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Update available: v${info.latest}'),
          content: Text(
            'You have v${info.current}.'
            '${info.notes.trim().isEmpty ? '' : '\n\n${info.notes.trim()}'}'
            '${info.apkUrl == null ? '\n\nThis release has no APK attached.' : ''}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
            if (info.apkUrl != null)
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Download')),
          ],
        ),
      );
      if (go == true && info.apkUrl != null) {
        final ok = await _updates.download(info.apkUrl!);
        if (!ok && mounted) {
          messenger.showSnackBar(const SnackBar(content: Text('Could not open the download link.')));
        }
      }
    } catch (e) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
          content: Text('Update check failed: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                letterSpacing: 1.2, fontSize: 12, color: Colors.white54)),
      );
}
