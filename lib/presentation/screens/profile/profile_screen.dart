import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/presentation/widgets/profile_widgets.dart';
import 'package:sampada/providers/profile_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import 'package:sampada/core/providers/locale_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchStats();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final profileProvider = context.watch<ProfileProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final isNepali = localeProvider.locale.languageCode == 'ne';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Header Section ---
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Header Gradient
                Container(
                  height: size.height * 0.2, // Reduced from 0.25 to 0.2
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF5D1700), // Deep brownish-red
                        Color(0xFF9E3D1A), // Brighter orange-brown
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12), // Reduced vertical padding
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.profile, // "My Profile"
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24, // Slightly reduced font size
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings, color: Colors.white, size: 24),
                            onPressed: () {
                              Navigator.pushNamed(context, AppStrings.settingsPath);
                            },
                            tooltip: 'Settings',
                            hoverColor: Colors.white.withValues(alpha: 0.1),
                            splashColor: Colors.white.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Avatar
                Positioned(
                  bottom: -45, // Adjusted from -60 to -45 to match smaller header
                  child: Container(
                    width: 100, // Reduced from 120 to 100
                    height: 100, // Reduced from 120 to 100
                    decoration: BoxDecoration(
                      color: const Color(0xFFC89932), // Goldish color from image
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 70, // Reduced from 80 to 70
                      color: Color(0xFF7197C7), // Blue silhouette color
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 55), // Reduced from 70 to 55 to match smaller avatar/header

            // User Name & Email
            Text(
              user?.displayName ?? 'Prabin Rokaya',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? 'prabin@example.com',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextSecondary,
              ),
            ),

            const SizedBox(height: 32),

            // --- Stats Card ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppStrings.visitHistoryPath),
                      child: _buildStatItem(context, profileProvider.visitHistoryCount.toString(), l10n.visitHistory),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppStrings.savedSitesPath),
                      child: _buildStatItem(context, profileProvider.bookmarksCount.toString(), l10n.bookmarks),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppStrings.downloadsPath),
                      child: _buildStatItem(context, profileProvider.downloadsCount.toString(), l10n.manageDownloads),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // --- Recently Visited ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recently Visited',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC8851A), // Keep accent color consistent
                    ),
                  ),
                  const SizedBox(height: 16),
                  const RecentlyVisitedCard(
                    title: 'Pashupatinath Temple',
                    timeAgo: '2 days ago',
                    icon: Icons.temple_hindu,
                  ),
                  const RecentlyVisitedCard(
                    title: 'Boudhanath Stupa',
                    timeAgo: '1 week ago',
                    icon: Icons.temple_buddhist,
                  ),
                  const RecentlyVisitedCard(
                    title: '55-Window Palace',
                    timeAgo: '2 weeks ago',
                    icon: Icons.castle,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // --- Account Section ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFC8851A),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Language Toggle Tile
                  _buildAccountTile(
                    context,
                    icon: Icons.language, // Replace with appropriate icon if needed
                    title: l10n.language,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Eng', style: TextStyle(fontSize: 14, color: Color(0xFF8C7162))),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 30,
                          width: 50,
                          child: Switch(
                            value: isNepali,
                            onChanged: (val) {
                              localeProvider.setLocale(Locale(val ? 'ne' : 'en'));
                            },
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF3DA35D), // Green from image
                            inactiveThumbColor: Colors.white,
                            inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Nep', style: TextStyle(fontSize: 14, color: Color(0xFF8C7162))),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Saved Sites (Bookmarks) Tile
                  _buildAccountTile(
                    context,
                    icon: Icons.bookmark_border_rounded,
                    title: l10n.bookmarks,
                    trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF8C7162)),
                    onTap: () => Navigator.pushNamed(context, AppStrings.savedSitesPath),
                  ),

                  const SizedBox(height: 12),

                  // Downloads Tile
                  _buildAccountTile(
                    context,
                    icon: Icons.file_download_outlined,
                    title: l10n.manageDownloads,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${profileProvider.downloadsCount} files", style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF4A342B) : AppColors.darkTextSecondary)),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, size: 20, color: Color(0xFF8C7162)),
                      ],
                    ),
                    onTap: () => Navigator.pushNamed(context, AppStrings.downloadsPath),
                  ),

                  const SizedBox(height: 12),

                  // Be a Guide Tile
                  _buildAccountTile(
                    context,
                    icon: Icons.file_download_outlined, // Matching image placeholder
                    title: 'Be a Guide',
                    trailing: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF8C7162)),
                    onTap: () => Navigator.pushNamed(context, AppStrings.becomeGuidePath),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  Widget _buildStatItem(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC8851A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAccountTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder),
        ),
        child: Row(
          children: [
            // Icon Background - Circular dark brown as in image
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF3A241C) : AppColors.darkBgCard,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Theme.of(context).brightness == Brightness.light ? Colors.white : AppColors.goldMain, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}







