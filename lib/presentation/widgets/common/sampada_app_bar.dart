import 'package:flutter/material.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/theme/app_theme.dart';

/// The app's header: maroon→terracotta gradient, rounded at the bottom, white
/// content. Use this rather than building an [AppBar] by hand — the theme is
/// built around this header, and a hand-rolled one is easy to get wrong in two
/// ways that both end in an invisible title:
///
///  * `AppBarTheme` hard-sets a white `titleTextStyle` and a white `iconTheme`,
///    and both beat `foregroundColor` (Flutter only applies `foregroundColor` to
///    *default* styles). So a "light" AppBar that merely sets `foregroundColor`
///    still renders white text — on the cream scaffold, i.e. invisibly.
///  * `flexibleSpace` is laid out with loose constraints, so a childless
///    `DecoratedBox` there collapses to zero and paints no gradient at all. It
///    has to be a `Container`, which expands to fill.
///
/// Both are handled here, once. A solid [AppColors.kColorDeep] sits under the
/// gradient so the bar can never fall back to the scaffold colour, and the
/// AppBar's own [shape] matches the gradient's radius so that solid layer does
/// not show as square corners behind rounded ones.
///
/// The title needs no style: the theme already renders it white in Cinzel.
class SampadaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  const SampadaAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
  });

  static const BorderRadius radius = BorderRadius.only(
    bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
    bottomRight: Radius.circular(AppDimensions.kRadiusXxl),
  );

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.kColorDeep,
      shape: const RoundedRectangleBorder(borderRadius: radius),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      foregroundColor: AppColors.kColorTextOnHeader,
      leading: leading,
      title: title,
      actions: actions,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.navGradient,
          borderRadius: radius,
        ),
      ),
    );
  }
}
