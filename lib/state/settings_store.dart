import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ai_service.dart';

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
  SettingsStore({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  late SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  ThemeMode themeMode = ThemeMode.system;
  Locale locale = const Locale('en');
  ViewMode viewMode = ViewMode.list;
  FareRates fare = const FareRates();

  /// Where the teacher starts the day (usually home), for routine planning.
  double? homeLat;
  double? homeLng;
  String homeLabel = '';

  /// How many minutes earlier/later than usual a class may move when the
  /// routine planner looks for a shorter travel order.
  int flexMinutes = 30;

  AiProvider aiProvider = AiProvider.gemini;
  String aiModel = '';
  String aiKey = '';

  bool get hasHome => homeLat != null && homeLng != null;

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
    homeLat = _prefs.getDouble('homeLat');
    homeLng = _prefs.getDouble('homeLng');
    homeLabel = _prefs.getString('homeLabel') ?? '';
    flexMinutes = _prefs.getInt('flexMinutes') ?? 30;
    aiProvider = AiProvider.values.firstWhere(
      (p) => p.name == _prefs.getString('aiProvider'),
      orElse: () => AiProvider.gemini,
    );
    aiModel = _prefs.getString('aiModel') ?? '';
    try {
      aiKey = await _secure.read(key: 'aiKey') ?? '';
    } catch (_) {
      aiKey = '';
    }
    notifyListeners();
  }

  AiService aiService() =>
      AiService(provider: aiProvider, model: aiModel, ownKey: aiKey);

  Future<void> setHome(double lat, double lng, String label) async {
    homeLat = lat;
    homeLng = lng;
    homeLabel = label;
    notifyListeners();
    await _prefs.setDouble('homeLat', lat);
    await _prefs.setDouble('homeLng', lng);
    await _prefs.setString('homeLabel', label);
  }

  Future<void> setFlexMinutes(int m) async {
    flexMinutes = m;
    notifyListeners();
    await _prefs.setInt('flexMinutes', m);
  }

  Future<void> setAi(AiProvider provider, String model, String key) async {
    aiProvider = provider;
    aiModel = model.trim();
    aiKey = key.trim();
    notifyListeners();
    await _prefs.setString('aiProvider', provider.name);
    await _prefs.setString('aiModel', aiModel);
    await _secure.write(key: 'aiKey', value: aiKey);
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
