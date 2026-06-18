import 'package:flutter/material.dart';

enum TextSize { small, medium, large }

class TextSizeProvider with ChangeNotifier {
  TextSize _textSize = TextSize.medium;

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

  String getTextSizeLabel(BuildContext context) {
    // Note: You can add these to l10n later
    switch (_textSize) {
      case TextSize.small:
        return 'Small';
      case TextSize.medium:
        return 'Medium';
      case TextSize.large:
        return 'Large';
    }
  }

  void setTextSize(TextSize size) {
    _textSize = size;
    notifyListeners();
  }
}