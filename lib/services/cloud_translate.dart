import 'dart:convert';
import 'package:http/http.dart' as http;

/// Google Cloud Translation v2 client using an API key.
/// NOTE: Do NOT send "source":"auto". Omit the field to auto-detect.
class CloudTranslatorService {
  final String apiKey;
  CloudTranslatorService(this.apiKey);

  Future<String> translate(
    String text, {
    required String target, // e.g., 'hi'
    String source = 'auto', // omit if 'auto'
    bool html = false,
  }) async {
    final url = Uri.parse(
      'https://translation.googleapis.com/language/translate/v2?key=$apiKey',
    );

    // Build the body WITHOUT 'source' when auto-detecting
    final Map<String, dynamic> body = {
      'q': text,
      'target': target,
      'format': html ? 'html' : 'text',
    };
    if (source.isNotEmpty && source.toLowerCase() != 'auto') {
      body['source'] = source;
    }

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return (data['data']['translations'][0]['translatedText'] as String?) ??
          '';
    }
    throw Exception('Translate failed: ${resp.statusCode} ${resp.body}');
  }

  Future<List<String>> translateBatch(
    List<String> texts, {
    required String target,
    String source = 'auto',
    bool html = false,
  }) async {
    final url = Uri.parse(
      'https://translation.googleapis.com/language/translate/v2?key=$apiKey',
    );

    final Map<String, dynamic> body = {
      'q': texts,
      'target': target,
      'format': html ? 'html' : 'text',
    };
    if (source.isNotEmpty && source.toLowerCase() != 'auto') {
      body['source'] = source;
    }

    final resp = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final items = data['data']['translations'] as List<dynamic>;
      return items.map((e) => (e['translatedText'] as String?) ?? '').toList();
    }
    throw Exception('Translate batch failed: ${resp.statusCode} ${resp.body}');
  }
}
