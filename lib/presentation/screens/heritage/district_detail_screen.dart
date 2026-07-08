import 'package:flutter/material.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/data/models/district_model.dart';
import 'package:sampada/data/models/heritage_site.dart';
import 'package:sampada/providers/heritage_provider.dart';

class DistrictDetailScreen extends StatefulWidget {
  final DistrictModel district;

  const DistrictDetailScreen({super.key, required this.district});

  @override
  State<DistrictDetailScreen> createState() => _DistrictDetailScreenState();
}

class _DistrictDetailScreenState extends State<DistrictDetailScreen> {
  List<HeritageSite> _sites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSites());
  }

  Future<void> _loadSites() async {
    final repo = context.read<HeritageProvider>().repository;
    final slug = widget.district.slug.isNotEmpty
        ? widget.district.slug
        : widget.district.name.toLowerCase();
    try {
      final results = await repo.getHeritageSites(district: slug);
      if (mounted) setState(() { _sites = results; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.district;
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final description = d.descriptionEn.isNotEmpty
        ? d.descriptionEn
        : '${d.name} is one of Nepal\'s notable districts, home to significant cultural and historical heritage sites that reflect the rich traditions of the region.';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Hero header
          SizedBox(
            height: size.height * 0.32,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Cover image or gradient fallback
                if (d.coverImageUrl.isNotEmpty)
                  AppNetworkImage(
                    url: d.coverImageUrl,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [const Color(0xFF5D1700), const Color(0xFF9E3D1A)],
                        ),
                      ),
                      child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 64))),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [AppColors.brownDeep, const Color(0xFF3B1A0A)]
                            : [const Color(0xFF5D1700), const Color(0xFF9E3D1A)],
                      ),
                    ),
                    child: const Center(child: Text('🏛️', style: TextStyle(fontSize: 64))),
                  ),
                // Dark gradient overlay for nav readability
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Color(0x00000000)],
                      stops: [0.0, 0.5],
                    ),
                  ),
                ),
                // Nav buttons
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _NavBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content card
          DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.72,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBgCard : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.kRadiusXxl)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFDDD0C8),
                          borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
                        ),
                      ),
                    ),

                    // Title
                    Text(
                      '${d.name} District',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF2C1A0E),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // UNESCO badge
                    if (d.unescoCount > 0) ...[
                      Row(
                        children: [
                          const Text('🥇', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Text(
                            AppLocalizations.of(context)!.unescoZone,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.goldMain : AppColors.kColorAccentSafe,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    Text(
                      '${d.sitesCount} Heritage Sites  •  ${d.unescoCount} UNESCO Sites',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162),
                      ),
                    ),

                    const SizedBox(height: 16),
                    Divider(color: isDark ? AppColors.darkBorder : const Color(0xFFF0E6D3)),
                    const SizedBox(height: 16),

                    // About
                    Text(
                      AppLocalizations.of(context)!.labelAbout,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2C1A0E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF5C4033),
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Stats
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBgPage : const Color(0xFFFAF5EF),
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFF0E6D3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _stat(isDark, d.sitesCount.toString(), 'Sites'),
                          _statDivider(isDark),
                          _stat(isDark, d.eventCount > 0 ? d.eventCount.toString() : '–', 'Events'),
                          _statDivider(isDark),
                          _stat(isDark, d.unescoCount.toString(), 'UNESCO'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Top Sites
                    Text(
                      AppLocalizations.of(context)!.topSites,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2C1A0E),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_loading)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_sites.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          AppLocalizations.of(context)!.noPublishedSites,
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162),
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      ..._sites.take(5).map((site) => _SiteListTile(site: site)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _stat(bool isDark, String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.goldMain : AppColors.kColorAccentSafe,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162),
          ),
        ),
      ],
    );
  }

  Widget _statDivider(bool isDark) {
    return Container(
      height: 32,
      width: 1,
      color: isDark ? AppColors.darkBorder : const Color(0xFFE8D9C8),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SiteListTile extends StatelessWidget {
  final HeritageSite site;
  const _SiteListTile({required this.site});

  IconData _icon(String cat) {
    switch (cat.toLowerCase()) {
      case 'temple': return Icons.temple_hindu;
      case 'stupa': return Icons.temple_buddhist;
      case 'palace': return Icons.castle;
      case 'durbar': return Icons.account_balance;
      default: return Icons.museum;
    }
  }

  Widget _iconPlaceholder(bool isDark) => Container(
    width: 56,
    height: 56,
    color: isDark ? AppColors.darkBgPage : const Color(0xFFF5EFEC),
    child: Icon(_icon(site.category),
        color: isDark ? AppColors.goldMain : const Color(0xFF5C4033), size: 22),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(
        context,
        AppStrings.heritageDetailsPath,
        arguments: site,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFF0E6D3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
              child: site.imageUrl != null && site.imageUrl!.isNotEmpty
                  ? AppNetworkImage(
                      url: site.imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: _iconPlaceholder(isDark),
                    )
                  : _iconPlaceholder(isDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12,
                          color: isDark ? AppColors.darkTextTertiary : const Color(0xFF8C7162)),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          site.location.isNotEmpty ? site.location : site.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextTertiary : const Color(0xFF8C7162),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: isDark ? AppColors.darkTextTertiary : const Color(0xFF8C7162)),
          ],
        ),
      ),
    );
  }
}
