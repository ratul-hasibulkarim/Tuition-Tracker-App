import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../models/student.dart';

/// Opens the dialer, WhatsApp, maps and ride-share apps.
class Launcher {
  static String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

  /// Converts local Bangladeshi numbers (01XXXXXXXXX) to 8801XXXXXXXXX for WhatsApp.
  static String toInternational(String phone) {
    var d = _digits(phone).replaceAll('+', '');
    if (d.startsWith('00')) d = d.substring(2);
    if (d.startsWith('0') && d.length == 11) d = '88$d';
    return d;
  }

  static Future<bool> call(String phone) =>
      launchUrl(Uri(scheme: 'tel', path: _digits(phone)));

  static Future<bool> whatsapp(String phone) => launchUrl(
        Uri.parse('https://wa.me/${toInternational(phone)}'),
        mode: LaunchMode.externalApplication,
      );

  static String _destination(Student s) =>
      s.hasLocation ? '${s.latitude},${s.longitude}' : s.address;

  /// Google Maps turn-by-turn directions, using the motorbike travel mode.
  static Future<bool> directions(Student s) => launchUrl(
        Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': _destination(s),
          'travelmode': 'two-wheeler',
        }),
        mode: LaunchMode.externalApplication,
      );

  /// The whole day's route (home → students in order → home) in Google Maps.
  /// Google Maps links allow up to 9 stops in between.
  static Future<bool> dayRoute({String? home, required List<Student> stops}) {
    final located = stops.where((s) => s.hasLocation).map(_destination).toList();
    if (located.isEmpty) return Future.value(false);
    final destination = home ?? located.removeLast();
    final waypoints = located.take(9).join('|');
    return launchUrl(
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'origin': ?home,
        'destination': destination,
        if (waypoints.isNotEmpty) 'waypoints': waypoints,
        'travelmode': 'two-wheeler',
      }),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Uber's universal link with the drop-off pre-filled.
  static Future<bool> uber(Student s) {
    final params = <String, String>{
      'action': 'setPickup',
      'pickup': 'my_location',
      if (s.hasLocation) 'dropoff[latitude]': '${s.latitude}',
      if (s.hasLocation) 'dropoff[longitude]': '${s.longitude}',
      'dropoff[nickname]': s.name,
      if (s.address.isNotEmpty) 'dropoff[formatted_address]': s.address,
    };
    return launchUrl(
      Uri.https('m.uber.com', '/ul/', params),
      mode: LaunchMode.externalApplication,
    );
  }

  /// Pathao has no public deep link for setting a destination, so this opens
  /// the app's store page (which shows "Open" when it is installed).
  static Future<bool> pathao() => launchUrl(
        Platform.isIOS
            ? Uri.parse(
                'itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?media=software&term=Pathao')
            : Uri.parse('market://details?id=com.pathao.user'),
        mode: LaunchMode.externalApplication,
      );
}
