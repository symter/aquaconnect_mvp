import 'dart:convert';

import 'package:http/http.dart' as http;

import 'location_service.dart';

/// Turns a picked 주소 into coordinates so the nearest 수온 관측소 can be
/// recommended. The Daum postcode popup returns no coordinates, and Kakao's
/// geocoder needs a key, so this uses OpenStreetMap Nominatim (free, no key,
/// CORS-enabled). Korean road addresses are patchy in OSM, so when the full
/// address finds nothing it retries with the trailing words dropped
/// ("완도군 노화읍 …" → "완도군 노화읍") — coarser, but still close enough to
/// pick the right nearby station.
class AddressGeocoder {
  AddressGeocoder({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<GeoPoint?> locate(String address) async {
    final words = address.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    // Never drop below 2 words ("시/도 + 시/군") — a lone "전라남도" is too coarse.
    for (var count = words.length; count >= 2 && count >= words.length - 4; count--) {
      final point = await _query(words.take(count).join(' '));
      if (point != null) return point;
    }
    return null;
  }

  Future<GeoPoint?> _query(String q) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'limit': '1',
        'countrycodes': 'kr',
        'accept-language': 'ko',
        'q': q,
      });
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List<dynamic>;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final lat = double.tryParse('${first['lat']}');
      final lon = double.tryParse('${first['lon']}');
      return lat == null || lon == null ? null : GeoPoint(lat, lon);
    } catch (_) {
      return null;
    }
  }
}
