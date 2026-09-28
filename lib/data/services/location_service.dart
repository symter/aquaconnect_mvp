import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../models/ocean_reading.dart';

class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

class LocationException implements Exception {
  const LocationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads the device's current position through the browser Geolocation
/// API. Only works in a secure context (https or localhost), and the
/// browser asks the user for permission the first time.
class LocationService {
  Future<GeoPoint> currentPosition() {
    final completer = Completer<GeoPoint>();
    final geolocation = web.window.navigator.geolocation;

    geolocation.getCurrentPosition(
      ((web.GeolocationPosition position) {
        if (completer.isCompleted) return;
        completer.complete(GeoPoint(position.coords.latitude, position.coords.longitude));
      }).toJS,
      ((web.GeolocationPositionError error) {
        if (completer.isCompleted) return;
        completer.completeError(LocationException(switch (error.code) {
          1 => '위치 권한이 거부되었어요. 브라우저 설정에서 위치 접근을 허용해주세요.',
          2 => '현재 위치를 확인할 수 없어요.',
          3 => '위치 확인 시간이 초과되었어요. 다시 시도해주세요.',
          _ => '위치를 가져오지 못했어요.',
        }));
      }).toJS,
      web.PositionOptions(enableHighAccuracy: true, timeout: 15000, maximumAge: 60000),
    );

    return completer.future;
  }
}

/// Great-circle distance in kilometers (haversine).
double distanceKm(GeoPoint a, double latitude, double longitude) {
  const earthRadiusKm = 6371.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(latitude - a.latitude);
  final dLon = rad(longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) * math.cos(rad(latitude)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * earthRadiusKm * math.asin(math.sqrt(h));
}

/// A station paired with its distance from the user.
class StationDistance {
  const StationDistance(this.station, this.distanceKm);
  final OceanStation station;
  final double distanceKm;
}

/// Stations with coordinates, nearest first.
List<StationDistance> sortByDistance(GeoPoint from, List<OceanStation> stations) {
  return stations
      .where((s) => s.hasCoordinates)
      .map((s) => StationDistance(s, distanceKm(from, s.latitude!, s.longitude!)))
      .toList()
    ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
}
