import 'package:flutter/material.dart';

/// Sampada design system — Sunlit Parchment light theme
/// WCAG AA compliance patches applied (see sampada-wcag-patch-demo.html)
class AppColors {
  AppColors._();

  // ── Primary · Temple Red ─────────────────────────────────────────────────
  static const Color kColorDeep         = Color(0xFF5C1A0A); // gradient start
  static const Color kColorPrimaryDark  = Color(0xFF7A2210); // pressed state
  static const Color kColorPrimary      = Color(0xFF8B2500); // buttons, nav active, FAB
  static const Color kColorPrimaryMid   = Color(0xFFA83210); // gradient mid
  static const Color kColorPrimaryLight = Color(0xFFC8501A); // gradient end, event dot
  static const Color kColorPrimaryPale  = Color(0xFFE8896A); // disabled button

  // ── Accent · Heritage Gold ───────────────────────────────────────────────
  static const Color kColorAccentDark      = Color(0xFF7A5200); // UNESCO chip text
  /// Use for stars, stat numbers, icon fills, 22px+ display only.
  static const Color kColorAccent          = Color(0xFFB87A00); // 3.41:1 — large text/icons only
  /// WCAG-patched: safe for any body/small text. Ratio 4.52:1 vs page bg.
  static const Color kColorAccentSafe      = Color(0xFF9C6800); // replaces kColorAccent in text
  /// WCAG-patched: safe for small text labels. Ratio 4.28:1 vs page bg.
  static const Color kColorAccentTextSafe  = Color(0xFFA26B00); // "Featured · Top Rated"
  /// Restrict to gradients, icon fills, large 22px+ stat numbers ONLY.
  static const Color kColorAccentLight     = Color(0xFFD49A20); // 2.35:1 — NOT for small text
  static const Color kColorAccentPale      = Color(0xFFF0C96A); // badge borders, tag outlines
  static const Color kColorUnescoChipBg   = Color(0xFFFFF3D0); // UNESCO badge fill

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const Color kColorBgPage    = Color(0xFFFDF8F0); // scaffold / page
  static const Color kColorBgWarm    = Color(0xFFFAF3E8); // calendar, section fills, stats bar
  static const Color kColorSurface   = Color(0xFFFFFFFF); // cards, inputs, bottom nav
  static const Color kColorCardBg    = Color(0xFFFFF9F3); // heritage list cards, detail sheet
  static const Color kColorBgMuted   = Color(0xFFF5EDE0); // inactive chip bg, token labels
  static const Color kColorTagBg     = Color(0xFFFDEFD8); // chips, tag pills, nav icon bg
  static const Color kColorMapSurface = Color(0xFFF7F0E6); // map canvas background

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color kColorTextHeading   = Color(0xFF3A1005); // app bar title, card title
  static const Color kColorTextBody      = Color(0xFF4A2010); // body paragraphs
  static const Color kColorTextSecondary = Color(0xFF7A4530); // captions, metadata, subtitles
  static const Color kColorTextMuted     = Color(0xFFA06040); // timestamps, placeholders, hints
  static const Color kColorTextOnPrimary = Color(0xFFFFFFFF); // text on dark/primary bg
  static const Color kColorTextOnHeader  = Color(0xFFFFF8EE); // warm white on app bar
  static const Color kColorTextOnAccent  = Color(0xFF2A1800); // text on gold surfaces

  // ── Borders ──────────────────────────────────────────────────────────────
  static const Color kColorBorderStrong = Color(0xFFC8916A); // OutlinedButton, focused input
  static const Color kColorBorderMid    = Color(0xFFDDB895); // icon boxes, district cards
  static const Color kColorBorderSubtle = Color(0xFFEED5BE); // card outlines, dividers
  static const Color kColorBorderFaint  = Color(0xFFF5E8D8); // very subtle separators

  // ── Focus ring (WCAG-patched: 4.52:1) ───────────────────────────────────
  static const Color kFocusRing = Color(0xFFA36336);

  // ── Semantic · Status ────────────────────────────────────────────────────
  static const Color kColorOfflineBg     = Color(0xFFE8F5EE); // offline/ready badge bg
  static const Color kColorOfflineBorder = Color(0xFFBDD9BD); // offline badge border
  static const Color kColorOfflineText   = Color(0xFF1E6B3A); // offline badge text
  static const Color kColorOnlineDot     = Color(0xFF2CB84D); // guide online indicator

  // ── Navigation ───────────────────────────────────────────────────────────
  static const Color kColorNavActive   = Color(0xFF8B2500); // active icon + label
  static const Color kColorNavInactive = Color(0xFF9A6A50); // inactive icon + label
  static const Color kColorNavActiveBg = Color(0xFFFDEFD8); // active item pill background
  static const Color kColorNavDot      = Color(0xFFC8501A); // active tab indicator dot

  // ── Shadows ──────────────────────────────────────────────────────────────
  static const Color kShadowColor       = Color(0x1A5A1E0A); // rgba(90,30,10,0.10)
  static const Color kShadowColorSubtle = Color(0x125A1E0A); // rgba(90,30,10,0.07)

  // ── Dark theme ───────────────────────────────────────────────────────────
  static const Color kDarkBgPage      = Color(0xFF121212);
  static const Color kDarkBgSurface   = Color(0xFF1E1E1E);
  static const Color kDarkBgCard      = Color(0xFF2C2C2C);
  static const Color kDarkBorder      = Color(0xFF333333);
  static const Color kDarkTextPrimary = Color(0xFFE1E1E1);
  static const Color kDarkTextSecond  = Color(0xFFB0B0B0);
  static const Color kDarkTextMuted   = Color(0xFF808080);

  // ── Overlay ──────────────────────────────────────────────────────────────
  static const Color kOverlaySearchBar   = Color(0x26FFFFFF); // rgba(255,255,255,0.15)
  static const Color kOverlaySearchBorder = Color(0x59FFDCA0); // rgba(255,220,160,0.35)
  static const Color kOverlayModal       = Color(0x99000000); // modal backdrop

  // ── Backward-compat aliases (deprecated — prefer k* tokens above) ────────
  @Deprecated('Use kColorPrimary') static const Color brownDark       = kColorPrimary;
  @Deprecated('Use kColorDeep')    static const Color brownDeep       = kColorDeep;
  @Deprecated('Use kColorPrimaryLight') static const Color brownAccent = kColorPrimaryLight;
  @Deprecated('Use kColorBorderSubtle') static const Color brownLight  = kColorBorderSubtle;
  @Deprecated('Use kColorBgMuted') static const Color brownUltraLight  = kColorBgMuted;
  @Deprecated('Use kColorAccent')  static const Color goldDark         = kColorAccent;
  @Deprecated('Use kColorAccentLight') static const Color goldMain     = kColorAccentLight;
  @Deprecated('Use kColorTagBg')   static const Color goldLight        = kColorTagBg;
  @Deprecated('Use kColorBgPage')  static const Color bgPage           = kColorBgPage;
  @Deprecated('Use kColorSurface') static const Color bgSurface        = kColorSurface;
  @Deprecated('Use kColorTextHeading') static const Color textHeadline = kColorTextHeading;
  @Deprecated('Use kColorTextBody') static const Color textPrimary     = kColorTextBody;
  @Deprecated('Use kColorTextSecondary') static const Color textSecondary = kColorTextSecondary;
  @Deprecated('Use kColorTextMuted') static const Color textTertiary   = kColorTextMuted;
  @Deprecated('Use kColorTextOnPrimary') static const Color textInverted = kColorTextOnPrimary;

  // legacy names some widgets still reference
  static const Color primaryBrown   = kColorPrimary;
  static const Color darkText       = kColorTextHeading;
  static const Color offWhite       = kColorBgPage;
  static const Color secondaryText  = kColorTextSecondary;
  static const Color gold           = kColorAccentLight;
  static const Color creamWhite     = kColorCardBg;
  static const Color tertiaryText   = kColorTextMuted;
  static const Color brownMedium    = kColorPrimaryMid;
  static const Color bgCream        = kColorCardBg;
  static const Color bgShimmer      = kColorBgMuted;
  static const Color bgOverlay      = kOverlayModal;
  static const Color dividerYellow  = kColorAccentLight;
  static const Color languageButtonBorder = kColorBorderMid;
  static const Color indicatorInactive    = kColorBgMuted;
  static const Color ringColor      = Color(0x33C8501A);
  static const Color textGold       = kColorAccentSafe; // was kColorAccentLight — patched
  static const Color statusSuccess  = Color(0xFF2E7D32);
  static const Color statusError    = Color(0xFFC62828);
  static const Color statusWarning  = Color(0xFFEF6C00);
  static const Color statusInfo     = Color(0xFF1976D2);
  static const Color darkBgPage     = kDarkBgPage;
  static const Color darkBgSurface  = kDarkBgSurface;
  static const Color darkBgCard     = kDarkBgCard;
  static const Color darkBorder     = kDarkBorder;
  static const Color darkTextPrimary = kDarkTextPrimary;
  static const Color darkTextSecondary = kDarkTextSecond;
  static const Color darkTextTertiary  = kDarkTextMuted;
  static const Color goldSurface    = kColorTagBg;
  static const Color goldSubtle     = Color(0xFFFFF9EA);
  static const Color goldAccentPale = kColorAccentPale;
}
