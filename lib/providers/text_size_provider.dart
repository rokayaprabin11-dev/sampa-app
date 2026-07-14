import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sampada/generated/app_localizations.dart';

enum TextSize { small, medium, large }

/// In-app text-size preference, on top of the device font scale.
///
/// Persisted so it survives a restart. The factor is composed with — not
/// substituted for — the OS accessibility font scale in `app.dart`, so a user
/// who has enlarged system fonts still gets larger text here.
class TextSizeProvider with ChangeNotifier {
  static const _key = 'text_size';

  TextSize _textSize = TextSize.medium;

  TextSizeProvider() {
    _load();
  }

  TextSize get textSize => _textSize;

  double get textScaleFactor {
    switch (_textSize) {
      case TextSize.small:
        return 0.85;
      case TextSize.medium:
        return 1.0;
      case TextSize.large:
        return 1.2;
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null) {
        _textSize = TextSize.values.firstWhere(
          (s) => s.name == saved,
          orElse: () => TextSize.medium,
        );
        notifyListeners();
      }
    } catch (_) {
      // Keep the medium default.
    }
  }

  Future<void> setTextSize(TextSize size) async {
    _textSize = size;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, size.name);
    } catch (_) {}
  }

  String getTextSizeLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (_textSize) {
      case TextSize.small:
        return l10n.textSizeSmall;
      case TextSize.medium:
        return l10n.textSizeMedium;
      case TextSize.large:
        return l10n.textSizeLarge;
    }
  }
}
