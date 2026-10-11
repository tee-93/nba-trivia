import 'package:shared_preferences/shared_preferences.dart';

/// Saved 50/50 credits and progress towards the next one.
class LifelineState {
  const LifelineState({this.credits = 0, this.progress = 0});
  final int credits;

  /// Unassisted correct answers since the last credit was earned (0..2).
  final int progress;
}

class LifelineService {
  /// Correct answers (without a 50/50) needed to earn one credit.
  static const answersPerCredit = 3;

  /// 50/50s every game starts with, before any saved credits.
  static const freePerGame = 1;

  static const _creditsKey = 'lifeline_credits';
  static const _progressKey = 'lifeline_progress';

  Future<LifelineState> load() async {
    final p = await SharedPreferences.getInstance();
    return LifelineState(
      credits: p.getInt(_creditsKey) ?? 0,
      progress: p.getInt(_progressKey) ?? 0,
    );
  }

  // Saves run one after another so a slow older write can't land after a
  // newer one and bring back a stale balance.
  static Future<void> _lastSave = Future.value();

  Future<void> save(int credits, int progress) {
    final next = _lastSave.then((_) async {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_creditsKey, credits);
      await p.setInt(_progressKey, progress);
    });
    _lastSave = next.catchError((_) {});
    return next;
  }
}
