import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/presentation/widgets/profile_widgets.dart';
import 'package:sampada/core/providers/locale_provider.dart';
import 'package:sampada/core/providers/theme_provider.dart';
import 'package:sampada/core/providers/text_size_provider.dart';
import 'package:sampada/core/providers/auto_sync_provider.dart';
import 'package:sampada/providers/profile_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _pushNotifications = true;
  bool _nearbySiteAlerts = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider = context.read<ProfileProvider>();
      profileProvider.fetchStats();
      profileProvider.calculateCacheSize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localeProvider = context.watch<LocaleProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final textSizeProvider = context.watch<TextSizeProvider>();
    final autoSyncProvider = context.watch<AutoSyncProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final isNepali = localeProvider.locale.languageCode == 'ne';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // --- Header Section ---
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5C1A0A),
                  Color(0xFFA83210),
                  Color(0xFFC8501A),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
                bottomRight: Radius.circular(AppDimensions.kRadiusXxl),
              ),
            ),
            // Sizes to its content instead of a fixed screen-height fraction, so
            // it never clips on short devices or leaves dead space on tall ones.
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                      hoverColor: Colors.white.withValues(alpha: 0.1),
                      splashColor: Colors.white.withValues(alpha: 0.2),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.settings_outlined, color: Color(0xFFB0B0B0), size: 24),
                  ],
                ),
              ),
            ),
          ),

          // --- Scrollable Content ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- General ---
                  _buildSectionTitle(context, 'General'),
                  SettingsSwitchTile(
                    title: l10n.language,
                    icon: Icons.language,
                    value: isNepali,
                    onChanged: (val) {
                      localeProvider.setLocale(Locale(val ? 'ne' : 'en'));
                    },
                    leftLabel: 'Eng',
                    rightLabel: 'Nep',
                  ),
                  SettingsSwitchTile(
                    title: l10n.theme,
                    icon: Icons.palette_outlined,
                    value: themeProvider.isDarkMode,
                    onChanged: (val) {
                      themeProvider.toggleTheme(val);
                    },
                    leftLabel: 'Light',
                    rightLabel: 'Dark',
                  ),
                  SettingsNavigationTile(
                    title: l10n.textSize,
                    icon: Icons.text_fields,
                    trailingText: textSizeProvider.getTextSizeLabel(context),
                    onTap: () {},
                  ),

                  const SizedBox(height: 16),
                  // --- Account Settings ---
                  _buildSectionTitle(context, 'Account Settings'),
                  SettingsNavigationTile(
                    title: 'Settings',
                    icon: Icons.manage_accounts_outlined,
                    onTap: () {
                      Navigator.pushNamed(context, AppStrings.accountSettingsPath);
                    },
                  ),

                  const SizedBox(height: 16),
                  // --- Notifications ---
                  _buildSectionTitle(context, 'Notifications'),
                  SettingsSwitchTile(
                    title: 'Push Notifications',
                    icon: Icons.notifications_none,
                    value: _pushNotifications,
                    onChanged: (val) => setState(() => _pushNotifications = val),
                  ),
                  SettingsSwitchTile(
                    title: 'Nearby Site Alerts',
                    icon: Icons.location_on_outlined,
                    value: _nearbySiteAlerts,
                    onChanged: (val) => setState(() => _nearbySiteAlerts = val),
                  ),

                  const SizedBox(height: 16),
                  // --- Data & Storage ---
                  _buildSectionTitle(context, 'Data & Storage'),
                  SettingsNavigationTile(
                    title: l10n.autoSync,
                    icon: Icons.sync,
                    trailingText: autoSyncProvider.getSyncModeLabel(context),
                    onTap: () => _showAutoSyncOptions(context, autoSyncProvider),
                  ),
                  SettingsNavigationTile(
                    title: l10n.clearCache,
                    icon: Icons.delete_outline,
                    trailingText: '${profileProvider.cacheSizeMB.toStringAsFixed(1)} MB',
                    onTap: () => profileProvider.clearLocalCache(),
                  ),
                  SettingsNavigationTile(
                    title: l10n.aboutSampada,
                    icon: Icons.info_outline,
                    onTap: () {},
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Legal'),
                  SettingsNavigationTile(
                    title: 'Privacy Policy',
                    icon: Icons.privacy_tip_outlined,
                    onTap: () => Navigator.pushNamed(context, AppStrings.privacyPolicyPath),
                  ),
                  SettingsNavigationTile(
                    title: 'Terms & Conditions',
                    icon: Icons.description_outlined,
                    onTap: () => Navigator.pushNamed(context, AppStrings.termsPath),
                  ),
                  SettingsNavigationTile(
                    title: 'Community Guidelines',
                    icon: Icons.people_outline,
                    onTap: () => Navigator.pushNamed(context, AppStrings.communityPolicyPath),
                  ),
                  SettingsNavigationTile(
                    title: 'Disclaimer',
                    icon: Icons.warning_amber_outlined,
                    onTap: () => Navigator.pushNamed(context, AppStrings.disclaimerPath),
                  ),
                  SettingsNavigationTile(
                    title: 'Copyright Policy',
                    icon: Icons.copyright_outlined,
                    onTap: () => Navigator.pushNamed(context, AppStrings.copyrightPolicyPath),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF4A342B) : AppColors.goldMain,
        ),
      ),
    );
  }

  void _showAutoSyncOptions(BuildContext context, AutoSyncProvider provider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.kRadiusXxl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Auto Sync',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.sync),
                title: const Text('On'),
                onTap: () {
                  provider.setSyncMode(AutoSyncMode.dataAndWifi);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.wifi),
                title: const Text('Wi-Fi Only'),
                onTap: () {
                  provider.setSyncMode(AutoSyncMode.wifiOnly);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync_disabled),
                title: const Text('Off'),
                onTap: () {
                  provider.setSyncMode(AutoSyncMode.off);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
