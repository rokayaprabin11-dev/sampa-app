import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/data/models/district_model.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/presentation/widgets/heritage_widgets.dart';
import 'package:sampada/providers/heritage_provider.dart';

enum _DistrictFilter { all, valley, mostSites }

const _valleySlugs = {'kathmandu', 'lalitpur', 'bhaktapur'};

class DistrictListScreen extends StatefulWidget {
  const DistrictListScreen({super.key});

  @override
  State<DistrictListScreen> createState() => _DistrictListScreenState();
}

class _DistrictListScreenState extends State<DistrictListScreen> {
  _DistrictFilter _filter = _DistrictFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hp = context.read<HeritageProvider>();
      if (hp.districts.isEmpty) hp.fetchDistricts();
    });
  }

  List<DistrictModel> _visible(List<DistrictModel> populated) {
    Iterable<DistrictModel> list = populated;
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      list = list.where((d) =>
          d.name.toLowerCase().contains(q) || d.nameNp.contains(_query.trim()));
    }
    switch (_filter) {
      case _DistrictFilter.mostSites:
        return list.toList()..sort((a, b) => b.sitesCount.compareTo(a.sitesCount));
      case _DistrictFilter.valley:
        return list.where((d) => _valleySlugs.contains(d.slug)).toList();
      case _DistrictFilter.all:
        return list.toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _Header(
            onBack: () => Navigator.pop(context),
            onSearchChanged: (q) => setState(() => _query = q),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Consumer<HeritageProvider>(
              builder: (context, hp, _) {
                final loading = hp.isLoading && hp.districts.isEmpty;
                if (loading) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.kColorPrimary));
                }
                // Only districts that already have heritage sites — the rest
                // aren't populated yet, so they're left out rather than shown
                // as dimmed placeholders.
                final populated = hp.districts.where((d) => d.sitesCount > 0).toList();
                final visible = _visible(populated);
                final siteTotal = populated.fold<int>(0, (s, d) => s + d.sitesCount);

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _FilterChips(
                        current: _filter,
                        onChanged: (f) => setState(() => _filter = f),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                      sliver: SliverToBoxAdapter(
                        child: _CountLine(districtCount: populated.length, siteTotal: siteTotal),
                      ),
                    ),
                    if (visible.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(AppLocalizations.of(context)!.noDistrictsMatchSearch,
                            style: const TextStyle(color: AppColors.kColorTextMuted, fontSize: 14)),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            childAspectRatio: 0.82,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final d = visible[i];
                              final info = districtVisualInfo(d.name);
                              return _StaggeredFadeIn(
                                index: i,
                                child: DistrictGridCard(
                                  name: d.name,
                                  nameNp: d.nameNp,
                                  sitesCount: d.sitesCount,
                                  coverImageUrl: d.coverImageUrl.isNotEmpty ? d.coverImageUrl : null,
                                  icon: info.icon,
                                  iconColor: info.color,
                                  iconBgColor: info.bgColor,
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppStrings.districtDetailPath,
                                    arguments: d,
                                  ),
                                ),
                              );
                            },
                            childCount: visible.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}

class _StaggeredFadeIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggeredFadeIn({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index.clamp(0, 12) * 40)),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, (1 - value) * 12), child: child),
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final ValueChanged<String> onSearchChanged;
  const _Header({required this.onBack, required this.onSearchChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.kColorDeep, AppColors.kColorPrimaryMid, AppColors.kColorPrimaryLight],
            ),
            image: AppTheme.headerIllustration,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Row(
                children: [
                  _CircleIconButton(
                    icon: Icons.arrow_back_ios_new,
                    label: MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: onBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.districtsTitle.toUpperCase(),
                          // Cinzel — the display face — not the platform serif.
                          style: GoogleFonts.cinzel(
                            color: AppColors.kColorTextOnHeader,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ).copyWith(fontFamilyFallback: AppTheme.devanagariFallback)),
                        const SizedBox(height: 4),
                        Text(l10n.districtsSubtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xB3FFFFFF),
                          )),
                      ],
                    ),
                  ),
                  _CircleIconButton(
                    icon: Icons.notifications,
                    label: l10n.navNotifications,
                    onTap: () => Navigator.pushNamed(context, AppStrings.notificationsPath),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -22,
          left: 20,
          right: 20,
          child: _SearchBar(onChanged: onSearchChanged),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.kColorDeep, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(color: AppColors.kColorTextBody, fontSize: 14),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.searchDistrictHint,
                hintStyle: const TextStyle(color: AppColors.kColorTextMuted, fontSize: 14),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// What a screen reader announces — a bare icon says nothing.
  final String label;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    // Visual stays the 38dp chip; the tappable surface is the full 48dp
    // accessibility minimum around it.
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                ),
                child: Icon(icon, color: Colors.white, size: 17),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountLine extends StatelessWidget {
  final int districtCount;
  final int siteTotal;
  const _CountLine({required this.districtCount, required this.siteTotal});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Cinzel (not platform serif), and the phrases come whole from l10n so
    // word order survives translation.
    final base = GoogleFonts.cinzel(fontSize: 14, fontWeight: FontWeight.w700)
        .copyWith(fontFamilyFallback: AppTheme.devanagariFallback);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            style: base,
            children: [
              TextSpan(
                  text: l10n.districtCountLabel(districtCount),
                  style: const TextStyle(color: AppColors.kColorAccentSafe)),
              const TextSpan(text: ' · ', style: TextStyle(color: AppColors.kColorTextHeading)),
              TextSpan(
                  text: l10n.siteCountLabel(siteTotal),
                  style: const TextStyle(color: AppColors.kColorAccentSafe)),
            ],
          ),
        ),
        Text(l10n.updatedRecently,
            style: const TextStyle(fontSize: 12, color: AppColors.kColorTextMuted)),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  final _DistrictFilter current;
  final ValueChanged<_DistrictFilter> onChanged;
  const _FilterChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = {
      _DistrictFilter.all: l10n.all,
      _DistrictFilter.valley: l10n.filterKathmanduValley,
      _DistrictFilter.mostSites: l10n.filterMostSites,
    };
    return SizedBox(
      height: 60,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        children: items.entries.map((e) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: CategoryChip(
            label: e.value,
            isSelected: e.key == current,
            onTap: () => onChanged(e.key),
            isDesignStyle: true,
          ),
        )).toList(),
      ),
    );
  }
}
