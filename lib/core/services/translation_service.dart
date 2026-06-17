import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_endpoints.dart';
import 'package:sampada/core/network/network_exceptions.dart';

/// Translates text on-the-fly via the Sampada backend (/api/translate/).
///
/// Usage (after injection):
///   final ne = await translationService.translate('Hello', to: 'ne');
///   final list = await translationService.translateBatch(['Hello', 'World'], to: 'ne');
class TranslationService {
  TranslationService({required this.apiClient});

  final ApiClient apiClient;

  // Simple in-memory cache: "source|target|text" → translated string
  final Map<String, String> _cache = {};
  static const int _maxCache = 500;

  String _key(String text, String source, String target) =>
      '$source|$target|$text';

  // ---------------------------------------------------------------------------
  // Translate a single string
  // ---------------------------------------------------------------------------
  Future<String> translate(
    String text, {
    String source = 'auto',
    String target = 'ne',
  }) async {
    if (text.trim().isEmpty || source == target) return text;

    final k = _key(text, source, target);
    if (_cache.containsKey(k)) return _cache[k]!;

    final results = await translateBatch([text], source: source, target: target);
    return results.isNotEmpty ? results.first : text;
  }

  // ---------------------------------------------------------------------------
  // Translate a list of strings in one network call
  // ---------------------------------------------------------------------------
  Future<List<String>> translateBatch(
    List<String> texts, {
    String source = 'auto',
    String target = 'ne',
  }) async {
    if (texts.isEmpty) return [];

    // Split into cached vs. uncached
    final uncachedIndices = <int>[];
    final output = List<String>.from(texts);

    for (int i = 0; i < texts.length; i++) {
      final k = _key(texts[i], source, target);
      if (_cache.containsKey(k)) {
        output[i] = _cache[k]!;
      } else {
        uncachedIndices.add(i);
      }
    }

    if (uncachedIndices.isEmpty) return output;

    final uncachedTexts = uncachedIndices.map((i) => texts[i]).toList();

    try {
      final data = await apiClient.post(
        ApiEndpoints.translate,
        data: {
          'texts': uncachedTexts,
          'source': source,
          'target': target,
        },
      ) as Map<String, dynamic>;

      final translated = List<String>.from(data['translations'] as List);

      for (int j = 0; j < uncachedIndices.length; j++) {
        final i = uncachedIndices[j];
        final result = j < translated.length ? translated[j] : texts[i];
        output[i] = result;

        final k = _key(texts[i], source, target);
        if (_cache.length >= _maxCache) {
          _cache.remove(_cache.keys.first);
        }
        _cache[k] = result;
      }
    } on ServerException {
      // Network or server failure — return originals silently
    }

    return output;
  }

  // ---------------------------------------------------------------------------
  // Convenience: translate both name and description in one call
  // ---------------------------------------------------------------------------
  Future<Map<String, String>> translateContentFields({
    required String nameEn,
    required String descriptionEn,
    String target = 'ne',
  }) async {
    final results = await translateBatch(
      [nameEn, descriptionEn],
      source: 'en',
      target: target,
    );
    return {
      'name': results[0],
      'description': results[1],
    };
  }

  void clearCache() => _cache.clear();
}
