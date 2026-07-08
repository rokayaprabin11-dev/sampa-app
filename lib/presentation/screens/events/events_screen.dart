import 'package:flutter/material.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/utils/geo_distance.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';
import 'package:sampada/providers/event_provider.dart';
import 'package:sampada/data/models/cultural_event.dart';
import 'package:sampada/presentation/screens/events/event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatEventDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<EventProvider>();
      provider.resetToToday();
    });
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                l10n.sectionNearbyFestivals,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.light ? AppColors.textHeadline : AppColors.goldMain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _MonthSelector(
              months: eventProvider.bsMonths,
              selectedIndex: eventProvider.selectedMonthIndex,
              onTap: (index) => eventProvider.setSelectedMonthIndex(index),
            ),
            const SizedBox(height: 24),
            const _CalendarWidget(),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                l10n.sectionCurrentEvents,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.light ? AppColors.textHeadline : AppColors.goldMain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (eventProvider.isLoading)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 4,
                itemBuilder: (context, index) => const EventCardSkeleton(),
              )
            else if (eventProvider.error != null)
              Center(child: Text(eventProvider.error!))
            else if (eventProvider.currentEvents.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Center(
                  child: Text(
                    'No upcoming events',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.light ? AppColors.textSecondary : AppColors.darkTextSecondary,
                    ),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: eventProvider.currentEvents.length,
                itemBuilder: (context, index) {
                  final event = eventProvider.currentEvents[index];
                  final km = eventProvider.distanceKmOf(event);
                  return _EventListCard(
                    title: event.title,
                    date: _formatEventDate(event.startDate),
                    location: event.locationName,
                    distance: km == null ? null : GeoDistance.shortLabel(km),
                    tag: event.eventType,
                    imageUrl: event.imageUrl,
                    shortDescription: event.shortDescription,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
                    ),
                  );
                },
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [AppColors.brownDeep, Color(0xFF9E3D1A)]
              : const [Color(0xFF5C1A0A), Color(0xFFA83210), Color(0xFFC8501A)],
          stops: isDark ? null : const [0.0, 0.6, 1.0],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
          bottomRight: Radius.circular(AppDimensions.kRadiusXxl),
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 24,
        right: 24,
        bottom: 40,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Calendar & Cultural\nEvents',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final List<String> months;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _MonthSelector({
    required this.months,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: months.length,
        itemBuilder: (context, index) {
          final isSelected = selectedIndex == index;
          return GestureDetector(
            onTap: () => onTap(index),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected 
                    ? (Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.goldMain) 
                    : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
                border: Border.all(
                  color: isSelected ? AppColors.goldMain : (Theme.of(context).brightness == Brightness.light ? AppColors.brownLight : AppColors.darkBorder),
                ),
              ),
              child: Text(
                months[index],
                style: TextStyle(
                  color: isSelected 
                      ? (Theme.of(context).brightness == Brightness.light ? AppColors.brownDark : Colors.black) 
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalendarWidget extends StatelessWidget {
  const _CalendarWidget();

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();
    final days = eventProvider.calendarDays;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Calendar Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.darkBgCard,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppDimensions.kRadiusXxl),
                topRight: Radius.circular(AppDimensions.kRadiusXxl),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    eventProvider.calendarHeaderTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (eventProvider.selectedMonthIndex > 0) ...[
                      GestureDetector(
                        onTap: () => eventProvider.previousMonth(),
                        child: Icon(
                          Icons.chevron_left, 
                          size: 24, 
                          color: Theme.of(context).brightness == Brightness.light ? AppColors.textSecondary : AppColors.darkTextSecondary
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    GestureDetector(
                      onTap: () => eventProvider.resetToToday(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.goldMain,
                          borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.goldMain.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'आज',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => eventProvider.nextMonth(),
                      child: Icon(
                        Icons.chevron_right, 
                        size: 24, 
                        color: Theme.of(context).brightness == Brightness.light ? AppColors.textSecondary : AppColors.darkTextSecondary
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Days Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ['आइ', 'Sun'], 
                ['सोम', 'Mon'], 
                ['मंग', 'Tue'], 
                ['बुध', 'Wed'], 
                ['बिही', 'Thu'], 
                ['शुक्र', 'Fri'], 
                ['शनि', 'Sat']
              ].map((day) {
                return Column(
                  children: [
                    Text(
                      day[0],
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      day[1],
                      style: TextStyle(
                        fontSize: 10, 
                        color: Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextTertiary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          // Grid of Days
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              return _CalendarDayItem(day: day);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _CalendarDayItem extends StatelessWidget {
  final CalendarDay day;

  const _CalendarDayItem({required this.day});

  @override
  Widget build(BuildContext context) {
    final Color bgColor = day.isToday 
        ? (Theme.of(context).brightness == Brightness.light ? AppColors.brownDark : AppColors.goldMain) 
        : (day.hasEvent ? (Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.darkBgCard) : Colors.transparent);
    final Color textColor = day.isToday 
        ? (Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black) 
        : Theme.of(context).colorScheme.onSurface;
    final Color adTextColor = day.isToday 
        ? (Theme.of(context).brightness == Brightness.light ? Colors.white70 : Colors.black54) 
        : (Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextTertiary);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: day.events.isEmpty ? null : () => showDayEventsPopover(context, day.events),
      child: Opacity(
      opacity: day.isCurrentMonth ? 1.0 : 0.3,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
          border: (day.hasEvent && !day.isToday && Theme.of(context).brightness == Brightness.dark) ? Border.all(color: AppColors.darkBorder) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _toNepaliNumber(day.bsDay),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                ),
                if (day.hasEvent && !day.isToday)
                  Container(
                    margin: const EdgeInsets.only(left: 2),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: day.eventColor ?? AppColors.brownAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            Text(
              day.adDay.toString(),
              style: TextStyle(fontSize: 10, color: adTextColor),
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _toNepaliNumber(int number) {
    const nepaliDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    return number.toString().split('').map((d) => nepaliDigits[int.parse(d)]).join('');
  }
}

/// Anchored popover listing the events on a tapped calendar day. Each row
/// (title + category) is clickable and opens the [EventDetailScreen].
void showDayEventsPopover(BuildContext cellContext, List<CulturalEvent> events) {
  final overlay = Overlay.of(cellContext);
  final box = cellContext.findRenderObject() as RenderBox?;
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (box == null || overlayBox == null) return;

  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
  final size = box.size;
  final screen = overlayBox.size;
  final isDark = Theme.of(cellContext).brightness == Brightness.dark;
  final accent = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);

  const popWidth = 250.0;
  final centerX = topLeft.dx + size.width / 2;
  final left = (centerX - popWidth / 2).clamp(12.0, screen.width - popWidth - 12.0);

  final estHeight = (44.0 + events.length * 52.0).clamp(80.0, 280.0);
  final belowY = topLeft.dy + size.height + 6;
  final top = (belowY + estHeight <= screen.height - 12)
      ? belowY
      : (topLeft.dy - estHeight - 6).clamp(12.0, screen.height - estHeight - 12);

  late OverlayEntry entry;
  void close() => entry.remove();

  entry = OverlayEntry(
    builder: (_) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: close),
        ),
        Positioned(
          left: left,
          top: top,
          width: popWidth,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBgCard : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
                border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF0E6D2)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: Text(
                      events.length == 1 ? 'Event' : '${events.length} Events',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.4, color: accent),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 6),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? AppColors.darkBorder : const Color(0xFFF2ECE0)),
                      itemBuilder: (_, i) {
                        final e = events[i];
                        final dot = parseHexColor(e.color) ?? accent;
                        return InkWell(
                          onTap: () {
                            close();
                            Navigator.of(cellContext).push(
                              MaterialPageRoute(builder: (_) => EventDetailScreen(event: e)),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    e.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(cellContext).colorScheme.onSurface),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: dot.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
                                  child: Text(e.eventType, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: dot)),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right, size: 16, color: isDark ? AppColors.darkTextTertiary : Colors.grey),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  overlay.insert(entry);
}

class _EventListCard extends StatelessWidget {
  final String title;
  final String date;
  final String location;
  /// Compact "1.2 km" chip; null hides it (no GPS fix or event lacks coords).
  final String? distance;
  final String tag;
  final String imageUrl;
  final String shortDescription;
  final VoidCallback? onTap;

  const _EventListCard({
    required this.title,
    required this.date,
    required this.location,
    required this.distance,
    required this.tag,
    this.imageUrl = '',
    this.shortDescription = '',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 80,
                height: 80,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.darkBgCard,
                  borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
                ),
                child: imageUrl.isNotEmpty
                    ? AppNetworkImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: Icon(Icons.music_note, color: Theme.of(context).brightness == Brightness.light ? AppColors.brownDark : AppColors.goldMain, size: 40),
                      )
                    : Icon(Icons.music_note, color: Theme.of(context).brightness == Brightness.light ? AppColors.brownDark : AppColors.goldMain, size: 40),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$date • $location',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).brightness == Brightness.light ? AppColors.textSecondary : AppColors.darkTextSecondary),
                    ),
                    if (shortDescription.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        shortDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, height: 1.35, color: Theme.of(context).brightness == Brightness.light ? AppColors.textTertiary : AppColors.darkTextTertiary),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (distance != null) ...[
                          _Badge(icon: Icons.location_on, label: distance!),
                          const SizedBox(width: 8),
                        ],
                        _Badge(label: tag),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 24, color: Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.darkBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: const [
              Text(
                'View Details',
                style: TextStyle(
                  color: AppColors.brownAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 18, color: AppColors.brownAccent),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData? icon;
  final String label;

  const _Badge({this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.darkBgCard,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
        border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Theme.of(context).brightness == Brightness.light ? AppColors.brownDark : AppColors.goldMain),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.light ? AppColors.textSecondary : AppColors.darkTextSecondary),
          ),
        ],
      ),
    );
  }
}







