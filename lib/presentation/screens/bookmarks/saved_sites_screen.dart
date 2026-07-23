import 'package:flutter/material.dart';
import 'package:sampada/presentation/widgets/common/interactive_surface.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/providers/profile_provider.dart';
import 'package:sampada/presentation/widgets/shared/loading_states.dart';

class SavedSitesScreen extends StatefulWidget {
  const SavedSitesScreen({super.key});

  @override
  State<SavedSitesScreen> createState() => _SavedSitesScreenState();
}

class _SavedSitesScreenState extends State<SavedSitesScreen> {
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final profileProvider = context.watch<ProfileProvider>();
    final bookmarks = profileProvider.bookmarks;

    // Filter by category if not 'All'
    final filteredBookmarks = _selectedCategory == 'All'
        ? bookmarks
        : bookmarks
            .where((s) =>
                s.category.toLowerCase() == _selectedCategory.toLowerCase())
            .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // --- Header Section ---
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppTheme.heroGradient,
              image: AppTheme.headerIllustration,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
                bottomRight: Radius.circular(AppDimensions.kRadiusXxl),
              ),
            ),
            // Sizes to its content instead of a fixed screen-height fraction.
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(
                            foregroundColor: AppColors.kColorTextOnHeader,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.14),
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(Icons.arrow_back,
                              size: AppDimensions.iconMd),
                          onPressed: () => Navigator.pop(context),
                          hoverColor: Colors.white.withValues(alpha: 0.1),
                          splashColor: Colors.white.withValues(alpha: 0.2),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.bookmarks,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppColors.kColorTextOnHeader,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              '${profileProvider.bookmarksCount} bookmarked heritage sites',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Categories ---
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildCategoryChip(context, l10n.catAll,
                    isSelected: _selectedCategory == 'All'),
                _buildCategoryChip(context, l10n.catTemple,
                    isSelected: _selectedCategory == 'Temples'),
                _buildCategoryChip(context, l10n.catStupa,
                    isSelected: _selectedCategory == 'Stupas'),
                _buildCategoryChip(context, l10n.catPalace,
                    isSelected: _selectedCategory == 'Palaces'),
              ],
            ),
          ),

          // --- Results List ---
          Expanded(
            child: profileProvider.isLoading
                ? const LoadingSkeletonList(itemCount: 4)
                : filteredBookmarks.isEmpty
                    ? Center(child: Text(l10n.emptyBookmarks))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: filteredBookmarks.length,
                        itemBuilder: (context, index) {
                          final site = filteredBookmarks[index];
                          return _SavedSiteCard(
                            name: site.name,
                            location: site.location,
                            type: site.category,
                            icon: _getIconForCategory(site.category),
                            imageUrl: site.imageUrl,
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppStrings.heritageDetailsPath,
                                arguments: site,
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'temple':
        return Icons.temple_hindu;
      case 'stupa':
        return Icons.temple_buddhist;
      case 'palace':
        return Icons.castle;
      default:
        return Icons.account_balance;
    }
  }

  Widget _buildCategoryChip(BuildContext context, String label,
      {bool isSelected = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isSelected
        ? AppColors.kColorTextOnPrimary
        : (isDark ? AppColors.kDarkTextPrimary : AppColors.kColorTextSecondary);
    return InteractiveSurface(
      onTap: () => setState(() => _selectedCategory = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.kColorAccentLight : AppColors.kColorPrimary)
              : (isDark ? AppColors.kDarkBgSurface : AppColors.kColorSurface),
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
          border: Border.all(
              color: isSelected
                  ? (isDark
                      ? AppColors.kColorAccentLight
                      : AppColors.kColorPrimary)
                  : (isDark
                      ? AppColors.kDarkBorder
                      : AppColors.kColorBorderMid)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _SavedSiteCard extends StatelessWidget {
  final String name;
  final String location;
  final String type;
  final IconData icon;
  final String? imageUrl;
  final VoidCallback onTap;

  const _SavedSiteCard({
    required this.name,
    required this.location,
    required this.type,
    required this.icon,
    this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = Theme.of(context).textTheme;
    return InteractiveSurface(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(
              color: Theme.of(context).brightness == Brightness.light
                  ? AppColors.kColorBorderCream
                  : AppColors.darkBorder),
        ),
        child: Row(
          children: [
            // Left Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDimensions.kRadiusXxl),
                bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
              ),
              child: SizedBox(
                width: 100,
                height: 100,
                child: hasImage
                    ? AppNetworkImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: _iconFallback(icon))
                    : _iconFallback(icon),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Icon(Icons.bookmark,
                            color: isDark
                                ? AppColors.kColorAccentLight
                                : AppColors.kColorPrimary,
                            size: AppDimensions.iconLg),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: AppDimensions.iconSm,
                            color: isDark
                                ? AppColors.kDarkTextMuted
                                : AppColors.kColorTextMuted),
                        const SizedBox(width: 4),
                        Text(location,
                            style: t.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.kDarkTextMuted
                                  : AppColors.kColorTextMuted,
                            )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.kColorAccentLight
                                .withValues(alpha: 0.20)
                            : AppColors.kColorTagBg,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.kRadiusSm),
                      ),
                      child: Text(
                        type,
                        style: t.labelSmall?.copyWith(
                          color: isDark
                              ? AppColors.kColorAccentLight
                              : AppColors.kColorAccentSafe,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconFallback(IconData icon) => Container(
        decoration: const BoxDecoration(gradient: AppTheme.cardImageGradient),
        child: Center(
            child: Icon(icon,
                color: AppColors.kColorTextOnPrimary.withValues(alpha: 0.8),
                size: 40)),
      );
}
