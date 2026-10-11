import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User preferences (sound, vibration), persisted on the device.
class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  bool sound = true;
  bool haptics = true;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    sound = p.getBool('sound') ?? true;
    haptics = p.getBool('haptics') ?? true;
    notifyListeners();
  }

  Future<void> setSound(bool v) async {
    sound = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('sound', v);
  }

  Future<void> setHaptics(bool v) async {
    haptics = v;
    notifyListeners();
    (await SharedPreferences.getInstance()).setBool('haptics', v);
  }
}

enum Sfx { correct, wrong, tick, gameover, perfect, buzzer, lifeline }

/// Plays short sound effects and haptic pulses, honouring [Settings].
class Fx {
  static final _players = <Sfx, AudioPlayer>{};

  static Future<void> play(Sfx sfx) async {
    if (!Settings.instance.sound) return;
    try {
      final p = _players.putIfAbsent(sfx, () {
        final player = AudioPlayer();
        player.setPlayerMode(PlayerMode.lowLatency);
        return player;
      });
      await p.stop();
      await p.play(AssetSource('sounds/${sfx.name}.wav'));
    } catch (_) {
      // Audio is a nicety; never break the game over it.
    }
  }

  static void tap() {
    if (Settings.instance.haptics) HapticFeedback.selectionClick();
  }

  static void good() {
    if (Settings.instance.haptics) HapticFeedback.lightImpact();
  }

  static void bad() {
    if (Settings.instance.haptics) HapticFeedback.heavyImpact();
  }
}
