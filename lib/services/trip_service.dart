import 'dart:convert';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'api_client.dart';

/// Optional Google Maps key used directly from the app when no server is
/// set up: `--dart-define=MAPS_API_KEY=...`. Prefer the server (API_BASE_URL)
/// for store builds so the key is not inside the app.
const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

class LatLngPoint {
  const LatLngPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  Map<String, double> toJson() => {'lat': lat, 'lng': lng};
}

class TripEstimate {
  const TripEstimate({required this.km, required this.minutes, required this.live});

  final double km;
  final double minutes;

  /// True when the time came from Google's live-traffic routing.
  final bool live;
}

/// Travel minutes and km between every pair of points.
class TravelMatrix {
  const TravelMatrix({required this.minutes, required this.km, required this.live});

  final List<List<double>> minutes;
  final List<List<double>> km;
  final bool live;
}

class TripService {
  TripService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// Returns the phone's position, asking for permission if needed.
  /// Returns null when location is off or permission is denied.
  static Future<Position?> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Live-traffic estimate via the server (or a direct key), else a rough one.
  Future<TripEstimate> estimate(LatLngPoint from, LatLngPoint to) async {
    try {
      if (_api.configured) {
        final r = await _api.post('/v1/route', {'origin': from.toJson(), 'destination': to.toJson()});
        return TripEstimate(
          km: (r['km'] as num).toDouble(),
          minutes: (r['minutes'] as num).toDouble(),
          live: true,
        );
      }
      if (mapsApiKey.isNotEmpty) {
        final live = await _routesApiDirect(from, to);
        if (live != null) return live;
      }
    } catch (_) {
      // Fall back to the offline estimate below.
    }
    return roughEstimate(from, to);
  }

  /// Travel times between all [points] (max 10 for the live version).
  Future<TravelMatrix> matrix(List<LatLngPoint> points) async {
    if (_api.configured && points.length >= 2 && points.length <= 10) {
      try {
        final r = await _api.post('/v1/route-matrix', {
          'points': points.map((p) => p.toJson()).toList(),
        });
        final rough = roughMatrix(points);
        List<List<double>> read(String key, List<List<double>> fallback) => [
              for (var i = 0; i < points.length; i++)
                [
                  for (var j = 0; j < points.length; j++)
                    ((r[key] as List)[i] as List)[j] == null
                        ? fallback[i][j]
                        : (((r[key] as List)[i] as List)[j] as num).toDouble(),
                ],
            ];
        return TravelMatrix(
          minutes: read('minutes', rough.minutes),
          km: read('km', rough.km),
          live: true,
        );
      } catch (_) {
        // Use the rough matrix.
      }
    }
    return roughMatrix(points);
  }

  static TravelMatrix roughMatrix(List<LatLngPoint> points) {
    final n = points.length;
    final minutes = List.generate(n, (_) => List.filled(n, 0.0));
    final km = List.generate(n, (_) => List.filled(n, 0.0));
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        if (i == j) continue;
        final t = roughEstimate(points[i], points[j]);
        minutes[i][j] = t.minutes;
        km[i][j] = t.km;
      }
    }
    return TravelMatrix(minutes: minutes, km: km, live: false);
  }

  /// Straight-line distance × 1.35 road factor, at ~18 km/h city bike speed.
  static TripEstimate roughEstimate(LatLngPoint a, LatLngPoint b) {
    final km = haversineKm(a.lat, a.lng, b.lat, b.lng) * 1.35;
    return TripEstimate(km: km, minutes: km / 18 * 60, live: false);
  }

  static double haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return 2 * r * asin(sqrt(a));
  }

  static Future<TripEstimate?> _routesApiDirect(LatLngPoint from, LatLngPoint to) async {
    Map<String, dynamic> wp(LatLngPoint p) => {
          'location': {
            'latLng': {'latitude': p.lat, 'longitude': p.lng}
          }
        };
    for (final mode in ['TWO_WHEELER', 'DRIVE']) {
      final res = await http
          .post(
            Uri.parse('https://routes.googleapis.com/directions/v2:computeRoutes'),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': mapsApiKey,
              'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters',
            },
            body: jsonEncode({
              'origin': wp(from),
              'destination': wp(to),
              'travelMode': mode,
              'routingPreference': 'TRAFFIC_AWARE',
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) continue;
      final routes = (jsonDecode(res.body) as Map<String, dynamic>)['routes'] as List?;
      if (routes == null || routes.isEmpty) continue;
      final r = routes.first as Map<String, dynamic>;
      final meters = (r['distanceMeters'] as num?)?.toDouble() ?? 0;
      final secs = double.tryParse((r['duration'] as String? ?? '0s').replaceAll('s', '')) ?? 0;
      return TripEstimate(km: meters / 1000, minutes: secs / 60, live: true);
    }
    return null;
  }
}
