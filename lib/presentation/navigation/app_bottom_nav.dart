import 'package:flutter/material.dart';
import 'package:sampada/core/constants/app_strings.dart';

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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, Icons.home_rounded, 'Home'),
              _buildNavItem(context, 1, Icons.map_rounded, 'Map'),
              _buildNavItem(context, 2, Icons.explore_rounded, 'Guide'),
              _buildNavItem(context, 3, Icons.event_rounded, 'Events'),
              _buildNavItem(context, 4, Icons.person_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = currentIndex == index;
    final color = isSelected ? const Color(0xFFD4520A) : const Color(0xFF8C7162);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(context, index),
          borderRadius: BorderRadius.circular(16),
          splashColor: const Color(0xFFD4520A).withValues(alpha: 0.05),
          highlightColor: const Color(0xFFD4520A).withValues(alpha: 0.02),
          hoverColor: const Color(0xFFD4520A).withValues(alpha: 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? const Color(0xFFD4520A).withValues(alpha: 0.1) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}







