import 'package:flutter/material.dart';

class AppColors {
  // Prevent instantiation
  AppColors._();

  // --- Brown / Earth Palette ---
  static const Color brownDeep = Color(0xFF3A0A00);
  static const Color brownDark = Color(0xFF7B1E00);
  static const Color brownMedium = Color(0xFF993214);
  static const Color brownAccent = Color(0xFFD4520A);
  static const Color brownLight = Color(0xFFE2D6CE);
  static const Color brownUltraLight = Color(0xFFF5EFEC);

  // --- Gold / Accent Palette ---
  static const Color goldDark = Color(0xFFB48325);
  static const Color goldMain = Color(0xFFDCA73A);
  static const Color goldLight = Color(0xFFF7EED3);
  static const Color goldSurface = Color(0xFFFDF8E8);
  static const Color goldSubtle = Color(0xFFFFF9EA);

  // --- Backgrounds & Surfaces ---
  static const Color bgPage = Color(0xFFFBF9F6);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgCream = Color(0xFFF5E8D0);
  static const Color bgOverlay = Color(0x1A000000);
  static const Color bgShimmer = Color(0xFFF0F0F0);

  // --- Dark Theme Palette ---
  static const Color darkBgPage = Color(0xFF121212);
  static const Color darkBgSurface = Color(0xFF1E1E1E);
  static const Color darkBgCard = Color(0xFF2C2C2C);
  static const Color darkBorder = Color(0xFF333333);
  static const Color darkTextPrimary = Color(0xFFE1E1E1);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkTextTertiary = Color(0xFF808080);

  // --- Text Palette ---
  static const Color textHeadline = Color(0xFF331609);
  static const Color textPrimary = Color(0xFF4A342B);
  static const Color textSecondary = Color(0xFF6B5041);
  static const Color textTertiary = Color(0xFF8C7162);
  static const Color textInverted = Color(0xFFFFFFFF);
  static const Color textGold = Color(0xFFDCA73A);

  // --- Semantic & Status ---
  static const Color statusSuccess = Color(0xFF2E7D32);
  static const Color statusError = Color(0xFFC62828);
  static const Color statusWarning = Color(0xFFEF6C00);
  static const Color statusInfo = Color(0xFF1976D2);

  // --- Legacy / Compatibility Mapping (Deprecated - use specific tokens above) ---
  static const Color primaryBrown = brownAccent; // Updated to match vibrant action color
  static const Color darkText = textHeadline;
  static const Color offWhite = bgPage;
  static const Color secondaryText = textSecondary;
  static const Color gold = goldMain;
  static const Color darkBrown = brownDeep;
  static const Color midBrown = brownDark;
  static const Color orange = brownAccent;
  static const Color lightGold = goldLight;
  static const Color creamWhite = bgCream;
  static const Color ringColor = Color(0x33C8851A);
  static const Color dividerYellow = goldMain;
  static const Color tertiaryText = textTertiary;
  static const Color languageButtonBorder = brownLight;
  static const Color indicatorInactive = brownUltraLight;
}







