import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/data/models/payment_model.dart';
import 'package:sampada/presentation/screens/bookings/booking_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared pieces of the payment screens.
///
/// Deliberately thin: the cards, chips, sections, key-value rows, empty and
/// error states all come from `booking_widgets.dart` — a payment *is* the tail
/// of a booking, and giving it its own visual language would make the two read
/// as different products. Only what is genuinely payment-specific lives here.

// ── Status ───────────────────────────────────────────────────────────────────

StatusMeta paymentStatusMeta(PaymentStatus status) => switch (status) {
      PaymentStatus.confirmed => (
          bg: AppColors.kColorOfflineBg,
          fg: AppColors.kColorOfflineText,
          icon: Icons.verified_outlined,
          label: 'Confirmed',
        ),
      PaymentStatus.rejected => (
          bg: AppColors.statusError.withValues(alpha: 0.10),
          fg: AppColors.statusError,
          icon: Icons.error_outline,
          label: 'Not confirmed',
        ),
      PaymentStatus.pending => (
          bg: AppColors.kColorPendingBg,
          fg: AppColors.kColorPendingText,
          icon: Icons.hourglass_top,
          label: 'Awaiting guide',
        ),
    };

IconData paymentMethodIcon(PaymentMethod? method) => switch (method) {
      PaymentMethod.fonepay => Icons.qr_code_2,
      PaymentMethod.cash => Icons.payments_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };

/// NPR is the only currency the platform prices in, so it is stated rather than
/// resolved — a currency selector would imply a conversion that never happens.
String npr(double? amount) => amount == null ? '—' : 'NPR ${money(amount)}';

// ── Amount owed ──────────────────────────────────────────────────────────────

/// The headline "this is what you owe" card. One number, large, with the tour it
/// belongs to underneath — the tourist is about to type this figure into a
/// wallet app, so it must be unmissable and unambiguous.
class PaymentAmountCard extends StatelessWidget {
  final double? amount;
  final String title;
  final String? subtitle;
  final Color? accent;

  const PaymentAmountCard({
    super.key,
    required this.amount,
    required this.title,
    this.subtitle,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colour = accent ?? AppColors.kColorPrimary;
    return BookingCardShell(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sp20, vertical: AppDimensions.sp20),
      child: Column(
        children: [
          Text(title.toUpperCase(),
              style: t.labelSmall?.copyWith(color: bookingMuted(context))),
          const SizedBox(height: AppDimensions.sp8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              npr(amount),
              style: t.headlineSmall?.copyWith(
                color: colour,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppDimensions.sp6),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: bookingSecondary(context))),
          ],
        ],
      ),
    );
  }
}

// ── Where to pay ─────────────────────────────────────────────────────────────

/// One of the guide's accounts, with the identifier the tourist has to type into
/// their wallet app. Copy is the primary action because it is the step where a
/// typo sends money to a stranger.
class PaymentDestinationTile extends StatelessWidget {
  final PaymentDestination destination;
  final bool preferred;
  final bool selected;
  final VoidCallback? onTap;

  const PaymentDestinationTile({
    super.key,
    required this.destination,
    this.preferred = false,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final method = destination.method;
    final isCash = method == PaymentMethod.cash;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sp10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.sp14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.kColorPrimary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
            border: Border.all(
              color: selected ? AppColors.kColorPrimary : bookingBorder(context),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(paymentMethodIcon(method),
                  size: AppDimensions.iconMd,
                  color: selected ? AppColors.kColorPrimary : bookingMuted(context)),
              const SizedBox(width: AppDimensions.sp12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(method.label,
                            style: t.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            )),
                        if (preferred) ...[
                          const SizedBox(width: AppDimensions.sp8),
                          const BookingChip(
                            meta: (
                              bg: AppColors.kColorTagBg,
                              fg: AppColors.kColorAccentDark,
                              icon: Icons.star_outline,
                              label: 'Preferred',
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sp2),
                    Text(
                      isCash
                          ? 'Hand the money to your guide in person.'
                          : destination.identifier,
                      style: t.bodySmall?.copyWith(
                        color: bookingSecondary(context),
                        // A wallet ID is copied and compared digit by digit;
                        // proportional type makes that harder than it needs to be.
                        fontFeatures: isCash
                            ? null
                            : const [FontFeature.tabularFigures()],
                        letterSpacing: isCash ? null : 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isCash)
                IconButton(
                  tooltip: 'Copy ${method.identifierLabel}',
                  icon: const Icon(Icons.copy_rounded, size: AppDimensions.iconSm),
                  color: AppColors.kColorPrimary,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                        ClipboardData(text: destination.identifier));
                    messenger.showSnackBar(SnackBar(
                        content: Text('${method.label} ID copied.')));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the wallet app, falling back to its store listing.
///
/// Nepali wallets publish no documented deep link, so this tries the app's
/// scheme and, when nothing handles it, sends the user to the store rather than
/// failing silently. It never claims to have started a payment — the transfer
/// happens in the wallet, and Sampada only hears about it when the tourist says
/// so.
Future<void> openWalletApp(BuildContext context, PaymentMethod method) async {
  final messenger = ScaffoldMessenger.of(context);
  const schemes = {
    PaymentMethod.esewa: 'esewa://',
    PaymentMethod.khalti: 'khalti://',
    PaymentMethod.fonepay: 'fonepay://',
  };
  const stores = {
    PaymentMethod.esewa: 'https://play.google.com/store/apps/details?id=com.f1soft.esewa',
    PaymentMethod.khalti: 'https://play.google.com/store/apps/details?id=com.khalti',
    PaymentMethod.fonepay: 'https://play.google.com/store/apps/details?id=com.f1soft.fonepay.consumer',
  };

  final scheme = schemes[method];
  if (scheme == null) return; // cash — nothing to open

  try {
    final opened = await launchUrl(Uri.parse(scheme),
        mode: LaunchMode.externalApplication);
    if (opened) return;
  } catch (_) {
    // Not installed, or the OS refused the scheme. Fall through to the store.
  }

  final store = stores[method];
  if (store == null) return;
  try {
    await launchUrl(Uri.parse(store), mode: LaunchMode.externalApplication);
  } catch (_) {
    messenger.showSnackBar(SnackBar(
        content: Text('Could not open ${method.label}. Pay from the app directly.')));
  }
}

// ── Claim summary ────────────────────────────────────────────────────────────

/// A payment claim as a list row: amount, method, status, and — when the guide
/// rejected it — the reason, because that is the only thing the tourist can act
/// on.
class PaymentCard extends StatelessWidget {
  final PaymentConfirmation payment;

  /// A guide reads the same row from the other side ("Ram paid you"), so the
  /// counterparty's name changes but the layout does not.
  final bool asGuide;
  final VoidCallback? onTap;

  const PaymentCard({
    super.key,
    required this.payment,
    this.asGuide = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final meta = paymentStatusMeta(payment.status);
    final who = asGuide ? payment.touristName : payment.guideName;

    return BookingCardShell(
      margin: const EdgeInsets.only(bottom: AppDimensions.sp12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: meta.bg,
                  borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
                ),
                child: Icon(paymentMethodIcon(payment.method),
                    size: AppDimensions.iconMd, color: meta.fg),
              ),
              const SizedBox(width: AppDimensions.sp12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      npr(payment.amount),
                      style: t.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.sp2),
                    Text(
                      '${payment.method?.label ?? 'Payment'} · ${asGuide ? 'from' : 'to'} $who',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(color: bookingSecondary(context)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.sp8),
              BookingChip(meta: meta),
            ],
          ),
          const SizedBox(height: AppDimensions.sp12),
          Row(
            children: [
              Icon(Icons.confirmation_number_outlined,
                  size: 13, color: bookingMuted(context)),
              const SizedBox(width: AppDimensions.sp4),
              Expanded(
                child: Text(
                  payment.isConfirmed && payment.receiptNo.isNotEmpty
                      ? payment.receiptNo
                      : payment.bookingRef,
                  style: t.bodySmall?.copyWith(color: bookingMuted(context)),
                ),
              ),
              Text(
                formatBookingDate(payment.submittedAt?.toIso8601String()) ?? '',
                style: t.bodySmall?.copyWith(color: bookingMuted(context)),
              ),
            ],
          ),
          if (payment.isRejected && payment.guideComment.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.sp10),
            Container(
              padding: const EdgeInsets.all(AppDimensions.sp10),
              decoration: BoxDecoration(
                color: AppColors.statusError.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
              ),
              child: Text(
                payment.guideComment,
                style: t.bodySmall?.copyWith(color: AppColors.statusError),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton with the same silhouette as [PaymentCard].
class PaymentCardSkeleton extends StatelessWidget {
  const PaymentCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const BookingCardSkeleton();
}
