import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/screens/payments/payment_screen.dart';
import 'package:sampada/presentation/screens/reviews/write_review_sheet.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';
import 'package:sampada/providers/guide_provider.dart';

/// Shared building blocks for the bookings feature — the list screen and the
/// detail screen render the same booking with the same chips, avatar, cards and
/// action flows, so they live here rather than being duplicated in both.
///
/// Every colour comes from an [AppColors] token (or an alpha of one) and every
/// text style from the app [TextTheme]; nothing here introduces new design.

// ── Theme-derived helpers ────────────────────────────────────────────────────

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Muted/secondary/border colours that respect dark mode, using existing tokens.
Color bookingMuted(BuildContext c) =>
    _isDark(c) ? AppColors.kDarkTextMuted : AppColors.kColorTextMuted;
Color bookingSecondary(BuildContext c) =>
    _isDark(c) ? AppColors.kDarkTextSecond : AppColors.kColorTextSecondary;
Color bookingBorder(BuildContext c) =>
    _isDark(c) ? AppColors.kDarkBorder : AppColors.kColorBorderSubtle;

// ── Value helpers ────────────────────────────────────────────────────────────

/// DRF renders DecimalFields (`rating_avg`, `total_price`, …) as JSON strings —
/// parse tolerantly instead of casting, so "4.9", 4.9 and null all work.
double? asDoubleOrNull(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('$v');

int? asIntOrNull(dynamic v) => v is num ? v.toInt() : int.tryParse('$v');

/// Trims trailing zeros: 2500.0 → "2,500", 2500.5 → "2,500.5".
String money(num v) {
  final whole = v == v.roundToDouble();
  final s = whole ? v.toInt().toString() : v.toStringAsFixed(2);
  final parts = s.split('.');
  final digits = parts.first;
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return parts.length > 1 ? '${buf.toString()}.${parts[1]}' : buf.toString();
}

/// Human booking reference, derived from the primary key (the backend stores no
/// separate reference column, so this is a stable display format, not new data).
String bookingRef(Map<String, dynamic> b) =>
    'BK-${'${b['id'] ?? ''}'.padLeft(5, '0')}';

String bookingTimeRange(Map<String, dynamic> b) {
  String hhmm(dynamic v) {
    final s = '$v';
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  return '${hhmm(b['start_time'])} – ${hhmm(b['end_time'])}';
}

String bookingStartTime(Map<String, dynamic> b) {
  final s = '${b['start_time']}';
  return s.length >= 5 ? s.substring(0, 5) : s;
}

int bookingGroupSize(Map<String, dynamic> b) => asIntOrNull(b['group_size']) ?? 1;

String bookingPackageLabel(Map<String, dynamic> b) =>
    (b['package_label'] ?? '').toString();

/// "Half Day · 6 people" — package + group summary, or null for a legacy hourly
/// booking taken solo (nothing worth a line of its own).
String? bookingPackageLine(Map<String, dynamic> b) {
  final label = bookingPackageLabel(b);
  final size = bookingGroupSize(b);
  final parts = <String>[
    if (label.isNotEmpty) label,
    if (size > 1) '$size people',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "12 Jul 2026" from an ISO timestamp or a plain yyyy-MM-dd date.
String? formatBookingDate(dynamic iso) {
  if (iso == null) return null;
  final dt = DateTime.tryParse('$iso')?.toLocal();
  if (dt == null) return null;
  return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
}

DateTime? bookingTourDate(Map<String, dynamic> b) =>
    DateTime.tryParse('${b['date']}');

/// Whole days from today until the tour (negative once it's past).
int? bookingDaysUntil(Map<String, dynamic> b) {
  final d = bookingTourDate(b);
  if (d == null) return null;
  final now = DateTime.now();
  return DateTime(d.year, d.month, d.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
}

/// The guide package this booking was taken on, matched by the label snapshotted
/// at booking time. Null for legacy hourly bookings, or when the guide record
/// isn't loaded (the list can render before `fetchGuides` lands).
({String label, double? hours, double? price})? bookingPackageOf(
    Map<String, dynamic> booking, Map<String, dynamic>? guide) {
  final label = bookingPackageLabel(booking);
  if (label.isEmpty || guide == null) return null;
  final packages = guide['packages'];
  if (packages is! List) return null;
  for (final p in packages) {
    if (p is Map && '${p['label']}' == label) {
      return (
        label: label,
        hours: asDoubleOrNull(p['hours']),
        price: asDoubleOrNull(p['price']),
      );
    }
  }
  return (label: label, hours: null, price: null);
}

/// What the total is actually made of. The server is authoritative for [total];
/// the parts are reconstructed from the guide's package + group pricing so the
/// tourist can see how the number was reached.
class BookingPriceBreakdown {
  final double? packagePrice;
  final int extraPeople;
  final double extraPersonFee;
  final double? total;

  const BookingPriceBreakdown({
    this.packagePrice,
    this.extraPeople = 0,
    this.extraPersonFee = 0,
    this.total,
  });

  double get extraCharge => extraPeople * extraPersonFee;

  /// True when the parts add up to the server total — only then is it honest to
  /// show a line-by-line breakdown rather than just the total.
  bool get isItemised =>
      packagePrice != null &&
      total != null &&
      ((packagePrice! + extraCharge) - total!).abs() < 0.01;

  factory BookingPriceBreakdown.of(
      Map<String, dynamic> booking, Map<String, dynamic>? guide) {
    final pkg = bookingPackageOf(booking, guide);
    final included = asIntOrNull(guide?['included_group_size']) ?? 0;
    final fee = asDoubleOrNull(guide?['extra_person_fee']) ?? 0;
    final extras = (bookingGroupSize(booking) - included).clamp(0, 1 << 30);
    return BookingPriceBreakdown(
      packagePrice: pkg?.price,
      extraPeople: extras,
      extraPersonFee: fee,
      total: asDoubleOrNull(booking['total_price']),
    );
  }
}

// ── Status + payment chips ───────────────────────────────────────────────────

typedef StatusMeta = ({Color bg, Color fg, IconData icon, String label});

/// Every booking status the platform can express, mapped onto existing semantic
/// tokens. The backend currently only emits pending/confirmed/completed/
/// cancelled; the rest are here so a future status renders correctly instead of
/// falling through to a generic chip.
StatusMeta bookingStatusMeta(String status) => switch (status) {
      'confirmed' || 'accepted' => (
          bg: AppColors.kColorOfflineBg,
          fg: AppColors.kColorOfflineText,
          icon: Icons.verified_outlined,
          label: status == 'accepted' ? 'Accepted' : 'Confirmed',
        ),
      'tour_started' || 'in_progress' => (
          bg: AppColors.kColorPrimary.withValues(alpha: 0.12),
          fg: AppColors.kColorPrimary,
          icon: Icons.directions_walk,
          label: 'Tour Started',
        ),
      'completed' => (
          bg: AppColors.statusInfo.withValues(alpha: 0.12),
          fg: AppColors.statusInfo,
          icon: Icons.check_circle_outline,
          label: 'Completed',
        ),
      'cancelled' => (
          bg: AppColors.statusError.withValues(alpha: 0.10),
          fg: AppColors.statusError,
          icon: Icons.cancel_outlined,
          label: 'Cancelled',
        ),
      'rejected' => (
          bg: AppColors.statusError.withValues(alpha: 0.10),
          fg: AppColors.statusError,
          icon: Icons.block,
          label: 'Rejected',
        ),
      'refunded' => (
          bg: AppColors.statusWarning.withValues(alpha: 0.12),
          fg: AppColors.statusWarning,
          icon: Icons.undo,
          label: 'Refunded',
        ),
      _ => (
          bg: AppColors.kColorPendingBg,
          fg: AppColors.kColorPendingText,
          icon: Icons.hourglass_top,
          label: 'Pending',
        ),
    };

/// Null when there is nothing owed yet (`payment_status == none`) — the chip is
/// simply not shown in that case.
///
/// The four states the backend actually emits: `due` (the tour is over, the
/// money is not sent), `submitted` (the tourist says they paid and the guide has
/// not answered), `rejected` (the guide could not find it), `paid` (the guide
/// confirmed). Only that last one means settled — the tourist can no longer put
/// a booking there on their own word.
StatusMeta? bookingPaymentMeta(Map<String, dynamic> b) {
  final status = (b['payment_status'] ?? 'none').toString();
  final method = b['payment_method']?.toString();
  return switch (status) {
    'paid' => (
        bg: AppColors.kColorOfflineBg,
        fg: AppColors.kColorOfflineText,
        icon: Icons.payments_outlined,
        label: (method == null || method.isEmpty) ? 'Paid' : 'Paid · $method',
      ),
    'submitted' => (
        bg: AppColors.statusInfo.withValues(alpha: 0.12),
        fg: AppColors.statusInfo,
        icon: Icons.hourglass_top,
        label: 'Awaiting guide',
      ),
    'rejected' => (
        bg: AppColors.statusError.withValues(alpha: 0.10),
        fg: AppColors.statusError,
        icon: Icons.error_outline,
        label: 'Payment disputed',
      ),
    'due' => (
        bg: AppColors.kColorPendingBg,
        fg: AppColors.kColorPendingText,
        icon: Icons.schedule,
        label: 'Payment due',
      ),
    _ => null,
  };
}

/// Small pill used for status, payment and package. Animates on change so a
/// status flipping under the user reads as a transition, not a jump.
class BookingChip extends StatelessWidget {
  final StatusMeta meta;
  const BookingChip({super.key, required this.meta});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sp10, vertical: AppDimensions.sp4),
      decoration: BoxDecoration(
        color: meta.bg,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 13, color: meta.fg),
          const SizedBox(width: AppDimensions.sp4),
          Text(
            meta.label,
            style: t.bodySmall?.copyWith(
                color: meta.fg, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Status + payment (+ optional package) chips in one wrap.
class BookingChipRow extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool showPackage;
  const BookingChipRow({super.key, required this.booking, this.showPackage = false});

  @override
  Widget build(BuildContext context) {
    final payment = bookingPaymentMeta(booking);
    final label = bookingPackageLabel(booking);
    return Wrap(
      spacing: AppDimensions.sp8,
      runSpacing: AppDimensions.sp8,
      children: [
        BookingChip(
            meta: bookingStatusMeta((booking['status'] ?? 'pending').toString())),
        if (payment != null) BookingChip(meta: payment),
        if (showPackage && label.isNotEmpty)
          BookingChip(
            meta: (
              bg: AppColors.kColorTagBg,
              fg: AppColors.kColorAccentDark,
              icon: Icons.tour_outlined,
              label: label,
            ),
          ),
      ],
    );
  }
}

// ── Guide avatar (hero) ──────────────────────────────────────────────────────

/// Guide photo with a verified badge, shared as the Hero between the card and
/// the detail header. Falls back to a gradient monogram when the guide has no
/// photo or the image fails.
class BookingGuideAvatar extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool verified;
  final String heroTag;
  final double size;

  const BookingGuideAvatar({
    super.key,
    required this.booking,
    required this.verified,
    required this.heroTag,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    final name = (booking['guide_name'] ?? 'G').toString();
    final photo = booking['guide_photo']?.toString();
    final t = Theme.of(context).textTheme;

    final monogram = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.avatarGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'G',
        style: t.titleMedium?.copyWith(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: AppColors.kColorTextOnPrimary,
        ),
      ),
    );

    final avatar = (photo == null || photo.isEmpty)
        ? monogram
        : ClipOval(
            child: AppNetworkImage(
              url: photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: monogram,
            ),
          );

    return Hero(
      tag: heroTag,
      child: SizedBox(
        width: size + 4,
        height: size + 4,
        child: Stack(
          children: [
            avatar,
            if (verified)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.verified,
                      size: size * 0.3, color: AppColors.kColorAccentLight),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Layout primitives ────────────────────────────────────────────────────────

/// The app's standard surface card: theme surface, subtle border, card shadow.
class BookingCardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const BookingCardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.sp16),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppDimensions.kRadiusXl);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: radius,
        border: Border.all(color: bookingBorder(context)),
        boxShadow: _isDark(context) ? null : AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Titled section on the detail screen: accent icon + Cinzel label + content.
class BookingSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  const BookingSection({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return BookingCardShell(
      margin: const EdgeInsets.only(bottom: AppDimensions.sp14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.kColorAccentSafe),
              const SizedBox(width: AppDimensions.sp6),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: t.labelSmall?.copyWith(color: bookingMuted(context)),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppDimensions.sp10),
          child,
        ],
      ),
    );
  }
}

/// Label ↔ value row used by Booking Information, Price Breakdown, Group Details.
class BookingKeyValue extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasise;
  final Color? valueColor;

  const BookingKeyValue({
    super.key,
    required this.label,
    required this.value,
    this.emphasise = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sp4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: t.bodySmall?.copyWith(color: bookingSecondary(context))),
          ),
          const SizedBox(width: AppDimensions.sp12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: (emphasise ? t.titleSmall : t.bodyMedium)?.copyWith(
                fontWeight: emphasise ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline notice: payment due, guide accepted, tour tomorrow, review pending,
/// offline. Tinted with the token colour it carries.
class BookingBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Color bg;
  final Color fg;
  final Widget? action;

  const BookingBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.bg,
    required this.fg,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sp12),
      padding: const EdgeInsets.all(AppDimensions.sp12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppDimensions.iconMd, color: fg),
          const SizedBox(width: AppDimensions.sp12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: t.bodyMedium
                        ?.copyWith(color: fg, fontWeight: FontWeight.w700)),
                if (message != null)
                  Text(message!, style: t.bodySmall?.copyWith(color: fg)),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppDimensions.sp8),
            action!,
          ],
        ],
      ),
    );
  }
}

// ── Loading / empty / error ──────────────────────────────────────────────────

/// Skeleton that mirrors the real card's silhouette (avatar, two text lines,
/// meta row, chips) so the swap to content doesn't shift the layout.
class BookingCardSkeleton extends StatelessWidget {
  const BookingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return BookingCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerSkeleton(width: 52, height: 52, borderRadius: 26),
              const SizedBox(width: AppDimensions.sp12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerSkeleton(width: 140, height: 14, borderRadius: 4),
                  SizedBox(height: AppDimensions.sp8),
                  ShimmerSkeleton(width: 90, height: 11, borderRadius: 4),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sp16),
          const ShimmerSkeleton(
              width: double.infinity, height: 12, borderRadius: 4),
          const SizedBox(height: AppDimensions.sp12),
          Row(
            children: const [
              ShimmerSkeleton(width: 90, height: 24, borderRadius: 50),
              SizedBox(width: AppDimensions.sp8),
              ShimmerSkeleton(width: 110, height: 24, borderRadius: 50),
            ],
          ),
        ],
      ),
    );
  }
}

/// Empty state: heritage-flavoured mark, a line of copy, and the app's primary
/// CTA. [onAction] is omitted for the filtered/other tabs, where a CTA is noise.
class BookingEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const BookingEmptyView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.sp32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isDark(context)
                    ? AppColors.kDarkBgCard
                    : AppColors.kColorBgWarm,
              ),
              child: Icon(icon,
                  size: 44,
                  color: _isDark(context)
                      ? AppColors.kColorAccentLight
                      : AppColors.kColorAccent),
            ),
            const SizedBox(height: AppDimensions.sp20),
            Text(title,
                textAlign: TextAlign.center,
                style: t.titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            if (message != null) ...[
              const SizedBox(height: AppDimensions.sp8),
              Text(message!,
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(color: bookingMuted(context))),
            ],
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: AppDimensions.sp20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.explore_outlined,
                    size: AppDimensions.iconSm),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Failed load: same silhouette as the empty state, with a retry.
class BookingErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const BookingErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.sp32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.statusError.withValues(alpha: 0.10),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 44, color: AppColors.statusError),
            ),
            const SizedBox(height: AppDimensions.sp20),
            Text("Couldn't load your bookings",
                textAlign: TextAlign.center,
                style: t.titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: AppDimensions.sp8),
            Text(message,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall?.copyWith(color: bookingMuted(context))),
            const SizedBox(height: AppDimensions.sp20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: AppDimensions.iconSm),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Staggered fade + rise used for list items and timeline steps.
class BookingFadeIn extends StatelessWidget {
  final int index;
  final Widget child;
  const BookingFadeIn({super.key, this.index = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + (index.clamp(0, 8) * 60)),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
            offset: Offset(0, (1 - value) * 16), child: child),
      ),
      child: child,
    );
  }
}

// ── Timeline ─────────────────────────────────────────────────────────────────

class _TimelineStep {
  final String label;
  final String? timestamp;
  final bool done;
  final bool terminal;
  const _TimelineStep(this.label, this.timestamp, this.done,
      {this.terminal = false});
}

/// Vertical animated timeline built from the booking's real timestamps. Steps
/// the backend does not record (a distinct "tour started", say) are not invented
/// — every row here corresponds to a field that actually exists.
class BookingTimeline extends StatelessWidget {
  final Map<String, dynamic> booking;
  const BookingTimeline({super.key, required this.booking});

  List<_TimelineStep> _steps() {
    final status = '${booking['status']}';
    final steps = <_TimelineStep>[
      _TimelineStep('Booking created', booking['created_at']?.toString(), true),
    ];

    if (status == 'cancelled' || status == 'rejected') {
      steps.add(_TimelineStep(
        status == 'rejected' ? 'Guide declined' : 'Booking cancelled',
        booking['updated_at']?.toString(),
        true,
        terminal: true,
      ));
      return steps;
    }

    final accepted = status == 'confirmed' || status == 'completed';
    steps
      ..add(_TimelineStep('Guide accepted', null, accepted))
      ..add(_TimelineStep(
          'Guide marked tour done',
          booking['guide_marked_complete_at']?.toString(),
          booking['guide_marked_complete_at'] != null))
      ..add(_TimelineStep(
          'You confirmed completion',
          booking['tourist_confirmed_complete_at']?.toString(),
          booking['tourist_confirmed_complete_at'] != null ||
              status == 'completed'))
      ..add(_TimelineStep(
          booking['receipt_no'] != null
              ? 'Payment settled · ${booking['receipt_no']}'
              : 'Payment settled',
          booking['paid_at']?.toString(),
          booking['payment_status'] == 'paid'))
      ..add(_TimelineStep('Review submitted',
          booking['reviewed_at']?.toString(), booking['reviewed_at'] != null));
    return steps;
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps();
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          BookingFadeIn(
            index: i,
            child: _row(context, steps[i], isLast: i == steps.length - 1),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, _TimelineStep step, {required bool isLast}) {
    final t = Theme.of(context).textTheme;
    final done = step.done;
    final Color dot = step.terminal
        ? AppColors.statusError
        : done
            ? AppColors.statusSuccess
            : bookingBorder(context);
    final time = formatBookingDate(step.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || step.terminal ? dot : Colors.transparent,
                  border: Border.all(color: dot, width: 2),
                ),
                child: step.terminal
                    ? const Icon(Icons.close,
                        size: 11, color: AppColors.kColorTextOnPrimary)
                    : done
                        ? const Icon(Icons.check,
                            size: 11, color: AppColors.kColorTextOnPrimary)
                        : null,
              ),
              if (!isLast)
                Expanded(
                    child: Container(width: 2, color: bookingBorder(context))),
            ],
          ),
          const SizedBox(width: AppDimensions.sp12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppDimensions.sp16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label,
                    style: t.bodyMedium?.copyWith(
                      fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                      color: done || step.terminal
                          ? Theme.of(context).colorScheme.onSurface
                          : bookingMuted(context),
                    ),
                  ),
                  if (time != null)
                    Text(time,
                        style:
                            t.bodySmall?.copyWith(color: bookingMuted(context))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared action flows ──────────────────────────────────────────────────────

/// The cancel / pay / review flows, shared so the card's quick actions and the
/// detail screen's buttons behave identically. All of them go through
/// [GuideProvider], which refetches and notifies on success.
class BookingActions {
  BookingActions._();

  static bool canChat(Map<String, dynamic> b) =>
      b['status'] == 'confirmed' || b['status'] == 'completed';

  static bool awaitingConfirm(Map<String, dynamic> b) =>
      b['status'] == 'confirmed' &&
      b['guide_marked_complete_at'] != null &&
      b['tourist_confirmed_complete_at'] == null;

  /// The tourist owes money and can act on it. `submitted` is deliberately not
  /// here: they have paid and are waiting on the guide, and offering "Pay Now"
  /// again is how someone pays twice. `rejected` is — the guide could not find
  /// the payment, so it is owed again.
  static bool paymentDue(Map<String, dynamic> b) =>
      b['payment_status'] == 'due' || b['payment_status'] == 'rejected';

  /// A claim is in, and the guide has not answered it yet.
  static bool paymentAwaitingGuide(Map<String, dynamic> b) =>
      b['payment_status'] == 'submitted';

  static bool canReview(Map<String, dynamic> b) =>
      b['status'] == 'completed' && b['reviewed_at'] == null;

  static bool canCancel(Map<String, dynamic> b) =>
      b['status'] == 'pending' ||
      (b['status'] == 'confirmed' && !awaitingConfirm(b));

  static Future<void> confirmCancel(
      BuildContext context, Map<String, dynamic> booking) async {
    final gp = context.read<GuideProvider>();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final t = Theme.of(context).textTheme;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
        title: Text('Cancel this booking?',
            style: t.titleMedium
                ?.copyWith(color: Theme.of(ctx).colorScheme.onSurface)),
        content: Text('The guide will be notified. This cannot be undone.',
            style: t.bodyMedium
                ?.copyWith(color: Theme.of(ctx).colorScheme.onSurface)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Booking',
                style: TextStyle(color: bookingSecondary(ctx))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.statusError,
                foregroundColor: AppColors.kColorTextOnPrimary),
            child: Text(l10n.btnConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await gp.updateBookingStatus(booking['id'] as int, 'cancelled');
    messenger.showSnackBar(const SnackBar(content: Text('Booking cancelled.')));
  }

  static Future<void> completeTour(
      BuildContext context, Map<String, dynamic> booking) async {
    final gp = context.read<GuideProvider>();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final err = await gp.completeTour(booking['id'] as int, asGuide: false);
    messenger.showSnackBar(
        SnackBar(content: Text(err ?? l10n.tourConfirmedSettle)));
  }

  /// Opens the payment screen for this booking.
  ///
  /// This used to be a bottom sheet in which the tourist picked a method from a
  /// hardcoded list and the booking went straight to `paid` — with no idea of
  /// the guide's actual account and no confirmation from them. Paying is now a
  /// screen of its own: it shows the guide's published wallet details, the
  /// tourist submits proof, and the guide confirms it.
  static Future<void> openPayment(
      BuildContext context, Map<String, dynamic> booking) async {
    final guides = context.read<GuideProvider>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          bookingId: booking['id'] as int,
          booking: booking,
        ),
      ),
    );
    // The booking's payment_status has very likely moved (due → submitted, or
    // rejected → submitted); the list behind this screen must not keep showing
    // "Pay Now".
    await guides.fetchMyBookings();
  }

  /// Rate the guide for a completed booking. Delegates to the one write-review
  /// sheet in the app (overall stars + optional per-category scores), so a review
  /// written from a booking card is the same thing as one written from the
  /// guide's reviews screen.
  static Future<void> openReviewDialog(
      BuildContext context, Map<String, dynamic> booking) async {
    final gp = context.read<GuideProvider>();
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final guideName = (booking['guide_name'] ?? 'this guide').toString();

    final draft = await showWriteReviewSheet(context, guideName: guideName);
    if (draft == null) return;

    final err = await gp.reviewBooking(
      booking['id'] as int,
      draft.rating,
      draft.text,
      categories: draft.categories,
    );
    messenger.showSnackBar(SnackBar(content: Text(err ?? l10n.reviewThanks)));
  }
}
