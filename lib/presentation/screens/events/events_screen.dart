import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';
import 'package:sampada/providers/event_provider.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
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
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: eventProvider.events.length,
                itemBuilder: (context, index) {
                  final event = eventProvider.events[index];
                  return _EventListCard(
                    title: event.title,
                    date: '${eventProvider.selectedMonthName} ${event.startDate.day}',
                    location: event.locationName,
                    distance: '5.6 km',
                    tag: event.eventType,
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
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brownDeep, Color(0xFF9E3D1A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
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
                borderRadius: BorderRadius.circular(25),
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
        borderRadius: BorderRadius.circular(24),
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
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
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
                          borderRadius: BorderRadius.circular(10),
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

    return Opacity(
      opacity: day.isCurrentMonth ? 1.0 : 0.3,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
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
                    decoration: const BoxDecoration(
                      color: AppColors.brownAccent,
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
    );
  }

  String _toNepaliNumber(int number) {
    const nepaliDigits = ['०', '१', '२', '३', '४', '५', '६', '७', '८', '९'];
    return number.toString().split('').map((d) => nepaliDigits[int.parse(d)]).join('');
  }
}

class _EventListCard extends StatelessWidget {
  final String title;
  final String date;
  final String location;
  final String distance;
  final String tag;

  const _EventListCard({
    required this.title,
    required this.date,
    required this.location,
    required this.distance,
    required this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
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
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.darkBgCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.music_note, color: Theme.of(context).brightness == Brightness.light ? AppColors.brownDark : AppColors.goldMain, size: 40), // Placeholder for image
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Badge(icon: Icons.location_on, label: distance),
                        const SizedBox(width: 8),
                        _Badge(label: tag),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Divider(height: 24, color: Theme.of(context).brightness == Brightness.light ? AppColors.bgCream : AppColors.darkBorder),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'View Details',
              style: TextStyle(
                color: AppColors.brownAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(10),
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







