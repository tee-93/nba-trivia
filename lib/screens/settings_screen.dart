import 'package:flutter/material.dart';

import '../config.dart';
import '../leaderboard.dart';
import '../settings.dart';
import '../stats_service.dart';
import '../theme.dart';
import '../update_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirm(
    BuildContext context,
    String title,
    String body,
    Future<void> Function() action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await action();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Done.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SETTINGS')),
      body: CourtBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: Settings.instance,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(12),
              children: [
                SwitchListTile(
                  title: const Text('Sound effects'),
                  value: Settings.instance.sound,
                  onChanged: Settings.instance.setSound,
                ),
                SwitchListTile(
                  title: const Text('Vibration'),
                  value: Settings.instance.haptics,
                  onChanged: Settings.instance.setHaptics,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Clear leaderboards'),
                  onTap: () => _confirm(
                    context,
                    'Clear leaderboards?',
                    'This removes every leaderboard entry on this phone.',
                    LeaderboardService().clear,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.restart_alt),
                  title: const Text('Reset lifetime stats'),
                  onTap: () => _confirm(
                    context,
                    'Reset stats?',
                    'Your accuracy stats will be erased.',
                    StatsService().clear,
                  ),
                ),
                const Divider(),
                FutureBuilder<String>(
                  future: UpdateService().currentVersion(),
                  builder: (_, snap) => ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('NBA Jersey Trivia'),
                    subtitle: Text(
                      'Version ${snap.data ?? '…'}${kPersonal ? ' (personal build)' : ''}\nRoster data from ESPN. Not affiliated with the NBA.',
                    ),
                    isThreeLine: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
