import 'package:sampada/core/database/database_helper.dart';
import 'package:sampada/core/services/translation_service.dart';

/// Handles translation of user-facing content (site descriptions, reviews).
///
/// UI strings are localized via ARB/AppLocalizations.
/// Only user content (heritage site descriptions and review text) goes through
/// Google Translate via [TranslationService].
class ContentTranslator {
  ContentTranslator({
    required this.translationService,
    required this.dbHelper,
  });

  final TranslationService translationService;
  final DatabaseHelper dbHelper;

  /// Translates a heritage site's short + long descriptions into [targetLang]
  /// and writes the translated fields back to the local_heritage_sites SQLite row.
  ///
  /// No-op when [targetLang] is 'en' or both description fields are empty.
  Future<void> translateAndCacheSiteDescriptions({
    required String siteId,
    required String shortDescEn,
    required String descriptionEn,
    required String targetLang,
  }) async {
    if (targetLang == 'en') return;
    if (shortDescEn.isEmpty && descriptionEn.isEmpty) return;

    final results = await translationService.translateBatch(
      [shortDescEn, descriptionEn],
      source: 'en',
      target: targetLang,
    );

    final db = await dbHelper.database;
    await db.update(
      'local_heritage_sites',
      {
        'short_desc_ne': results[0],
        'description_ne': results[1],
      },
      where: 'id = ?',
      whereArgs: [siteId],
    );
  }

  /// Translates a single user comment/review on demand.
  ///
  /// The result is NOT persisted — it is ephemeral and shown in the UI only.
  Future<String> translateReview(
    String commentText, {
    String targetLang = 'en',
  }) {
    return translationService.translate(
      commentText,
      source: 'auto',
      target: targetLang,
    );
  }
}
