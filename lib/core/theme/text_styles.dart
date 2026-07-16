import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Sampada type system
/// Headings: Cinzel (serif, roman-inscribed feel)
/// Body:     Crimson Pro (humanist serif, legible)
/// Devanagari: Noto Serif Devanagari — wired as the family on the Devanagari
/// styles and as the fallback on every Latin style, since neither Cinzel nor
/// Crimson Pro carries Devanagari glyphs.
class AppTextStyles {
  AppTextStyles._();

  static final List<String> _devFallback = [
    GoogleFonts.notoSerifDevanagari().fontFamily!,
  ];

  static TextStyle _dv(TextStyle style) =>
      style.copyWith(fontFamilyFallback: _devFallback);

  // ── Cinzel (headings / labels) ────────────────────────────────────────────

  /// Screen / hero title — 26px Cinzel 600
  static TextStyle get display => _dv(GoogleFonts.cinzel(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorTextHeading,
        letterSpacing: 0.5,
      ));

  /// Card title, screen header — 20px Cinzel 500
  static TextStyle get title => _dv(GoogleFonts.cinzel(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorTextHeading,
      ));

  /// App bar / section heading — 18px Cinzel 500
  static TextStyle get titleMedium => _dv(GoogleFonts.cinzel(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorTextOnHeader,
      ));

  /// Section label, card sub-header — 14px Cinzel 500
  static TextStyle get sectionHead => _dv(GoogleFonts.cinzel(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorTextHeading,
      ));

  /// Badge / chip label — 10px Cinzel 600, tracked
  static TextStyle get label => _dv(GoogleFonts.cinzel(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorTextSecondary,
        letterSpacing: 1.5,
      ));

  /// Stat number (22px+) — Cinzel 600, WCAG-safe accent.
  /// Was gold kColorAccentLight at 2.35:1 — below even the 3:1 large-text
  /// floor. kColorAccentSafe keeps the heritage warmth at ~6.4:1.
  static TextStyle get statNumber => _dv(GoogleFonts.cinzel(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorAccentSafe,
      ));

  // ── Crimson Pro (body / UI) ───────────────────────────────────────────────

  /// Primary body — 15px Crimson Pro 400
  static TextStyle get body => _dv(GoogleFonts.crimsonPro(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.kColorTextBody,
        height: 1.55,
      ));

  /// Body medium weight — 15px Crimson Pro 500
  static TextStyle get bodyMedium => _dv(GoogleFonts.crimsonPro(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorTextBody,
      ));

  /// Body semibold — 15px Crimson Pro 600
  static TextStyle get bodySemiBold => _dv(GoogleFonts.crimsonPro(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorTextBody,
      ));

  /// Caption, metadata — 12px Crimson Pro 400
  static TextStyle get caption => _dv(GoogleFonts.crimsonPro(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.kColorTextSecondary,
      ));

  /// Timestamp, hint — 11px Crimson Pro 400
  static TextStyle get hint => _dv(GoogleFonts.crimsonPro(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.kColorTextMuted,
      ));

  /// Price / highlight — 15px Crimson Pro 600, accent-safe (WCAG AA)
  static TextStyle get price => _dv(GoogleFonts.crimsonPro(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorAccentSafe, // 4.52:1 — safe for all text sizes
      ));

  /// Nav label active — 11px, bold
  static TextStyle get navActive => _dv(GoogleFonts.crimsonPro(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.kColorNavActive,
      ));

  /// Nav label inactive — 11px, medium
  static TextStyle get navInactive => _dv(GoogleFonts.crimsonPro(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorNavInactive,
      ));

  /// Button label
  static TextStyle get button => _dv(GoogleFonts.crimsonPro(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorTextOnPrimary,
        letterSpacing: 0.3,
      ));

  /// Outlined button label
  static TextStyle get buttonOutlined => _dv(GoogleFonts.crimsonPro(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorPrimary,
        letterSpacing: 0.3,
      ));

  // ── Devanagari ────────────────────────────────────────────────────────────

  /// Nepali script — 18px Noto Serif Devanagari
  static TextStyle get devanagari => GoogleFonts.notoSerifDevanagari(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: AppColors.kColorTextBody,
      );

  /// Nepali caption — 13px Noto Serif Devanagari
  static TextStyle get devanagariCaption => GoogleFonts.notoSerifDevanagari(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.kColorTextSecondary,
      );
}
