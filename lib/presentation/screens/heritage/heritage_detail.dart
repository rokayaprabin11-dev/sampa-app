import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sampada/core/constants/app_colors.dart';

class HeritageApp extends StatelessWidget {
  const HeritageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Heritage Detail',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Georgia',
        scaffoldBackgroundColor: const Color(0xFFF5EFE6),
      ),
      home: HeritageDetailPage(site: kSampleSite),
    );
  }
}

// ─── Colors ────────────────────────────────────────────────────────────────────

const Color kPrimary      = Color(0xFF8B2200);
const Color kPrimaryLight = Color(0xFFB84A1E);
const Color kAccent       = Color(0xFFD4891A);
const Color kBg           = Color(0xFFF5EFE6);
const Color kCardBg       = Color(0xFFFFFFFF);
const Color kTextDark     = Color(0xFF2C1A0E);
const Color kTextMuted    = Color(0xFF8C7B6E);
const Color kTagBg        = Color(0xFFF0E6D3);

// ─── Model ─────────────────────────────────────────────────────────────────────

class HeritageSite {
  final String name;
  final String category;
  final double rating;
  final int reviewCount;
  final String location;
  final String description;
  final Color heroColor;
  final IconData heroIcon;
  final List<GalleryItem> gallery;
  final bool availableOffline;

  const HeritageSite({
    required this.name,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.description,
    required this.heroColor,
    required this.heroIcon,
    required this.gallery,
    this.availableOffline = true,
  });
}

class GalleryItem {
  final IconData icon;
  final Color color;
  const GalleryItem({required this.icon, required this.color});
}

// ─── Sample Data ───────────────────────────────────────────────────────────────

final HeritageSite kSampleSite = HeritageSite(
  name: 'Pashupatinath Temple',
  category: 'UNESCO Heritage',
  rating: 4.9,
  reviewCount: 2400,
  location: 'Pashupati Area, Kathmandu',
  description:
      'Pashupatinath Temple is one of the most sacred Hindu temples dedicated to '
      'Lord Shiva. Located on the banks of the Bagmati River, it is a UNESCO World '
      'Heritage Site and one of the four most important religious sites in Asia for '
      'devotees of Shiva.',
  heroColor: Color(0xFF7A1E00),
  heroIcon: Icons.temple_hindu,
  gallery: [
    GalleryItem(icon: Icons.temple_hindu,          color: Color(0xFF8B2200)),
    GalleryItem(icon: Icons.account_balance,        color: Color(0xFF5C3A1E)),
    GalleryItem(icon: Icons.account_balance,    color: Color(0xFF8B4513)),
    GalleryItem(icon: Icons.account_balance_wallet, color: Color(0xFF6B3A2A)),
  ],
  availableOffline: true,
);

// ─── Detail Page ───────────────────────────────────────────────────────────────

class HeritageDetailPage extends StatefulWidget {
  final HeritageSite site;
  const HeritageDetailPage({super.key, required this.site});

  @override
  State<HeritageDetailPage> createState() => _HeritageDetailPageState();
}

class _HeritageDetailPageState extends State<HeritageDetailPage> {
  bool _isBookmarked = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHero(context),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: AppColors.darkBorder) : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitle(context),
                      const SizedBox(height: 10),
                      _buildCategoryTag(context),
                      const SizedBox(height: 10),
                      _buildRatingRow(context),
                      const SizedBox(height: 6),
                      _buildLocationRow(context),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFEEE4D8) : AppColors.darkBorder, thickness: 1),
                      ),
                      _buildAboutSection(context),
                      const SizedBox(height: 20),
                      _buildGallerySection(context),
                      const SizedBox(height: 28),
                      _buildActionButtons(context),
                      const SizedBox(height: 14),
                      _buildOfflineBadge(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [widget.site.heroColor, widget.site.heroColor.withRed(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.9,
                  colors: [
                    Colors.white.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              widget.site.heroIcon,
              size: 110,
              color: Colors.white.withValues(alpha: 0.80),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              hoverColor: Colors.black.withValues(alpha: 0.1),
              splashColor: Colors.black.withValues(alpha: 0.2),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: IconButton(
              onPressed: () {
                setState(() => _isBookmarked = !_isBookmarked);
                HapticFeedback.lightImpact();
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  key: ValueKey(_isBookmarked),
                  color: _isBookmarked ? kAccent : Colors.white,
                  size: 20,
                ),
              ),
              hoverColor: Colors.black.withValues(alpha: 0.1),
              splashColor: Colors.black.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      widget.site.name,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.25,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildCategoryTag(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light ? kTagBg : AppColors.darkBgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 13, color: kAccent),
          const SizedBox(width: 4),
          Text(
            widget.site.category,
            style: const TextStyle(
              color: kAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingRow(BuildContext context) {
    final reviews = widget.site.reviewCount >= 1000
        ? '${(widget.site.reviewCount / 1000).toStringAsFixed(1)}k'
        : '${widget.site.reviewCount}';

    return Row(
      children: [
        const Icon(Icons.star_rounded, color: kAccent, size: 17),
        const SizedBox(width: 4),
        Text(
          widget.site.rating.toStringAsFixed(1),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '($reviews reviews)',
          style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? kTextMuted : AppColors.darkTextTertiary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildLocationRow(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on_outlined, size: 15, color: Theme.of(context).brightness == Brightness.light ? kTextMuted : AppColors.darkTextTertiary),
        const SizedBox(width: 4),
        Text(
          widget.site.location,
          style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? kTextMuted : AppColors.darkTextTertiary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About this Site',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.site.description,
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light ? kTextMuted : AppColors.darkTextSecondary,
            fontSize: 13.5,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildGallerySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gallery',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: widget.site.gallery
              .map((item) => _GalleryThumb(item: item))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.map_outlined, size: 17),
            label: const Text('View Map'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.light ? kPrimary : AppColors.goldMain,
              side: BorderSide(color: Theme.of(context).brightness == Brightness.light ? kPrimary : AppColors.goldMain, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.near_me_outlined, size: 17),
            label: const Text('Directions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.light ? kPrimary : AppColors.goldMain,
              foregroundColor: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOfflineBadge() {
    if (!widget.site.availableOffline) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF4CAF50)),
        const SizedBox(width: 6),
        Text(
          'Available Offline',
          style: TextStyle(
            color: Colors.green.shade700,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Gallery Thumbnail ─────────────────────────────────────────────────────────

class _GalleryThumb extends StatelessWidget {
  final GalleryItem item;
  const _GalleryThumb({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          color: item.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: item.color.withValues(alpha: 0.45),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(item.icon, size: 32, color: Colors.white.withValues(alpha: 0.85)),
      ),
    );
  }
}






