import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Once-per-UTC-day soft Daily Missions nudge (local only).
class DailyMissionsNudgePrefs {
  DailyMissionsNudgePrefs({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const shownDayKey = 'arcori_daily_missions_nudge_day';

  final FlutterSecureStorage _storage;

  Future<String?> readShownDayKey() => _storage.read(key: shownDayKey);

  Future<void> writeShownDayKey(String dayKey) async {
    final trimmed = dayKey.trim();
    if (trimmed.isEmpty) return;
    await _storage.write(key: shownDayKey, value: trimmed);
  }
}
