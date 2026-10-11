import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ViewMode { list, grid }

/// Rates used to estimate a bike-ride fare. Defaults are rough Dhaka
/// ride-share bike rates; the teacher can adjust them in Settings.
class FareRates {
  const FareRates({
    this.base = 30,
    this.perKm = 15,
    this.perMinute = 1,
    this.minimum = 45,
  });

  final double base;
  final double perKm;
  final double perMinute;
  final double minimum;

  double estimate({required double km, required double minutes}) {
    final fare = base + perKm * km + perMinute * minutes;
    return fare < minimum ? minimum : fare;
  }
}

class SettingsStore extends ChangeNotifier {
  late SharedPreferences _prefs;

  ThemeMode themeMode = ThemeMode.system;
  Locale locale = const Locale('en');
  ViewMode viewMode = ViewMode.list;
  FareRates fare = const FareRates();

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == _prefs.getString('themeMode'),
      orElse: () => ThemeMode.system,
    );
    locale = Locale(_prefs.getString('locale') ?? 'en');
    viewMode = _prefs.getString('viewMode') == 'grid' ? ViewMode.grid : ViewMode.list;
    const d = FareRates();
    fare = FareRates(
      base: _prefs.getDouble('fareBase') ?? d.base,
      perKm: _prefs.getDouble('farePerKm') ?? d.perKm,
      perMinute: _prefs.getDouble('farePerMinute') ?? d.perMinute,
      minimum: _prefs.getDouble('fareMinimum') ?? d.minimum,
    );
    notifyListeners();
  }

  bool get isBangla => locale.languageCode == 'bn';

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _prefs.setString('themeMode', m.name);
  }

  Future<void> setLocale(Locale l) async {
    locale = l;
    notifyListeners();
    await _prefs.setString('locale', l.languageCode);
  }

  Future<void> setViewMode(ViewMode m) async {
    viewMode = m;
    notifyListeners();
    await _prefs.setString('viewMode', m.name);
  }

  Future<void> setFare(FareRates f) async {
    fare = f;
    notifyListeners();
    await _prefs.setDouble('fareBase', f.base);
    await _prefs.setDouble('farePerKm', f.perKm);
    await _prefs.setDouble('farePerMinute', f.perMinute);
    await _prefs.setDouble('fareMinimum', f.minimum);
  }
}
