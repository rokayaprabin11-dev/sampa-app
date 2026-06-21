import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/text_size_provider.dart';
import 'generated/app_localizations.dart';

import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/onboarding/onboarding_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/profile/profile_screen.dart';
import 'presentation/screens/profile/settings_screen.dart';
import 'presentation/screens/profile/account_settings_screen.dart';
import 'presentation/screens/profile/visit_history_screen.dart';
import 'presentation/screens/guides/become_guide_screen.dart';
import 'presentation/screens/downloads/downloads_screen.dart';
import 'presentation/screens/events/events_screen.dart';
import 'presentation/screens/map/map_placeholder_screen.dart';
import 'presentation/screens/guides/guide_screen.dart';
import 'presentation/screens/heritage/heritage_search_screen.dart';
import 'presentation/screens/bookmarks/saved_sites_screen.dart';
import 'presentation/screens/notifications/notifications_screen.dart';
import 'presentation/screens/heritage/heritage_site_screen.dart';
import 'presentation/screens/legal/policy_screen.dart';

class SampadaApp extends StatelessWidget {
  const SampadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final textSizeProvider = context.watch<TextSizeProvider>();

    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      locale: localeProvider.locale,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textSizeProvider.textScaleFactor),
          ),
          child: child!,
        );
      },
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), 
        Locale('ne'), 
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brownDark,
          brightness: Brightness.light,
          surface: AppColors.bgSurface,
          onSurface: AppColors.textPrimary,
        ),
        scaffoldBackgroundColor: AppColors.bgPage,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brownDark,
          brightness: Brightness.dark,
          surface: AppColors.darkBgSurface,
          onSurface: AppColors.darkTextPrimary,
          outline: AppColors.darkBorder,
        ),
        scaffoldBackgroundColor: AppColors.darkBgPage,
        cardTheme: const CardThemeData(
          color: AppColors.darkBgCard,
        ),
        useMaterial3: true,
      ),
      initialRoute: AppStrings.rootPath,
      routes: {
        AppStrings.rootPath: (context) => SplashScreen(
              currentPage: 1,
              totalPages: 3,
              onReady: () {
                Navigator.of(context).pushReplacementNamed(AppStrings.onboardingPath);
              },
            ),
        AppStrings.onboardingPath: (context) => const OnboardingScreen(),
        AppStrings.homePath: (context) => const HomeScreen(),
        AppStrings.loginPath: (context) => const LoginScreen(),
        AppStrings.registerPath: (context) => const RegisterScreen(),
        AppStrings.profilePath: (context) => const ProfileScreen(),
        AppStrings.settingsPath: (context) => const SettingsScreen(),
        AppStrings.accountSettingsPath: (context) => const AccountSettingsScreen(),
        AppStrings.becomeGuidePath: (context) => const BecomeGuideScreen(),
        AppStrings.downloadsPath: (context) => const DownloadsScreen(),
        AppStrings.eventsPath: (context) => const EventsScreen(),
        AppStrings.mapPath: (context) => const MapPlaceholderScreen(),
        AppStrings.guidePath: (context) => const GuideScreen(),
        AppStrings.searchPath: (context) => const HeritageSearchScreen(),
        AppStrings.savedSitesPath: (context) => const SavedSitesScreen(),
        AppStrings.visitHistoryPath: (context) => const VisitHistoryScreen(),
        AppStrings.notificationsPath: (context) => const NotificationsScreen(),
        AppStrings.heritageDetailsPath: (context) => const HeritageSiteScreen(),
        ...policyRoutes,
      },
    );
  }
}