import 'package:shared_preferences/shared_preferences.dart';

/// The user's chosen "바다 위치" (sea location) for water-temp display,
/// selected from MyPage. Persisted locally like [AuthTokenStore] — this is
/// a per-device UI preference, not institute/org data, so it never touches
/// the `server/` API.
class OceanStationSelection {
  const OceanStationSelection({required this.code, required this.name});

  final String code;
  final String name;
}

class OceanStationPreferenceStore {
  static const _codeKey = 'aquaconnect.ocean_station.code';
  static const _nameKey = 'aquaconnect.ocean_station.name';

  Future<OceanStationSelection?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_codeKey);
    final name = prefs.getString(_nameKey);
    if (code == null || name == null) return null;
    return OceanStationSelection(code: code, name: name);
  }

  Future<void> write(OceanStationSelection selection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_codeKey, selection.code);
    await prefs.setString(_nameKey, selection.name);
  }
}
