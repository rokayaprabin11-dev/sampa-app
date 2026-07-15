import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/data/models/cultural_event.dart';
import 'package:sampada/providers/event_provider.dart';

/// Full details for a single cultural event — cover/gallery, category, date
/// (BS + AD), location and descriptions. Reached from the calendar-day popover
/// and the "View Details" action on the events list.
class EventDetailScreen extends StatefulWidget {
  final CulturalEvent event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  int _carousel = 0;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final id = int.tryParse(widget.event.id);
      if (id == null) return;
      final provider = context.read<EventProvider>();
      provider.recordEventVisit(id);
      provider.loadBookmarkedEventIds();
    });
  }

  static const _bsMonths = [
    'बैशाख', 'जेठ', 'असार', 'साउन', 'भदौ', 'असोज',
    'कार्तिक', 'मंसिर', 'पुष', 'माघ', 'फागुन', 'चैत',
  ];
  static const _adMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Cover first, then the gallery — deduped. A non-empty gallery used to
  /// replace the cover outright, dropping it from the carousel.
  List<String> get _images {
    final e = widget.event;
    final out = <String>[];
    if (e.imageUrl.isNotEmpty) out.add(e.imageUrl);
    for (final url in e.gallery) {
      if (url.isNotEmpty && !out.contains(url)) out.add(url);
    }
    return out;
  }

  String _ad(DateTime d) => '${d.day} ${_adMonths[d.month - 1]} ${d.year}';

  String _bs(DateTime d) {
    final b = d.toNepaliDateTime();
    return '${_bsMonths[b.month - 1]} ${b.day}, ${b.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final e = widget.event;
    final accent = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    final catColor = parseHexColor(e.color) ?? accent;
    final images = _images;

    final sameDay = e.startDate.year == e.endDate.year &&
        e.startDate.month == e.endDate.month &&
        e.startDate.day == e.endDate.day;
    final adDate = sameDay ? _ad(e.startDate) : '${_ad(e.startDate)} – ${_ad(e.endDate)}';
    final bsDate = sameDay ? _bs(e.startDate) : '${_bs(e.startDate)} – ${_bs(e.endDate)}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: isDark ? AppColors.brownDeep : const Color(0xFF5D1700),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Consumer<EventProvider>(
                builder: (context, provider, _) {
                  final id = int.tryParse(e.id);
                  final bookmarked = id != null && provider.isEventBookmarked(id);
                  return IconButton(
                    icon: Icon(
                      bookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: Colors.white,
                    ),
                    onPressed: id == null ? null : () => provider.toggleEventBookmark(id),
                  );
                },
              ),
            ],
            // Hero handed to flexibleSpace directly, NOT via FlexibleSpaceBar:
            // its parallax wrapper swallows the PageView's horizontal drags, so
            // the gallery carousel couldn't be swiped. A plain Stack (like the
            // heritage hero) gets the gestures.
            flexibleSpace: _hero(context, isDark, images),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category + gallery dots row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
                        ),
                        child: Text(
                          e.eventType,
                          style: TextStyle(color: catColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      if (images.length > 1)
                        Text('${_carousel + 1}/${images.length}',
                            style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    e.title,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface, height: 1.2),
                  ),
                  const SizedBox(height: 16),

                  _infoRow(context, isDark, Icons.calendar_today_outlined, bsDate, adDate),
                  if (e.timeLabel != null) ...[
                    const SizedBox(height: 12),
                    _infoRow(context, isDark, Icons.schedule_outlined, e.timeLabel!, null),
                  ],
                  if (e.locationName.isNotEmpty || (e.latitude != 0.0 && e.longitude != 0.0)) ...[
                    const SizedBox(height: 12),
                    _infoRow(
                      context, isDark, Icons.location_on_outlined,
                      e.locationName.isNotEmpty ? e.locationName : 'Location',
                      (e.latitude != 0.0 && e.longitude != 0.0)
                          ? '${e.latitude.toStringAsFixed(5)}, ${e.longitude.toStringAsFixed(5)}'
                          : null,
                    ),
                  ],
                  if (e.latitude != 0.0 && e.longitude != 0.0) ...[
                    const SizedBox(height: 16),
                    _viewOnMapButton(context, isDark, accent),
                  ],

                  if (e.shortDescription.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBgCard : const Color(0xFFFBF6EC),
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
                        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
                      ),
                      child: Text(
                        e.shortDescription,
                        style: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ),
                  ],

                  if (e.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(AppLocalizations.of(context)!.labelAbout, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: accent)),
                    const SizedBox(height: 8),
                    Text(
                      e.description,
                      style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    ),
                  ],

                  if (images.length > 1) ...[
                    const SizedBox(height: 24),
                    Text(AppLocalizations.of(context)!.sectionGallery, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: accent)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
                          child: AppNetworkImage(
                            url: images[i], width: 120, height: 90, fit: BoxFit.cover,
                            errorWidget: Container(
                              width: 120, height: 90,
                              color: isDark ? AppColors.darkBgCard : const Color(0xFFF0EAE4),
                              child: Icon(Icons.image_not_supported_outlined, color: isDark ? AppColors.darkTextTertiary : Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(BuildContext context, bool isDark, List<String> images) {
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        isDark ? AppColors.brownDeep : const Color(0xFF5D1700),
        isDark ? AppColors.brownDark : const Color(0xFF9E3D1A),
      ],
    );
    if (images.isEmpty) {
      return Container(
        decoration: BoxDecoration(gradient: gradient),
        child: const Center(child: Icon(Icons.event, color: Colors.white54, size: 64)),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (i) => setState(() => _carousel = i),
          itemCount: images.length,
          itemBuilder: (_, i) => AppNetworkImage(
            url: images[i],
            fit: BoxFit.cover,
            errorWidget: Container(
              decoration: BoxDecoration(gradient: gradient),
              child: const Center(child: Icon(Icons.event, color: Colors.white54, size: 64)),
            ),
          ),
        ),
        // Bottom scrim for the app-bar controls legibility. IgnorePointer so
        // it never intercepts the carousel's swipe gestures.
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Colors.black54, Colors.transparent],
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 10, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _carousel;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _viewOnMapButton(BuildContext context, bool isDark, Color accent) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => Navigator.pushNamed(
          context,
          AppStrings.mapPath,
          arguments: widget.event,
        ),
        icon: Icon(Icons.map_outlined, size: 18, color: accent),
        label: Text(
          AppLocalizations.of(context)!.btnViewOnMap,
          style: TextStyle(
              color: accent, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          side: BorderSide(
              color: isDark ? AppColors.darkBorder : const Color(0xFFE0D3C2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, bool isDark, IconData icon, String primary, String? secondary) {
    final accent = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(primary, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
              if (secondary != null && secondary.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(secondary, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
