import 'package:flutter/material.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/providers/text_size_provider.dart';
import 'package:sampada/core/providers/auto_sync_provider.dart';
import 'package:sampada/core/theme/app_theme.dart';

class RecentlyVisitedCard extends StatelessWidget {
  final String title;
  final String timeAgo;
  final IconData icon;
  final String? imageUrl;
  final VoidCallback? onTap;

  const RecentlyVisitedCard({
    super.key,
    required this.title,
    required this.timeAgo,
    required this.icon,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap ?? () => Navigator.pushNamed(context, AppStrings.heritageDetailsPath),
      borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.goldLight : AppColors.darkBorder),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            // Use a simple Icon or Image if assets are available. 
            // Based on the image, they look like stylized illustrations.
            // For now, I'll keep the Icon but adjust the styling.
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
              child: SizedBox(
                width: 48, height: 48,
                child: (imageUrl != null && imageUrl!.isNotEmpty)
                    ? AppNetworkImage(url: imageUrl, fit: BoxFit.cover,
                        errorWidget: _iconBox(context))
                    : _iconBox(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFC8851A) : AppColors.goldMain, size: 18),
          ],
        ),
      ),
      ),
    );
  }

  Widget _iconBox(BuildContext context) => Container(
    color: Theme.of(context).brightness == Brightness.light ? AppColors.brownUltraLight : AppColors.darkBgCard,
    child: Center(child: Icon(icon, color: Theme.of(context).brightness == Brightness.light ? AppColors.brownDark : AppColors.goldMain, size: 28)),
  );
}

class AccountOptionTile extends StatelessWidget {
  final String title;
  final String? trailingText;
  final IconData? icon;
  final String? imagePath;
  final Color iconBgColor;

  const AccountOptionTile({
    super.key,
    required this.title,
    this.trailingText,
    this.icon,
    this.imagePath,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTransparent = iconBgColor == Colors.transparent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.goldLight : AppColors.darkBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTransparent ? 0 : 8),
            decoration: BoxDecoration(
              color: isTransparent ? Colors.transparent : (Theme.of(context).brightness == Brightness.light ? AppColors.brownUltraLight : AppColors.darkBgCard),
              shape: BoxShape.circle,
            ),
            child: imagePath != null
                ? Image.asset(
                    imagePath!,
                    width: isTransparent ? 32 : 20,
                    height: isTransparent ? 32 : 20,
                    fit: BoxFit.contain,
                  )
                : Icon(icon, color: Theme.of(context).brightness == Brightness.light ? AppColors.brownDark : AppColors.goldMain, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailingText != null)
            Text(
              trailingText!,
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextSecondary,
                fontSize: 14,
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right, color: Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextTertiary, size: 20),
        ],
      ),
    );
  }
}

class LanguageOptionTile extends StatelessWidget {
  final String title;
  final String currentLanguage;
  final Function(Locale) onLanguageSelected;

  const LanguageOptionTile({
    super.key,
    required this.title,
    required this.currentLanguage,
    required this.onLanguageSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.goldLight : AppColors.darkBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/language.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          PopupMenuButton<Locale>(
            tooltip: '',
            offset: const Offset(0, 40),
            onSelected: onLanguageSelected,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg)),
            color: Theme.of(context).colorScheme.surface,
            elevation: 8,
            itemBuilder: (context) => [
              _buildPopupMenuItem(context, const Locale('en'), 'English'),
              _buildPopupMenuItem(context, const Locale('ne'), 'नेपाली'),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentLanguage,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextTertiary, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<Locale> _buildPopupMenuItem(
      BuildContext context, Locale locale, String label) {
    return PopupMenuItem<Locale>(
      value: locale,
      padding: EdgeInsets.zero,
      child: _HoverMenuItem(label: label),
    );
  }
}

class TextSizeOptionTile extends StatelessWidget {
  final String title;
  final String currentSizeLabel;
  final Function(TextSize) onSizeSelected;

  const TextSizeOptionTile({
    super.key,
    required this.title,
    required this.currentSizeLabel,
    required this.onSizeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.goldLight : AppColors.darkBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/FONT.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          PopupMenuButton<TextSize>(
            tooltip: '',
            offset: const Offset(0, 40),
            onSelected: onSizeSelected,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg)),
            color: Theme.of(context).colorScheme.surface,
            elevation: 8,
            itemBuilder: (context) => [
              _buildPopupMenuItem(TextSize.small, 'Small'),
              _buildPopupMenuItem(TextSize.medium, 'Medium'),
              _buildPopupMenuItem(TextSize.large, 'Large'),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentSizeLabel,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextTertiary, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<TextSize> _buildPopupMenuItem(TextSize size, String label) {
    return PopupMenuItem<TextSize>(
      value: size,
      padding: EdgeInsets.zero,
      child: _HoverMenuItem(label: label),
    );
  }
}

class AutoSyncOptionTile extends StatelessWidget {
  final String title;
  final String currentModeLabel;
  final Function(AutoSyncMode) onModeSelected;

  const AutoSyncOptionTile({
    super.key,
    required this.title,
    required this.currentModeLabel,
    required this.onModeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.goldLight : AppColors.darkBorder),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/icons/AUTOSYCN.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          PopupMenuButton<AutoSyncMode>(
            tooltip: '',
            offset: const Offset(0, 40),
            onSelected: onModeSelected,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg)),
            color: Theme.of(context).colorScheme.surface,
            elevation: 8,
            itemBuilder: (context) => [
              _buildSyncPopupMenuItem(AutoSyncMode.wifiOnly, 'WiFi Only'),
              _buildSyncPopupMenuItem(AutoSyncMode.dataAndWifi, 'Data & WiFi'),
              _buildSyncPopupMenuItem(AutoSyncMode.off, 'Off'),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentModeLabel,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextTertiary, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<AutoSyncMode> _buildSyncPopupMenuItem(AutoSyncMode mode, String label) {
    return PopupMenuItem<AutoSyncMode>(
      value: mode,
      padding: EdgeInsets.zero,
      child: _HoverMenuItem(label: label),
    );
  }
}

class _HoverMenuItem extends StatefulWidget {
  final String label;
  const _HoverMenuItem({required this.label});

  @override
  State<_HoverMenuItem> createState() => _HoverMenuItemState();
}

class _HoverMenuItemState extends State<_HoverMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _isHovered 
              ? (Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.darkBgSurface)
              : Colors.transparent,
        ),
        child: Text(
          widget.label,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
        ),
      ),
    );
  }
}

class SettingsSwitchTile extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? imagePath;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? leftLabel;
  final String? rightLabel;

  const SettingsSwitchTile({
    super.key,
    required this.title,
    this.icon,
    this.imagePath,
    required this.value,
    required this.onChanged,
    this.leftLabel,
    this.rightLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.goldLight : AppColors.darkBorder),
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF3A241C) : AppColors.darkBgCard,
              shape: BoxShape.circle,
            ),
            child: imagePath != null
                ? Image.asset(imagePath!, width: 18, height: 18, color: Theme.of(context).brightness == Brightness.light ? Colors.white : AppColors.goldMain)
                : Icon(icon, color: Theme.of(context).brightness == Brightness.light ? Colors.white : AppColors.goldMain, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (leftLabel != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(leftLabel!, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
            ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF3DA35D),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8B2C1F) : Colors.grey.withValues(alpha: 0.3),
          ),
          if (rightLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(rightLabel!, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
            ),
        ],
      ),
    );
  }
}

class SettingsNavigationTile extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? imagePath;
  final String? trailingText;
  final VoidCallback onTap;

  const SettingsNavigationTile({
    super.key,
    required this.title,
    this.icon,
    this.imagePath,
    this.trailingText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.goldLight : AppColors.darkBorder),
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF3A241C) : AppColors.darkBgCard,
                shape: BoxShape.circle,
              ),
              child: imagePath != null
                  ? Image.asset(imagePath!, width: 18, height: 18, color: Theme.of(context).brightness == Brightness.light ? Colors.white : AppColors.goldMain)
                  : Icon(icon, color: Theme.of(context).brightness == Brightness.light ? Colors.white : AppColors.goldMain, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingText != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  trailingText!,
                  style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextSecondary, fontSize: 14),
                ),
              ),
            Icon(Icons.chevron_right, size: 20, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextTertiary),
          ],
        ),
      ),
      ),
    );
  }
}








