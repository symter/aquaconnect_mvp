import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "하루 요약 설정" — per-device notification preferences, selected from
/// MyPage. Persisted locally like [OceanStationPreferenceStore]; this is a
/// personal notification preference, not institute/org data, so it never
/// touches the `server/` API.
class DigestSettings {
  const DigestSettings({
    required this.dailyEnabled,
    required this.dailyTime,
    required this.weeklyEnabled,
  });

  static const defaults = DigestSettings(
    dailyEnabled: true,
    dailyTime: TimeOfDay(hour: 16, minute: 0),
    weeklyEnabled: true,
  );

  final bool dailyEnabled;
  final TimeOfDay dailyTime;

  /// Owner/director only — see [MemberRole]. Day/time are fixed (Monday
  /// morning), so there's no picker for it, just the toggle.
  final bool weeklyEnabled;

  DigestSettings copyWith({bool? dailyEnabled, TimeOfDay? dailyTime, bool? weeklyEnabled}) {
    return DigestSettings(
      dailyEnabled: dailyEnabled ?? this.dailyEnabled,
      dailyTime: dailyTime ?? this.dailyTime,
      weeklyEnabled: weeklyEnabled ?? this.weeklyEnabled,
    );
  }
}

class DigestSettingsStore {
  static const _dailyEnabledKey = 'aquaconnect.digest.daily_enabled';
  static const _dailyHourKey = 'aquaconnect.digest.daily_hour';
  static const _dailyMinuteKey = 'aquaconnect.digest.daily_minute';
  static const _weeklyEnabledKey = 'aquaconnect.digest.weekly_enabled';

  Future<DigestSettings> read() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = DigestSettings.defaults;
    return DigestSettings(
      dailyEnabled: prefs.getBool(_dailyEnabledKey) ?? defaults.dailyEnabled,
      dailyTime: TimeOfDay(
        hour: prefs.getInt(_dailyHourKey) ?? defaults.dailyTime.hour,
        minute: prefs.getInt(_dailyMinuteKey) ?? defaults.dailyTime.minute,
      ),
      weeklyEnabled: prefs.getBool(_weeklyEnabledKey) ?? defaults.weeklyEnabled,
    );
  }

  Future<void> write(DigestSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dailyEnabledKey, settings.dailyEnabled);
    await prefs.setInt(_dailyHourKey, settings.dailyTime.hour);
    await prefs.setInt(_dailyMinuteKey, settings.dailyTime.minute);
    await prefs.setBool(_weeklyEnabledKey, settings.weeklyEnabled);
  }
}
