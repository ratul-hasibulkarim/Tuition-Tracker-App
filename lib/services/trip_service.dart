import 'dart:convert';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Optional Google Maps Platform key, passed at build time:
/// `flutter build apk --dart-define=MAPS_API_KEY=...`
/// Without it, trip times are estimated from straight-line distance.
const mapsApiKey = String.fromEnvironment('MAPS_API_KEY');

class TripEstimate {
  const TripEstimate({required this.km, required this.minutes, required this.live});

  final double km;
  final double minutes;

  /// True when the time came from Google's live-traffic routing.
  final bool live;
}

class TripService {
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

  static Future<TripEstimate> estimate({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    if (mapsApiKey.isNotEmpty) {
      try {
        final live = await _routesApi(fromLat, fromLng, toLat, toLng);
        if (live != null) return live;
      } catch (_) {
        // Fall back to the offline estimate below.
      }
    }
    return roughEstimate(fromLat, fromLng, toLat, toLng);
  }

  /// Straight-line distance × 1.35 road factor, at ~18 km/h city bike speed.
  static TripEstimate roughEstimate(double lat1, double lng1, double lat2, double lng2) {
    final km = haversineKm(lat1, lng1, lat2, lng2) * 1.35;
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

  static Future<TripEstimate?> _routesApi(
      double fromLat, double fromLng, double toLat, double toLng) async {
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
              'origin': {
                'location': {
                  'latLng': {'latitude': fromLat, 'longitude': fromLng}
                }
              },
              'destination': {
                'location': {
                  'latLng': {'latitude': toLat, 'longitude': toLng}
                }
              },
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
      // Duration comes as e.g. "1234s".
      final secs = double.tryParse((r['duration'] as String? ?? '0s').replaceAll('s', '')) ?? 0;
      return TripEstimate(km: meters / 1000, minutes: secs / 60, live: true);
    }
    return null;
  }
}
