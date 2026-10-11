import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

/// Free or cheap AI providers with OpenAI-compatible chat APIs. The teacher
/// can paste their own key in Settings if the app's server isn't set up.
enum AiProvider {
  gemini('Google Gemini (free tier)',
      'https://generativelanguage.googleapis.com/v1beta/openai', 'gemini-2.5-flash'),
  openRouter('OpenRouter (free DeepSeek & more)', 'https://openrouter.ai/api/v1',
      'deepseek/deepseek-chat-v3.1:free'),
  groq('Groq (free tier)', 'https://api.groq.com/openai/v1', 'llama-3.3-70b-versatile'),
  deepSeek('DeepSeek', 'https://api.deepseek.com', 'deepseek-chat');

  const AiProvider(this.label, this.baseUrl, this.defaultModel);

  final String label;
  final String baseUrl;
  final String defaultModel;
}

class AiNotConfigured implements Exception {}

class AiMessage {
  const AiMessage(this.role, this.content);

  final String role;
  final String content;

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class AiService {
  AiService({
    ApiClient? api,
    http.Client? client,
    this.provider = AiProvider.gemini,
    this.model = '',
    this.ownKey = '',
  })  : _api = api ?? ApiClient(),
        _http = client ?? http.Client();

  final ApiClient _api;
  final http.Client _http;
  final AiProvider provider;
  final String model;
  final String ownKey;

  /// The teacher's own key wins over the server, so they can try other models.
  bool get available => ownKey.isNotEmpty || _api.configured;

  Future<String> chat(List<AiMessage> messages) async {
    if (ownKey.isNotEmpty) return _direct(messages);
    if (_api.configured) {
      final r = await _api.post(
        '/v1/ai/chat',
        {'messages': messages.map((m) => m.toJson()).toList()},
        timeout: const Duration(seconds: 60),
      );
      return r['text'] as String? ?? '';
    }
    throw AiNotConfigured();
  }

  Future<String> _direct(List<AiMessage> messages) async {
    final res = await _http
        .post(
          Uri.parse('${provider.baseUrl}/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $ownKey',
          },
          body: jsonEncode({
            'model': model.isEmpty ? provider.defaultModel : model,
            'messages': messages.map((m) => m.toJson()).toList(),
            'max_tokens': 1500,
            'temperature': 0.4,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw ApiException(res.statusCode, res.body.length > 300 ? res.body.substring(0, 300) : res.body);
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    return ((choices.first as Map)['message'] as Map)['content'] as String? ?? '';
  }
}
