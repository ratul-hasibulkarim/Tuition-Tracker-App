import 'dart:convert';

import 'package:http/http.dart' as http;

/// Address of the Tuition Tracker server (see `server/`), passed at build time:
/// `--dart-define=API_BASE_URL=https://... --dart-define=APP_TOKEN=...`
const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const appToken = String.fromEnvironment('APP_TOKEN');

class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => 'ApiException($status): $message';
}

/// Calls the server that holds the Maps and AI keys.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl, String? token})
      : _http = client ?? http.Client(),
        _base = (baseUrl ?? apiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _token = token ?? appToken;

  final http.Client _http;
  final String _base;
  final String _token;

  bool get configured => _base.isNotEmpty;

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
      {Duration timeout = const Duration(seconds: 20)}) async {
    if (!configured) throw ApiException(0, 'Server not configured');
    final res = await _http
        .post(
          Uri.parse('$_base$path'),
          headers: {'Content-Type': 'application/json', 'X-App-Token': _token},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode,
          data is Map ? '${data['error'] ?? res.reasonPhrase}' : '${res.reasonPhrase}');
    }
    return data as Map<String, dynamic>;
  }
}
