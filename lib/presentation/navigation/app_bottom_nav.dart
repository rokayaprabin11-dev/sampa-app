import 'package:flutter/material.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/generated/app_localizations.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
  });

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    String? routeName;
    switch (index) {
      case 0:
        routeName = AppStrings.homePath;
        break;
      case 1:
        routeName = AppStrings.mapPath;
        break;
      case 2:
        routeName = AppStrings.guidePath;
        break;
      case 3:
        routeName = AppStrings.eventsPath;
        break;
      case 4:
        routeName = AppStrings.profilePath;
        break;
    }

    if (routeName != null) {
      Navigator.pushReplacementNamed(context, routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).brightness == Brightness.light ? Colors.grey.withValues(alpha: 0.1) : Colors.white10,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(context, 0, Icons.home_rounded, l10n.navHome),
                  _buildNavItem(context, 1, Icons.map_rounded, l10n.navMap),
                  _buildNavItem(context, 2, Icons.explore_rounded, l10n.navGuide),
                  _buildNavItem(context, 3, Icons.event_rounded, l10n.navEvents),
                  _buildNavItem(context, 4, Icons.person_rounded, l10n.navProfile),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final color = isSelected ? AppColors.kColorNavActive : AppColors.kColorNavInactive;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(context, index),
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          splashColor: AppColors.kColorNavActive.withValues(alpha: 0.05),
          highlightColor: AppColors.kColorNavActive.withValues(alpha: 0.02),
          hoverColor: AppColors.kColorNavActive.withValues(alpha: 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.kColorNavActiveBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}







