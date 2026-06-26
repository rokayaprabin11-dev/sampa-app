import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// Sampada type system
/// Headings: Cinzel (serif, roman-inscribed feel)
/// Body:     Crimson Pro (humanist serif, legible)
/// Devanagari: System font (fallback to Noto Serif Devanagari)
class AppTextStyles {
  AppTextStyles._();

  // ── Cinzel (headings / labels) ────────────────────────────────────────────

  /// Screen / hero title — 26px Cinzel 600
  static TextStyle get display => GoogleFonts.cinzel(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorTextHeading,
        letterSpacing: 0.5,
      );

  /// Card title, screen header — 20px Cinzel 500
  static TextStyle get title => GoogleFonts.cinzel(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorTextHeading,
      );

  /// App bar / section heading — 18px Cinzel 500
  static TextStyle get titleMedium => GoogleFonts.cinzel(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorTextOnHeader,
      );

  /// Section label, card sub-header — 14px Cinzel 500
  static TextStyle get sectionHead => GoogleFonts.cinzel(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorTextHeading,
      );

  /// Badge / chip label — 10px Cinzel 600, tracked
  static TextStyle get label => GoogleFonts.cinzel(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorTextSecondary,
        letterSpacing: 1.5,
      );

  /// Stat number (22px+) — Cinzel 600, accent gold (ok at large size)
  static TextStyle get statNumber => GoogleFonts.cinzel(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorAccentLight, // large size only — 2.35:1 acceptable at 26px
      );

  // ── Crimson Pro (body / UI) ───────────────────────────────────────────────

  /// Primary body — 15px Crimson Pro 400
  static TextStyle get body => GoogleFonts.crimsonPro(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.kColorTextBody,
        height: 1.55,
      );

  /// Body medium weight — 15px Crimson Pro 500
  static TextStyle get bodyMedium => GoogleFonts.crimsonPro(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorTextBody,
      );

  /// Body semibold — 15px Crimson Pro 600
  static TextStyle get bodySemiBold => GoogleFonts.crimsonPro(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorTextBody,
      );

  /// Caption, metadata — 12px Crimson Pro 400
  static TextStyle get caption => GoogleFonts.crimsonPro(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.kColorTextSecondary,
      );

  /// Timestamp, hint — 11px Crimson Pro 400
  static TextStyle get hint => GoogleFonts.crimsonPro(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.kColorTextMuted,
      );

  /// Price / highlight — 15px Crimson Pro 600, accent-safe (WCAG AA)
  static TextStyle get price => GoogleFonts.crimsonPro(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorAccentSafe, // 4.52:1 — safe for all text sizes
      );

  /// Nav label active — 11px, bold
  static TextStyle get navActive => GoogleFonts.crimsonPro(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.kColorNavActive,
      );

  /// Nav label inactive — 11px, medium
  static TextStyle get navInactive => GoogleFonts.crimsonPro(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorNavInactive,
      );

  /// Button label
  static TextStyle get button => GoogleFonts.crimsonPro(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.kColorTextOnPrimary,
        letterSpacing: 0.3,
      );

  /// Outlined button label
  static TextStyle get buttonOutlined => GoogleFonts.crimsonPro(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.kColorPrimary,
        letterSpacing: 0.3,
      );

  // ── Devanagari ────────────────────────────────────────────────────────────

  /// Nepali script — 18px system font (Noto Serif Devanagari fallback)
  static const TextStyle devanagari = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    color: AppColors.kColorTextBody,
  );

  /// Nepali caption — 13px
  static const TextStyle devanagariCaption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.kColorTextSecondary,
  );
}
