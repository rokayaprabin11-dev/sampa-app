import 'package:flutter/material.dart';
import 'package:sampada/presentation/widgets/common/interactive_surface.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/theme/app_theme.dart';

/// Design kit for the Help & Support feature. Mirrors the approved prototype
/// (terracotta accents, seal dots, eyebrow labels, card lists) but resolves the
/// header, surfaces and ink from the app theme — the Sampada gradient app bar,
/// Cinzel headings and terracotta tokens — so light and dark both look right and
/// it never drifts from the rest of the app.

/// Theme-agnostic brand accents (identical in light and dark).
class HelpColors {
  HelpColors._();
  static const terracotta = AppColors.kColorPrimary; // #C8501A
  static const terracottaDeep = AppColors.kColorAccentDark; // #993814
  static const gold = Color(0xFFD4AF37);
  static const sage = Color(0xFF6E8360);
  static const alert = Color(0xFFB8453A);
}

/// Surface/ink colours resolved for the current theme.
class HelpPalette {
  final bool isDark;
  final Color page, card, line, ink, muted, faint, wash;
  const HelpPalette._({
    required this.isDark,
    required this.page,
    required this.card,
    required this.line,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.wash,
  });

  factory HelpPalette.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return HelpPalette._(
      isDark: dark,
      page: Theme.of(context).scaffoldBackgroundColor,
      card: Theme.of(context).colorScheme.surface,
      line: dark ? AppColors.darkBorder : AppColors.kColorBorderSubtle,
      ink: Theme.of(context).colorScheme.onSurface,
      muted: dark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary,
      faint: dark ? AppColors.darkTextTertiary : AppColors.kColorTextMuted,
      wash:
          dark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF6EBE0),
    );
  }
}

/// Cinzel — the app's heading font (matches AppTheme titleLarge/displayLarge).
TextStyle helpSerif(
        {double size = 16,
        FontWeight weight = FontWeight.w600,
        Color? color}) =>
    GoogleFonts.cinzel(fontSize: size, fontWeight: weight, color: color);

/// Small letter-spaced label. Uses the app's own font (no separate mono face)
/// so eyebrows read as part of Sampada, not a bolt-on.
TextStyle helpLabel({double size = 10.5, Color? color}) => TextStyle(
    fontSize: size,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: color);

/// A page scaffold with Sampada's signature terracotta gradient header
/// (AppTheme.navGradient + rounded bottom corners), identical to Settings/About
/// so the Help Center reads as part of the app.
class HelpScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? floating;

  const HelpScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.floating,
  });

  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return Scaffold(
      backgroundColor: p.page,
      floatingActionButton: floating,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppTheme.navGradient,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
                bottomRight: Radius.circular(AppDimensions.kRadiusXxl),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: helpSerif(size: 20, color: Colors.white)),
                          if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(subtitle!,
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w500)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Uppercase eyebrow label in the app font.
class HelpEyebrow extends StatelessWidget {
  final String text;
  const HelpEyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(),
            style: helpLabel(size: 10.5, color: HelpColors.terracottaDeep)),
      );
}

/// Serif section title with a terracotta seal dot.
class HelpSectionTitle extends StatelessWidget {
  final String text;
  final EdgeInsets padding;
  const HelpSectionTitle(this.text,
      {super.key, this.padding = const EdgeInsets.only(top: 22, bottom: 12)});
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  color: HelpColors.terracotta, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: helpSerif(size: 15.5, color: p.ink)),
        ],
      ),
    );
  }
}

/// A rounded white card container.
class HelpCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  const HelpCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return InteractiveSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: card,
    );
  }
}

/// A grouped list container (rounded, hairline-separated rows).
class HelpMenuList extends StatelessWidget {
  final List<Widget> children;
  const HelpMenuList({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(height: 1, thickness: 1, color: p.line),
          ],
        ],
      ),
    );
  }
}

class HelpMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? tint;
  const HelpMenuItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.tint,
  });
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    final accent = tint ?? HelpColors.terracottaDeep;
    return InteractiveSurface(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: p.isDark ? 0.18 : 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: p.ink)),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(subtitle!,
                          style: TextStyle(fontSize: 11.5, color: p.muted)),
                    ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right, size: 16, color: p.faint),
          ],
        ),
      ),
    );
  }
}

/// A topic tile in the 3-column popular-topics grid (pentagon "seal" icon).
class HelpTopicTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final bool disabled;
  final VoidCallback? onTap;
  const HelpTopicTile({
    super.key,
    required this.icon,
    required this.label,
    this.badge,
    this.disabled = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InteractiveSurface(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.line),
          ),
          // Centred: the Column is the only unpositioned child, so the Stack's
          // alignment is what actually centres it — without this it pins to the
          // top-left and leaves dead space under the label.
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: HelpColors.terracotta
                          .withValues(alpha: p.isDark ? 0.18 : 0.12),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(11), bottom: Radius.circular(4)),
                    ),
                    child:
                        Icon(icon, size: 17, color: HelpColors.terracottaDeep),
                  ),
                  const SizedBox(height: 6),
                  Text(label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: p.ink,
                          height: 1.2)),
                ],
              ),
              if (badge != null)
                Positioned(
                  top: -8,
                  right: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                        color: p.ink, borderRadius: BorderRadius.circular(6)),
                    child:
                        Text(badge!, style: helpLabel(size: 8, color: p.page)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Search field styled per the prototype.
class HelpSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  const HelpSearchField(
      {super.key, required this.hint, this.onChanged, this.controller});
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: p.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.faint, fontSize: 14),
        prefixIcon: Icon(Icons.search, size: 18, color: p.muted),
        filled: true,
        fillColor: p.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: HelpColors.terracotta, width: 1.4)),
      ),
    );
  }
}

/// Full-width primary CTA.
class HelpPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  const HelpPrimaryButton(
      {super.key, required this.label, this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: HelpColors.terracotta,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
        label: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Full-width secondary (outlined) button.
class HelpSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const HelpSecondaryButton({super.key, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          side: BorderSide(color: p.line),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(label,
            style:
                const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// Selectable pill chip (single- or multi-select handled by the parent).
class HelpChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const HelpChip(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return InteractiveSurface(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? HelpColors.terracotta : p.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? HelpColors.terracotta : p.line),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : p.muted)),
      ),
    );
  }
}

/// Labelled text input for forms.
class HelpTextField extends StatelessWidget {
  final String label;
  final String hint;
  final int maxLines;
  final TextEditingController? controller;
  const HelpTextField({
    super.key,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.controller,
  });
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: p.ink)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: TextStyle(fontSize: 13.5, color: p.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: p.faint, fontSize: 13),
            filled: true,
            fillColor: p.card,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: p.line)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: p.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: HelpColors.terracotta, width: 1.4)),
          ),
        ),
      ],
    );
  }
}

/// Toast-style confirmation (dark pill with a gold check).
void showHelpToast(BuildContext context, String message,
    {IconData icon = Icons.check_circle}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.kColorBrownDarkest,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    margin: const EdgeInsets.all(16),
    content: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 16, color: HelpColors.gold),
      const SizedBox(width: 10),
      Flexible(
          child: Text(message,
              style: const TextStyle(
                  color: Color(0xFFF8F6F3),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600))),
    ]),
  ));
}
