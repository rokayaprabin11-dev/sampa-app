import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
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
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text('No districts match this search',
                            style: TextStyle(color: AppColors.kColorTextMuted, fontSize: 14)),
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
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Row(
                children: [
                  _CircleIconButton(icon: Icons.arrow_back_ios_new, onTap: onBack),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DISTRICTS',
                          style: TextStyle(
                            color: AppColors.kColorTextOnHeader,
                            fontFamily: 'serif',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          )),
                        SizedBox(height: 4),
                        Text('जिल्ला अनुसार हेर्नुहोस्',
                          style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 13)),
                      ],
                    ),
                  ),
                  _CircleIconButton(
                    icon: Icons.notifications,
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
          const Icon(Icons.search, color: Color(0xFF7B1E00), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(color: Color(0xFF4A342B), fontSize: 14),
              decoration: const InputDecoration(
                hintText: 'Search a district...',
                hintStyle: TextStyle(color: Color(0xFF8C7162), fontSize: 14),
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
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
    );
  }
}

class _CountLine extends StatelessWidget {
  final int districtCount;
  final int siteTotal;
  const _CountLine({required this.districtCount, required this.siteTotal});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontFamily: 'serif', fontSize: 16, fontWeight: FontWeight.w700),
            children: [
              TextSpan(text: '$districtCount', style: const TextStyle(color: AppColors.kColorAccentSafe)),
              const TextSpan(text: ' districts · ', style: TextStyle(color: AppColors.kColorTextHeading)),
              TextSpan(text: '$siteTotal', style: const TextStyle(color: AppColors.kColorAccentSafe)),
              const TextSpan(text: ' sites', style: TextStyle(color: AppColors.kColorTextHeading)),
            ],
          ),
        ),
        const Text('Updated recently', style: TextStyle(fontSize: 12, color: AppColors.kColorTextMuted)),
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
    const items = {
      _DistrictFilter.all: 'All',
      _DistrictFilter.valley: 'Kathmandu Valley',
      _DistrictFilter.mostSites: 'Most Sites',
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
