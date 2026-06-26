import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _buildLight();
  static ThemeData get dark  => _buildDark();

  static ThemeData _buildLight() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.kColorBgPage,
      colorScheme: const ColorScheme.light(
        primary:          AppColors.kColorPrimary,
        onPrimary:        AppColors.kColorTextOnPrimary,
        primaryContainer: AppColors.kColorBgMuted,
        secondary:        AppColors.kColorAccentSafe,
        onSecondary:      AppColors.kColorTextOnPrimary,
        surface:          AppColors.kColorSurface,
        onSurface:        AppColors.kColorTextBody,
        surfaceContainerHighest: AppColors.kColorBgWarm,
        outline:          AppColors.kColorBorderMid,
        outlineVariant:   AppColors.kColorBorderSubtle,
        error:            Color(0xFFC62828),
        onError:          AppColors.kColorTextOnPrimary,
        shadow:           AppColors.kShadowColor,
      ),
      textTheme: GoogleFonts.crimsonProTextTheme(base.textTheme).copyWith(
        displayLarge:  GoogleFonts.cinzel(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.kColorTextHeading),
        displayMedium: GoogleFonts.cinzel(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.kColorTextHeading),
        titleLarge:    GoogleFonts.cinzel(fontSize: 20, fontWeight: FontWeight.w500, color: AppColors.kColorTextHeading),
        titleMedium:   GoogleFonts.cinzel(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.kColorTextHeading),
        titleSmall:    GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.kColorTextHeading),
        bodyLarge:     GoogleFonts.crimsonPro(fontSize: 16, color: AppColors.kColorTextBody),
        bodyMedium:    GoogleFonts.crimsonPro(fontSize: 15, color: AppColors.kColorTextBody),
        bodySmall:     GoogleFonts.crimsonPro(fontSize: 13, color: AppColors.kColorTextSecondary),
        labelLarge:    GoogleFonts.crimsonPro(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.kColorTextOnPrimary),
        labelSmall:    GoogleFonts.cinzel(fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.5, color: AppColors.kColorTextSecondary),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.kColorPrimary,
        foregroundColor: AppColors.kColorTextOnHeader,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.cinzel(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.kColorTextOnHeader,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: AppColors.kColorTextOnHeader),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.kColorPrimary,
          foregroundColor: AppColors.kColorTextOnPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
          ),
          textStyle: GoogleFonts.crimsonPro(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.kColorPrimary,
          side: const BorderSide(color: AppColors.kColorBorderStrong, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
          ),
          textStyle: GoogleFonts.crimsonPro(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.3),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.kColorPrimary,
          textStyle: GoogleFonts.crimsonPro(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.kColorSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
          borderSide: const BorderSide(color: AppColors.kColorBorderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
          borderSide: const BorderSide(color: AppColors.kColorBorderMid),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
          borderSide: const BorderSide(color: AppColors.kFocusRing, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
          borderSide: const BorderSide(color: Color(0xFFC62828)),
        ),
        hintStyle: GoogleFonts.crimsonPro(fontSize: 14, color: AppColors.kColorTextMuted),
        labelStyle: GoogleFonts.crimsonPro(fontSize: 14, color: AppColors.kColorTextSecondary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.kColorBgMuted,
        selectedColor: AppColors.kColorPrimary,
        labelStyle: GoogleFonts.crimsonPro(fontSize: 12, color: AppColors.kColorTextSecondary),
        side: const BorderSide(color: AppColors.kColorBorderMid),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      cardTheme: CardThemeData(
        color: AppColors.kColorCardBg,
        elevation: 0,
        shadowColor: AppColors.kShadowColorSubtle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
          side: const BorderSide(color: AppColors.kColorBorderSubtle),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.kColorBorderSubtle,
        space: 1,
        thickness: 1,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.kColorSurface,
        selectedItemColor: AppColors.kColorNavActive,
        unselectedItemColor: AppColors.kColorNavInactive,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.kColorPrimary,
        foregroundColor: AppColors.kColorTextOnPrimary,
        elevation: 4,
        shape: StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.kColorTextHeading,
        contentTextStyle: GoogleFonts.crimsonPro(fontSize: 14, color: AppColors.kColorTextOnPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData _buildDark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.kDarkBgPage,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.kColorPrimaryLight,
        onPrimary: AppColors.kColorTextOnPrimary,
        secondary: AppColors.kColorAccentLight,
        surface:   AppColors.kDarkBgSurface,
        onSurface: AppColors.kDarkTextPrimary,
        outline:   AppColors.kDarkBorder,
        error:     Color(0xFFEF5350),
      ),
      textTheme: GoogleFonts.crimsonProTextTheme(base.textTheme),
      cardTheme: CardThemeData(
        color: AppColors.kDarkBgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
          side: const BorderSide(color: AppColors.kDarkBorder),
        ),
      ),
    );
  }

  // ── Gradient helpers ──────────────────────────────────────────────────────

  /// Hero header: Home, Detail, District screens
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    transform: GradientRotation(2.79), // ~160deg
    colors: [AppColors.kColorDeep, AppColors.kColorPrimary, AppColors.kColorPrimaryLight],
    stops: [0.0, 0.4, 1.0],
  );

  /// Navigation header: Map, Events, Settings screens
  static const LinearGradient navGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    transform: GradientRotation(2.79),
    colors: [AppColors.kColorDeep, AppColors.kColorPrimary, AppColors.kColorPrimaryMid],
    stops: [0.0, 0.5, 1.0],
  );

  /// Warm content section: Calendar, Downloads
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.kColorBgWarm, AppColors.kColorCardBg],
  );

  /// Card image placeholder gradient
  static const LinearGradient cardImageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.kColorPrimary, AppColors.kColorPrimaryLight, AppColors.kColorAccentLight],
    stops: [0.0, 0.6, 1.0],
  );

  /// Storage / progress bar fill
  static const LinearGradient progressGradient = LinearGradient(
    colors: [AppColors.kColorPrimary, AppColors.kColorAccentLight],
  );

  /// Avatar / saved icon background
  static const LinearGradient avatarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.kColorPrimary, AppColors.kColorPrimaryLight],
  );

  // ── Shadow presets ────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    const BoxShadow(color: AppColors.kShadowColorSubtle, blurRadius: 6, offset: Offset(0, 1)),
  ];

  static List<BoxShadow> get elevatedShadow => [
    const BoxShadow(color: AppColors.kShadowColor, blurRadius: 12, offset: Offset(0, 2)),
  ];
}
