import 'package:flutter/material.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/data/datasources/local/notification_local_datasource.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';
import 'package:sampada/presentation/screens/guides/chat_screen.dart';
import 'package:sampada/presentation/screens/payments/guide_confirm_payment_screen.dart';
import 'package:sampada/presentation/screens/payments/payment_receipt_screen.dart';
import 'package:sampada/presentation/screens/payments/payment_screen.dart';
import 'package:sampada/providers/guide_provider.dart';
import 'package:sampada/providers/notification_provider.dart';

/// What a notification *is*, for icons and routing.
///
/// Prefer the `type` inside the data payload over the row's own `type` column:
/// the backend files chat messages under the booking type (its `_notify_user`
/// helper hardcodes `TYPE_BOOKING`), but stamps the real kind — `chat` — into
/// `data`, which is the same key FCM routes on. Falls back to the column for
/// notifications that carry no data.
String notificationKind(LocalNotification n) {
  final fromData = n.data['type']?.toString();
  return (fromData == null || fromData.isEmpty) ? n.type : fromData;
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.kColorDeep, AppColors.kColorPrimaryMid, AppColors.kColorPrimary],
                stops: [0.0, 0.6, 1.0],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
                bottomRight: Radius.circular(AppDimensions.kRadiusXxl),
              ),
            ),
            // Sizes to its content instead of a fixed screen-height fraction.
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(
                          l10n.notifTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.read<NotificationProvider>().markAllRead(),
                          child: Text(
                            l10n.notifMarkAllRead,
                            style: const TextStyle(color: AppColors.kColorAccentLight, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFilterChip(l10n.notifFilterAll, 'All'),
                        _buildFilterChip(l10n.notifFilterEvents, 'event'),
                        _buildFilterChip('Heritage', 'heritage'),
                        _buildFilterChip('Alerts', 'system'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: Consumer<NotificationProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 7,
                    itemBuilder: (context, _) => const NotificationCardSkeleton(),
                  );
                }

                final filtered = _selectedFilter == 'All'
                    ? provider.notifications
                    : provider.notifications
                        .where((n) => _matchesFilter(notificationKind(n)))
                        .toList();

                if (filtered.isEmpty) {
                  return _buildEmpty(isDark);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final n = filtered[index];
                    return _NotificationCard(
                      notification: n,
                      isDark: isDark,
                      onTap: () {
                        context.read<NotificationProvider>().markRead(n.id);
                        _navigate(n);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  // The "Heritage" tab groups both new-site announcements and proximity alerts.
  bool _matchesFilter(String type) {
    if (_selectedFilter == 'heritage') {
      return type == 'heritage' || type == 'geofence';
    }
    return type == _selectedFilter;
  }

  void _navigate(LocalNotification n) {
    switch (notificationKind(n)) {
      // New-site + proximity alerts open that heritage site's detail page.
      case 'heritage':
      case 'geofence':
        final slug = n.data['site_slug']?.toString();
        if (slug != null && slug.isNotEmpty) {
          Navigator.pushNamed(context, AppStrings.heritageDetailsPath, arguments: {'slug': slug});
        } else {
          Navigator.pushNamed(context, AppStrings.homePath);
        }
      case 'event':
      case 'event_reminder':
        Navigator.pushNamed(context, AppStrings.eventsPath);
      // A chat notification means someone replied — open that conversation.
      // ChatScreen resolves who it is from the channel, since the notification
      // only carries the booking id.
      case 'chat':
        final bookingId = int.tryParse('${n.data['booking_id']}');
        if (bookingId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatScreen(bookingId: bookingId)),
          );
        } else {
          Navigator.pushNamed(context, AppStrings.messagesPath);
        }
      // Booking updates reach both sides of a booking, so send each to the
      // screen that holds their side of it: a guide's requests, tours and
      // history live in the guide profile, not in My Bookings.
      case 'booking':
        // Payment notifications are booking notifications with an action. They
        // name one payment, so they open that payment rather than a list the
        // user then has to search.
        final paymentId = int.tryParse('${n.data['payment_id']}');
        final bookingId = int.tryParse('${n.data['booking_id']}');
        final action = '${n.data['action'] ?? ''}';
        if (paymentId != null) {
          switch (action) {
            case 'payment_submitted':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GuideConfirmPaymentScreen(paymentId: paymentId),
                ),
              );
              return;
            case 'payment_confirmed':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentReceiptScreen(paymentId: paymentId),
                ),
              );
              return;
            case 'payment_rejected':
              if (bookingId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PaymentScreen(bookingId: bookingId),
                  ),
                );
                return;
              }
          }
        }

        // Route on the server-provided audience, not a role guess (see the
        // notification service for why). Fallback to the guess only for legacy
        // rows without an audience field.
        final audience = '${n.data['audience'] ?? ''}';
        final bool isGuide;
        if (audience == 'guide') {
          isGuide = true;
        } else if (audience == 'tourist') {
          isGuide = false;
        } else {
          isGuide = context.read<GuideProvider>().myProfile?['status'] == 'approved';
        }
        Navigator.pushNamed(
          context,
          isGuide ? AppStrings.guideProfilePath : AppStrings.myBookingsPath,
        );
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.kColorAccentLight : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 64, color: isDark ? AppColors.darkTextSecondary : const Color(0xFFB08060)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.emptyNotifications,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final LocalNotification notification;
  final bool isDark;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.isDark,
    required this.onTap,
  });

  /// Cover image (event/heritage) when the notification carries one, else the
  /// type icon.
  Widget _leading(bool isDark) {
    final img = notification.data['image_url'];
    if (img is String && img.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
        child: AppNetworkImage(
          url: img,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorWidget: _iconBox(isDark),
        ),
      );
    }
    return _iconBox(isDark);
  }

  Widget _iconBox(bool isDark) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgCard : AppColors.kColorTagBg,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
        ),
        child: Icon(_icon,
            color: isDark ? AppColors.goldMain : AppColors.kColorTextHeading,
            size: 26),
      );

  IconData get _icon => switch (notificationKind(notification)) {
        'event' || 'event_reminder' => Icons.event,
        'geofence' => Icons.location_on,
        'heritage' => Icons.account_balance,
        'review' => Icons.star,
        'booking' => Icons.event_note,
        'chat' => Icons.chat_bubble,
        _ => Icons.notifications,
      };

  Color get _accent => switch (notificationKind(notification)) {
        'event' || 'event_reminder' => Colors.orange,
        'geofence' => Colors.teal,
        'heritage' => AppColors.kColorPrimaryMid,
        'review' => Colors.amber,
        'booking' => AppColors.statusSuccess,
        'chat' => AppColors.kColorPrimary,
        _ => AppColors.kColorPrimaryMid,
      };

  String get _subtitle {
    final type = switch (notificationKind(notification)) {
      'event' || 'event_reminder' => 'Event reminder',
      'geofence' => 'Nearby heritage',
      'heritage' => 'New heritage site',
      'chat' => 'Message',
      'review' => 'Review',
      'booking' => 'Booking update',
      _ => 'System',
    };
    final dt = notification.receivedAt;
    final formatted = '${dt.day}/${dt.month}/${dt.year}';
    return '$type • $formatted';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Theme.of(context).colorScheme.surface
              : (isDark
                  ? const Color(0xFF2A1A0A)
                  : const Color(0xFFFFF8EE)),
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.kColorBorderCream,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: notification.isRead ? Colors.transparent : _accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppDimensions.kRadiusXxl),
                    bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      _leading(isDark),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              notification.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.kColorTextMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _subtitle,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : const Color(0xFFB08060),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: AppColors.kColorAccentLight,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
