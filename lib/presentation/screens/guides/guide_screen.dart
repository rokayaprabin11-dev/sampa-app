import 'package:flutter/material.dart';
import 'package:sampada/core/services/location_service.dart';
import 'package:sampada/core/utils/geo_distance.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:sampada/presentation/widgets/shared/shimmer_loading.dart';
import 'package:sampada/providers/guide_provider.dart';
import 'package:sampada/providers/auth_provider.dart';
import 'package:sampada/presentation/screens/guides/chat_screen.dart';
import 'package:sampada/presentation/screens/guides/guide_detail_screen.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  String _selectedFilter = 'Nearby';
  final _searchController = TextEditingController();

  // Reference point for distance labels — populated only by a real
  // accuracy-gated GPS fix (cached 5 min in LocationService). Until then
  // labels stay hidden instead of showing a Kathmandu-based guess (same rule
  // as event and heritage cards).
  double? _refLat;
  double? _refLng;

  Future<void> _locateUser() async {
    final svc = LocationService();
    // Accuracy-gated fix first; degrade to the best poor fix, then to one raw
    // fix (emulator / indoors) — a rough real position beats no label. Only
    // permission denied / services off leaves labels hidden.
    final (fix, _) = await svc.getFixWithQuality();
    final pos = fix ?? await svc.getCurrentPosition();
    if (pos == null || !mounted) return;
    setState(() {
      _refLat = pos.latitude;
      _refLng = pos.longitude;
    });
  }

  static const _chips = ['Nearby', 'Top Rated', 'Temple Expert', 'Trekking', 'Culture', 'Language'];

  static const _langShort = {
    'english': 'EN',
    'nepali': 'नेपाली',
    'hindi': 'हिन्दी',
    'chinese': '中文',
    'japanese': '日本語',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locateUser(); // re-ranks distance labels when a real fix lands
      final gp = context.read<GuideProvider>();
      gp.fetchGuides();
      // Profile/bookings are per-user (auth required) — skip when logged out
      // to avoid 401 noise during the sign-out/sign-in transition.
      if (context.read<AuthProvider>().isAuthenticated) {
        gp.fetchMyBookings();  // gates the Review action
        gp.fetchMyProfile();   // detects the user's own guide card
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Data helpers ─────────────────────────────────────────────

  double _ratingOf(Map<String, dynamic> g) => double.tryParse('${g['rating_avg'] ?? ''}') ?? 0.0;
  int _reviewsOf(Map<String, dynamic> g) => (g['review_count'] as int?) ?? 0;

  /// Cheapest configured package price as a display string, or null when the
  /// guide has no packages (cards then fall back to the hourly rate).
  String? _cheapestPackagePrice(Map<String, dynamic> g) {
    final pkgs = g['packages'];
    if (pkgs is! List) return null;
    double? min;
    for (final p in pkgs) {
      if (p is Map) {
        final v = double.tryParse('${p['price']}');
        if (v != null && (min == null || v < min)) min = v;
      }
    }
    if (min == null) return null;
    return min.toStringAsFixed(min % 1 == 0 ? 0 : 2);
  }

  /// The server computes this at request time (never from its response cache):
  /// online == a fresh heartbeat AND the guide is accepting bookings, so a green
  /// dot always means "bookable right now", not merely "app is open".
  bool _isOnline(Map<String, dynamic> g) {
    final presence = g['presence'] as Map<String, dynamic>?;
    return presence?['status'] == 'online';
  }

  DateTime? _lastSeenOf(Map<String, dynamic> g) {
    final presence = g['presence'] as Map<String, dynamic>?;
    final raw = presence?['last_seen'] as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  /// "Online" when live, else "Last seen 12 min ago". Null when the guide has
  /// never been seen — better to show nothing than "last seen never".
  String? _presenceLabel(BuildContext context, Map<String, dynamic> g) {
    final l10n = AppLocalizations.of(context)!;
    if (_isOnline(g)) return l10n.presenceOnline;

    final seen = _lastSeenOf(g);
    if (seen == null) return null;

    final ago = DateTime.now().difference(seen);
    if (ago.inMinutes < 1) return l10n.presenceLastSeenJustNow;
    if (ago.inMinutes < 60) return l10n.presenceLastSeenMinutes(ago.inMinutes);
    if (ago.inHours < 24) return l10n.presenceLastSeenHours(ago.inHours);
    return l10n.presenceLastSeenDays(ago.inDays);
  }

  bool _isTopGuide(Map<String, dynamic> g) => _ratingOf(g) >= 4.5 && _reviewsOf(g) >= 10;

  double? _distanceKm(Map<String, dynamic> g) {
    if (_refLat == null || _refLng == null) return null;
    final lat = g['latitude'], lng = g['longitude'];
    if (lat is! num || lng is! num) return null;
    return GeoDistance.kmTo(_refLat!, _refLng!, lat.toDouble(), lng.toDouble());
  }

  String? _distanceLabel(Map<String, dynamic> g) {
    final km = _distanceKm(g);
    return km == null ? null : GeoDistance.shortLabel(km);
  }

  String _locationOf(Map<String, dynamic> g) {
    final areas = (g['areas'] as List?) ?? [];
    return areas.isNotEmpty ? areas.first.toString() : 'Nepal';
  }

  /// Search + chip filter, then sort so featured/nearby split is meaningful.
  List<Map<String, dynamic>> _process(List<Map<String, dynamic>> guides) {
    final q = _searchController.text.toLowerCase();
    var list = guides.where((g) {
      final user = g['user'] as Map<String, dynamic>? ?? {};
      final name = (user['full_name'] ?? user['username'] ?? '').toString().toLowerCase();
      final spec = ((g['specialties'] as List?) ?? []).join(' ').toLowerCase();
      final langs = ((g['languages'] as List?) ?? []).join(' ').toLowerCase();
      return q.isEmpty || name.contains(q) || spec.contains(q) || langs.contains(q);
    }).toList();

    bool specContains(Map<String, dynamic> g, List<String> needles) {
      final hay = ('${(g['specialties'] as List?) ?? []} ${(g['tour_types'] as List?) ?? []}').toLowerCase();
      return needles.any(hay.contains);
    }

    switch (_selectedFilter) {
      case 'Top Rated':
        list.sort((a, b) => _ratingOf(b).compareTo(_ratingOf(a)));
      case 'Temple Expert':
        list = list.where((g) => specContains(g, ['temple', 'stupa', 'durbar'])).toList();
      case 'Trekking':
        list = list.where((g) => specContains(g, ['trek', 'everest', 'mustang'])).toList();
      case 'Culture':
        list = list.where((g) => specContains(g, ['cultur', 'newari', 'festival', 'heritage'])).toList();
      case 'Language':
        list.sort((a, b) => ((b['languages'] as List?)?.length ?? 0).compareTo((a['languages'] as List?)?.length ?? 0));
      case 'Nearby':
      default:
        // Closest first when we have a real fix; guides without coordinates
        // (or before the fix arrives) fall back to rating order.
        list.sort((a, b) {
          final da = _distanceKm(a);
          final db = _distanceKm(b);
          if (da != null && db != null && da != db) return da.compareTo(db);
          if ((da == null) != (db == null)) return da == null ? 1 : -1;
          return _ratingOf(b).compareTo(_ratingOf(a));
        });
    }
    return list;
  }

  void _openDetail(Map<String, dynamic> guide) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GuideDetailScreen(guide: guide)),
      );

  /// True when this guide card belongs to the logged-in user (their own
  /// profile) — they can't hire or review themselves.
  bool _isSelf(Map<String, dynamic> guide) {
    final mine = context.read<GuideProvider>().myProfile;
    return mine != null && mine['id'] != null && mine['id'] == guide['id'];
  }

  /// True when the tourist has an unanswered request with this guide.
  bool _hasPending(Map<String, dynamic> guide) {
    final id = guide['id'];
    return id is int && context.read<GuideProvider>().hasPendingWith(id);
  }

  Widget _pendingBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.kColorPendingBg,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        border: Border.all(color: AppColors.kColorPendingBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_top, size: AppDimensions.iconSm, color: AppColors.kColorPendingText),
          const SizedBox(width: AppDimensions.sp6),
          Text(AppLocalizations.of(context)!.requestPending,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.kColorPendingText)),
        ],
      ),
    );
  }

  Widget _selfBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.kColorBgMuted,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: AppDimensions.iconSm, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary),
          const SizedBox(width: 6),
          Text(AppLocalizations.of(context)!.yourGuideProfile,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary)),
        ],
      ),
    );
  }

  /// The booking that authorizes a chat with this guide, or null if there is
  /// none — the guide must have accepted a request first.
  int? _chatBookingIdWith(Map<String, dynamic> guide) {
    final id = guide['id'];
    if (id is! int) return null;
    return context.read<GuideProvider>().chatBookingIdWith(id);
  }

  void _openChat(Map<String, dynamic> guide, int bookingId) {
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final name = (user['full_name'] ?? user['username'] ?? 'Guide').toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(bookingId: bookingId, otherPartyName: name),
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Reviews are tied to a completed booking. Find the tourist's completed,
  /// not-yet-reviewed booking with this guide, then open the rating dialog.
  Future<void> _reviewGuide(Map<String, dynamic> guide) async {
    final gp = context.read<GuideProvider>();
    final gid = guide['id'];

    Map<String, dynamic>? booking;
    for (final b in gp.myBookings) {
      if (b['guide'] == gid && b['status'] == 'completed' && b['reviewed_at'] == null) {
        booking = b;
        break;
      }
    }

    final l10n = AppLocalizations.of(context)!;
    if (booking == null) {
      // Distinguish "already reviewed" from "no completed tour" for clarity.
      final hasCompleted = gp.myBookings.any((b) => b['guide'] == gid && b['status'] == 'completed');
      _snack(hasCompleted ? l10n.reviewAlreadyDone : l10n.reviewAfterTour);
      return;
    }

    final result = await _showReviewDialog(guide);
    if (result == null) return; // cancelled

    final err = await gp.reviewBooking(booking['id'] as int, result.$1, result.$2);
    if (!mounted) return;
    if (err == null) {
      _snack(l10n.reviewThanks);
      gp.fetchGuides(); // refresh the guide's rating
    } else {
      _snack(l10n.reviewFailed(err));
    }
  }

  /// Returns (rating, text) or null if cancelled.
  Future<(int, String)?> _showReviewDialog(Map<String, dynamic> guide) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.goldMain : AppColors.kColorPrimary;
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final name = (user['full_name'] ?? user['username'] ?? 'this guide').toString();
    final controller = TextEditingController();
    int rating = 5;

    return showDialog<(int, String)?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
          title: Text(l10n.reviewGuide(name), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final filled = i < rating;
                  return IconButton(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    constraints: const BoxConstraints(),
                    onPressed: () => setLocal(() => rating = i + 1),
                    icon: Icon(filled ? Icons.star : Icons.star_border, color: isDark ? AppColors.goldMain : AppColors.kColorAccent, size: AppDimensions.iconXl),
                  );
                }),
              ),
              const SizedBox(height: AppDimensions.sp12),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 300,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: l10n.reviewHint,
                  hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : Colors.grey, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text(l10n.btnCancel, style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, (rating, controller.text.trim())),
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: isDark ? Colors.black : Colors.white),
              child: Text(l10n.btnSubmit),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────

  // ─── Post-tour actions: confirm completion, settle payment ────

  /// Bookings that need the tourist to act: the guide marked the tour done
  /// (counter-sign), or the tour is completed with payment still due.
  List<Map<String, dynamic>> _actionNeeded(GuideProvider gp) {
    return gp.myBookings.where((b) {
      final awaitingConfirm = b['status'] == 'confirmed' &&
          b['guide_marked_complete_at'] != null &&
          b['tourist_confirmed_complete_at'] == null;
      final paymentDue =
          b['status'] == 'completed' && b['payment_status'] == 'due';
      return awaitingConfirm || paymentDue;
    }).toList();
  }

  List<Widget> _actionNeededSlivers(
      BuildContext context, bool isDark, GuideProvider gp) {
    final items = _actionNeeded(gp);
    if (items.isEmpty) return const [];
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => _actionCard(context, isDark, items[i]),
          childCount: items.length,
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ];
  }

  Widget _actionCard(
      BuildContext context, bool isDark, Map<String, dynamic> b) {
    final l10n = AppLocalizations.of(context)!;
    final paymentDue = b['payment_status'] == 'due' && b['status'] == 'completed';
    final guideName = (b['guide_name'] ?? 'your guide').toString();
    final price = b['total_price'];
    final title = paymentDue ? l10n.payDueTitle : l10n.confirmTourTitle;
    final body = paymentDue
        ? '${l10n.payDueBody(guideName, '${b['date']}')}'
            '${price != null ? ' — NPR $price' : ''}'
        : l10n.confirmTourBody(guideName, '${b['date']}');

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.kColorPendingBg,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        border: Border.all(color: AppColors.kColorPendingBorder),
      ),
      child: Row(
        children: [
          Icon(paymentDue ? Icons.payments_outlined : Icons.task_alt,
              color: AppColors.kColorPendingText, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.kColorPendingText)),
                const SizedBox(height: 2),
                Text(body,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.kColorPendingText)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => paymentDue
                ? _openPaymentSheet(b)
                : _confirmCompletion(b),
            style: ElevatedButton.styleFrom(
              backgroundColor: paymentDue
                  ? AppColors.kColorPrimary
                  : const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(paymentDue ? l10n.btnPayNow : l10n.btnConfirm,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCompletion(Map<String, dynamic> b) async {
    final confirmedMsg = AppLocalizations.of(context)!.tourConfirmedSettle;
    final err = await context
        .read<GuideProvider>()
        .completeTour(b['id'] as int, asGuide: false);
    if (!mounted) return;
    _snack(err ?? confirmedMsg);
  }

  static const _paymentMethods = [
    ('esewa', 'eSewa', Icons.account_balance_wallet_outlined),
    ('khalti', 'Khalti', Icons.account_balance_wallet_outlined),
    ('fonepay', 'Fonepay', Icons.qr_code_2),
    ('cash', 'Cash', Icons.payments_outlined),
  ];

  Future<void> _openPaymentSheet(Map<String, dynamic> b) async {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final refController = TextEditingController();
    String method = 'esewa';
    bool submitting = false;
    final price = b['total_price'];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDimensions.kRadiusXxl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.paySheetTitle,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(ctx).colorScheme.onSurface)),
              const SizedBox(height: 4),
              Text(
                '${l10n.paySheetBody('${b['guide_name'] ?? 'your guide'}')}'
                '${price != null ? ' — NPR $price' : ''}',
                style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ..._paymentMethods.map((m) {
                final selected = method == m.$1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setLocal(() => method = m.$1),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.kRadiusLg),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.kColorPrimary.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.kRadiusLg),
                        border: Border.all(
                          color: selected
                              ? AppColors.kColorPrimary
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.kColorBorderSubtle),
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(m.$3,
                              size: 20,
                              color: selected
                                  ? AppColors.kColorPrimary
                                  : Theme.of(ctx).colorScheme.onSurface),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(m.$2,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color:
                                        Theme.of(ctx).colorScheme.onSurface)),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle,
                                size: 18, color: AppColors.kColorPrimary),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (method != 'cash') ...[
                const SizedBox(height: 4),
                TextField(
                  controller: refController,
                  decoration: InputDecoration(
                    labelText: l10n.payTxnIdLabel,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          setLocal(() => submitting = true);
                          final (err, paid) = await context
                              .read<GuideProvider>()
                              .recordPayment(b['id'] as int, method,
                                  refController.text.trim());
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (err != null) {
                            _snack(l10n.payRecordFailed(err));
                          } else if (paid != null && mounted) {
                            _showReceipt(paid);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.kColorPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(l10n.btnRecordPayment,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReceipt(Map<String, dynamic> b) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
        title: Row(
          children: [
            Icon(Icons.receipt_long,
                color: isDark ? AppColors.goldMain : AppColors.kColorPrimary),
            const SizedBox(width: 10),
            Text(l10n.payRecordedTitle,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(ctx).colorScheme.onSurface)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _receiptRow(ctx, l10n.receiptLabelNo, '${b['receipt_no'] ?? '—'}'),
            _receiptRow(ctx, l10n.receiptLabelGuide, '${b['guide_name'] ?? '—'}'),
            _receiptRow(ctx, l10n.receiptLabelDate, '${b['date'] ?? '—'}'),
            _receiptRow(ctx, l10n.receiptLabelMethod, '${b['payment_method'] ?? '—'}'),
            if (b['total_price'] != null)
              _receiptRow(ctx, l10n.receiptLabelAmount, 'NPR ${b['total_price']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.btnDone),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(BuildContext ctx, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(ctx).colorScheme.onSurface)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<GuideProvider>(
        builder: (context, guideProvider, _) {
          final all = guideProvider.guides;
          final processed = _process(all);
          final featured = processed.take(2).toList();
          final nearby = processed.skip(2).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context, isDark, guideProvider)),
              const SliverToBoxAdapter(child: SizedBox(height: 45)),

              // Stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15.0),
                  child: Row(
                    children: [
                      _statCard(context, '${all.length}', l10n.statGuidesAvailable),
                      const SizedBox(width: 12),
                      _statCard(context, '77', l10n.statDistrictsCovered),
                      const SizedBox(width: 12),
                      _statCard(
                        context,
                        all.isEmpty ? '–' : (all.map(_ratingOf).reduce((a, b) => a + b) / all.length).toStringAsFixed(1),
                        l10n.avgRating,
                      ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Filter chips
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: _chips.map((f) => _chip(context, f)).toList()),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // Tours needing the tourist's attention: counter-sign the
              // guide's "tour completed", or settle a due payment.
              ..._actionNeededSlivers(context, isDark, guideProvider),

              // Error
              if (guideProvider.error != null)
                SliverToBoxAdapter(child: _errorBox(context)),

              // Loading
              if (guideProvider.isLoading && all.isEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate((_, __) => _skeleton(context), childCount: 3),
                )
              else if (processed.isEmpty && !guideProvider.isLoading)
                SliverToBoxAdapter(child: _emptyState(context, isDark, all.isEmpty))
              else ...[
                // Featured section
                if (featured.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _sectionHeader(context, isDark, l10n.sectionFeaturedGuides, showSeeAll: true)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _featuredCard(context, isDark, featured[i]),
                      childCount: featured.length,
                    ),
                  ),
                ],
                // Nearby section
                if (nearby.isNotEmpty) ...[
                  SliverToBoxAdapter(child: _sectionHeader(context, isDark, l10n.sectionNearbyGuides)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _nearbyCard(context, isDark, nearby[i]),
                      childCount: nearby.length,
                    ),
                  ),
                ],
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  // ─── Header ───────────────────────────────────────────────────

  Widget _header(BuildContext context, bool isDark, GuideProvider gp) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Banner sizes to its content (+ bottom room for the overhanging search
        // bar) instead of a fixed screen fraction, so it never leaves an empty
        // band on tall devices or clips text on short ones.
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // Figma header combo: #5C1A0A → #A83210 → #C8501A (stops 0/.6/1).
              colors: isDark
                  ? [AppColors.brownDeep, AppColors.brownDark]
                  : const [Color(0xFF5C1A0A), Color(0xFFA83210), Color(0xFFC8501A)],
              stops: isDark ? null : const [0.0, 0.6, 1.0],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
              bottomRight: Radius.circular(AppDimensions.kRadiusXxl),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              // Extra bottom room so the search bar (overhangs by 28) clears the text.
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 44),
                      const Text(
                        'SAMPADA • सम्पदा',
                        style: TextStyle(color: AppColors.kColorBgWarm, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 14),
                      ),
                      _headerCircle(
                        onTap: gp.isLoading ? null : () => gp.fetchGuides(),
                        child: gp.isLoading
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.refresh, color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Find Your\nHeritage Guide',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.1),
                  ),
                  const SizedBox(height: 8),
                  Container(width: 40, height: 3, decoration: BoxDecoration(color: AppColors.kColorBgWarm, borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm))),
                  const SizedBox(height: 8),
                  const Text(
                    "Book certified local guides across Nepal's 77 districts",
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -28, left: 24, right: 24,
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgCard : Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
              boxShadow: AppTheme.elevatedShadow,
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: isDark ? AppColors.goldMain : AppColors.kColorPrimary, size: AppDimensions.iconLg),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context)!.searchGuidesHint,
                      hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary, fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Visual circle stays 36px, but the tappable area is padded out to the
  /// 44dp minimum touch target (48dp is ideal; 44 is the practical floor for
  /// a dense header row) so the refresh button isn't a mis-tap magnet.
  Widget _headerCircle({required Widget child, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44, height: 44,
          child: Center(
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, bool isDark, String title, {bool showSeeAll = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary)),
          if (showSeeAll)
            Text(AppLocalizations.of(context)!.guidesSeeAll, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : AppColors.kColorAccentSafe)),
        ],
      ),
    );
  }

  // ─── Cards ────────────────────────────────────────────────────

  Widget _avatar(BuildContext context, bool isDark, Map<String, dynamic> guide, double radius) {
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final fullName = (user['full_name'] ?? user['username'] ?? 'Guide').toString();
    final initials = fullName.split(' ').take(2).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
    final photoUrl = guide['photo_url'] as String?;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: isDark ? AppColors.darkBgCard : AppColors.kColorPrimary,
          // AppNetworkImage gives disk caching + a right-sized Cloudinary
          // transform instead of pulling the full-resolution original into
          // a ~50px circle on every cold start.
          child: hasPhoto
              ? ClipOval(
                  child: AppNetworkImage(
                    url: photoUrl,
                    width: radius * 2,
                    height: radius * 2,
                    cloudinaryWidth: radius * 2,
                  ),
                )
              : Text(initials, style: TextStyle(color: AppColors.kColorBgWarm, fontSize: radius * 0.6, fontWeight: FontWeight.bold)),
        ),
        // Green dot only for a guide who is genuinely reachable *and* accepting
        // bookings (the server decides — see guides/presence.py). Offline guides
        // get no dot at all: their "Last seen …" line carries the status, and a
        // permanent grey dot would just be visual noise on every card.
        if (_isOnline(guide))
          Positioned(
            bottom: 0, right: 2,
            child: Container(
              width: 13, height: 13,
              decoration: BoxDecoration(color: const Color(0xFF2ECC71), shape: BoxShape.circle, border: Border.all(color: isDark ? AppColors.darkBgCard : Colors.white, width: 2)),
            ),
          ),
      ],
    );
  }

  Widget _featuredCard(BuildContext context, bool isDark, Map<String, dynamic> guide) {
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final fullName = (user['full_name'] ?? user['username'] ?? 'Guide').toString();
    final rating = _ratingOf(guide);
    final reviews = _reviewsOf(guide);
    final rate = guide['hourly_rate'];
    final isVerified = (guide['is_verified'] as bool?) ?? false;
    final specialties = ((guide['specialties'] as List?) ?? []).cast<String>();
    final languages = ((guide['languages'] as List?) ?? []).cast<String>();
    final dist = _distanceLabel(guide);
    final accent = isDark ? AppColors.goldMain : AppColors.kColorPrimary;
    final sub = isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetail(guide),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(context, isDark, guide, 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fullName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 11, color: sub),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text.rich(
                              TextSpan(children: [
                                if (dist != null)
                                  TextSpan(
                                    text: '$dist · ',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent),
                                  ),
                                TextSpan(text: _locationOf(guide), style: TextStyle(fontSize: 11, color: sub)),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_isTopGuide(guide))
                      _pill('⭐ Top', isDark ? AppColors.goldMain : AppColors.kColorAccentLight, AppColors.kColorBrownDarkest),
                    if (isVerified) ...[
                      if (_isTopGuide(guide)) const SizedBox(height: 4),
                      _pill('✓ Verified', AppColors.kColorOfflineBg, AppColors.statusSuccess),
                    ],
                  ],
                ),
              ],
            ),
            if (specialties.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 5, runSpacing: 5, children: specialties.take(3).map((s) => _tag(context, isDark, s)).toList()),
            ],
            if (languages.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 5, runSpacing: 5, children: languages.take(3).map((l) => _langChip(context, isDark, l)).toList()),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: isDark ? AppColors.goldMain : AppColors.kColorAccent, size: 13),
                          const SizedBox(width: 3),
                          Text(rating.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
                          const SizedBox(width: 3),
                          Text('($reviews reviews)', style: TextStyle(fontSize: 11, color: sub)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _presenceText(context, isDark, guide, sub),
                    ],
                  ),
                ),
                if (_cheapestPackagePrice(guide) != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('From ${AppLocalizations.of(context)!.nprAmount(_cheapestPackagePrice(guide)!)}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accent)),
                      Text('per tour', style: TextStyle(fontSize: 10, color: sub)),
                    ],
                  )
                else if (rate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(AppLocalizations.of(context)!.nprAmount(rate.toString()), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accent)),
                      Text(AppLocalizations.of(context)!.labelPerHalfDay, style: TextStyle(fontSize: 10, color: sub)),
                    ],
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1, color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
            ),
            if (_isSelf(guide))
              _selfBanner(context, isDark)
            else if (_hasPending(guide))
              _pendingBanner(context, isDark)
            else
              Builder(builder: (context) {
                // Chat exists only for a booking this guide accepted. Without one
                // there is nothing to open, so the button is hidden rather than
                // offering a conversation the backend would refuse.
                final chatBookingId = _chatBookingIdWith(guide);
                return Row(
                  children: [
                    if (chatBookingId != null) ...[
                      Expanded(
                        child: _outlineBtn(context, isDark, 'Message',
                            () => _openChat(guide, chatBookingId)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(child: _outlineBtn(context, isDark, 'Review', () => _reviewGuide(guide))),
                    const SizedBox(width: 6),
                    Expanded(flex: 2, child: _filledBtn(context, isDark, 'Hire Now', () => _openDetail(guide))),
                  ],
                );
              }),
          ],
        ),
        ),
      ),
    );
  }

  Widget _nearbyCard(BuildContext context, bool isDark, Map<String, dynamic> guide) {
    final l10n = AppLocalizations.of(context)!;
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final fullName = (user['full_name'] ?? user['username'] ?? 'Guide').toString();
    final rating = _ratingOf(guide);
    final reviews = _reviewsOf(guide);
    final rate = guide['hourly_rate'];
    final isVerified = (guide['is_verified'] as bool?) ?? false;
    final specialties = ((guide['specialties'] as List?) ?? []).cast<String>();
    final languages = ((guide['languages'] as List?) ?? []).cast<String>();
    final dist = _distanceLabel(guide);
    final accent = isDark ? AppColors.goldMain : AppColors.kColorPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openDetail(guide),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
        child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _avatar(context, isDark, guide, 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(fullName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface), overflow: TextOverflow.ellipsis)),
                          if (isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 13, color: AppColors.statusSuccess),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text.rich(
                              TextSpan(children: [
                                if (dist != null)
                                  TextSpan(
                                    text: '$dist · ',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accent),
                                  ),
                                TextSpan(
                                  text: _locationOf(guide),
                                  style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary),
                                ),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_cheapestPackagePrice(guide) != null)
                  Text('From ${l10n.nprAmount(_cheapestPackagePrice(guide)!)}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accent))
                else if (rate != null)
                  Text(l10n.nprAmount(rate.toString()), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accent)),
              ],
            ),
            if (specialties.isNotEmpty || languages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 5, runSpacing: 5, children: [
                ...specialties.take(2).map((s) => _tag(context, isDark, s)),
                ...languages.take(2).map((l) => _langChip(context, isDark, l)),
              ]),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.star, color: isDark ? AppColors.goldMain : AppColors.kColorAccent, size: 13),
                const SizedBox(width: 3),
                Text(rating.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(width: 3),
                Text('($reviews)', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.kColorTextSecondary)),
                const SizedBox(width: 8),
                Flexible(
                  child: _presenceText(
                    context, isDark, guide,
                    isDark ? AppColors.darkTextTertiary : AppColors.kColorTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isSelf(guide))
              _selfBanner(context, isDark)
            else if (_hasPending(guide))
              _pendingBanner(context, isDark)
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _openDetail(guide),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
                  ),
                  child: Text(l10n.btnRequestGuide, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }

  // ─── Small widgets ────────────────────────────────────────────

  Widget _statCard(BuildContext context, String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : AppColors.kColorPrimary)),
            const SizedBox(height: 3),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedFilter == label;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = label),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? (isDark ? AppColors.goldMain : AppColors.kColorPrimary) : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
            border: Border.all(color: isSelected ? (isDark ? AppColors.goldMain : AppColors.kColorPrimary) : (isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? (isDark ? Colors.black : Colors.white) : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  /// "🟢 Online" or "Last seen 12 min ago". Renders nothing for a guide who has
  /// never sent a heartbeat (rather than inventing a status for them).
  Widget _presenceText(BuildContext context, bool isDark, Map<String, dynamic> guide, Color sub) {
    final label = _presenceLabel(context, guide);
    if (label == null) return const SizedBox.shrink();

    final online = _isOnline(guide);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (online) ...[
          Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(color: Color(0xFF2ECC71), shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: online ? FontWeight.bold : FontWeight.normal,
              color: online ? const Color(0xFF1E8449) : sub,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _tag(BuildContext context, bool isDark, String label) {
    final bg = isDark ? AppColors.darkBgCard : AppColors.kColorTagBg;
    final fg = isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500)),
    );
  }

  Widget _langChip(BuildContext context, bool isDark, String lang) {
    final short = _langShort[lang.toLowerCase()] ?? lang;
    final bg = isDark ? AppColors.darkBgCard : AppColors.kColorBgMuted;
    final border = isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle;
    final fg = isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
        border: Border.all(color: border),
      ),
      child: Text(short, style: TextStyle(fontSize: 11, color: fg)),
    );
  }

  Widget _outlineBtn(BuildContext context, bool isDark, String label, VoidCallback onTap) {
    final accent = isDark ? AppColors.goldMain : AppColors.kColorPrimary;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _filledBtn(BuildContext context, bool isDark, String label, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppColors.goldMain : AppColors.kColorPrimary,
        foregroundColor: isDark ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _errorBox(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg), border: Border.all(color: Colors.red.shade200)),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(child: Text(AppLocalizations.of(context)!.failedLoadGuides, style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, bool isDark, bool none) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.person_search, size: 64, color: isDark ? AppColors.darkTextTertiary : const Color(0xFFD4B8A8)),
          const SizedBox(height: 16),
          Text(none ? 'No guides registered yet.' : 'No guides match your search.', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary)),
        ],
      ),
    );
  }

  Widget _skeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
      ),
      child: Row(
        children: [
          const ShimmerSkeleton(width: 60, height: 60, borderRadius: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerSkeleton(width: 120, height: 14, borderRadius: AppDimensions.kRadiusSm),
                const SizedBox(height: 8),
                const ShimmerSkeleton(width: 80, height: 12, borderRadius: AppDimensions.kRadiusSm),
                const SizedBox(height: 8),
                const ShimmerSkeleton(width: 160, height: 10, borderRadius: AppDimensions.kRadiusSm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
