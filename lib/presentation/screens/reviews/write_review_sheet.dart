import 'package:flutter/material.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/generated/app_localizations.dart';

/// The five things a tourist can score beyond the overall star rating. The keys
/// are the API contract (backend `Booking.REVIEW_CATEGORIES`); the labels and
/// icons are display only.
const reviewCategories = <({String key, String label, IconData icon})>[
  (key: 'knowledge', label: 'Knowledge', icon: Icons.menu_book_outlined),
  (key: 'communication', label: 'Communication', icon: Icons.forum_outlined),
  (key: 'friendliness', label: 'Friendliness', icon: Icons.sentiment_satisfied_alt_outlined),
  (key: 'punctuality', label: 'Punctuality', icon: Icons.schedule_outlined),
  (key: 'value', label: 'Value for money', icon: Icons.payments_outlined),
];

/// What the sheet returns. Categories are only included for the rows the tourist
/// actually touched — the backend stores a category as null when it was not
/// scored, and an unscored category must not be sent as a zero.
class ReviewDraft {
  final int rating;
  final String text;
  final Map<String, int> categories;

  const ReviewDraft({
    required this.rating,
    required this.text,
    this.categories = const {},
  });
}

/// The single write-review UX in the app — used both by the reviews screen's
/// "Write a Review" button and by the bookings screens' Rate Guide action, so a
/// review means the same thing wherever it is written.
Future<ReviewDraft?> showWriteReviewSheet(
  BuildContext context, {
  required String guideName,
}) {
  return showModalBottomSheet<ReviewDraft>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppDimensions.kRadiusXxl)),
    ),
    builder: (_) => _WriteReviewSheet(guideName: guideName),
  );
}

class _WriteReviewSheet extends StatefulWidget {
  final String guideName;
  const _WriteReviewSheet({required this.guideName});

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  static const _maxChars = 1000;

  final _controller = TextEditingController();
  int _rating = 5;
  final Map<String, int> _categories = {};

  @override
  void initState() {
    super.initState();
    // Rebuild for the character counter.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? AppColors.kColorAccentLight
          : AppColors.kColorAccent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted =
        isDark ? AppColors.kDarkTextMuted : AppColors.kColorTextMuted;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.sp20,
        AppDimensions.sp12,
        AppDimensions.sp20,
        MediaQuery.of(context).viewInsets.bottom + AppDimensions.sp24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimensions.sp16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.kDarkBorder
                      : AppColors.kColorBorderSubtle,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.kRadiusPill),
                ),
              ),
            ),

            Text(l10n.reviewGuide(widget.guideName),
                style: t.titleMedium?.copyWith(color: onSurface)),
            const SizedBox(height: AppDimensions.sp16),

            // ── Overall ──────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text('Overall',
                      style: t.labelSmall?.copyWith(color: muted)),
                  const SizedBox(height: AppDimensions.sp4),
                  _StarRow(
                    value: _rating,
                    size: AppDimensions.iconXl,
                    color: _accent(context),
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.sp20),

            // ── Per category ─────────────────────────────────────────
            Text('Rate the details',
                style: t.labelSmall?.copyWith(color: muted)),
            const SizedBox(height: AppDimensions.sp4),
            Text(
              'Optional — skip any that did not apply.',
              style: t.bodySmall?.copyWith(color: muted),
            ),
            const SizedBox(height: AppDimensions.sp10),
            ...reviewCategories.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.sp8),
                  child: Row(
                    children: [
                      Icon(c.icon,
                          size: AppDimensions.iconSm,
                          color: AppColors.kColorAccentSafe),
                      const SizedBox(width: AppDimensions.sp8),
                      Expanded(
                        child: Text(c.label,
                            style: t.bodyMedium?.copyWith(color: onSurface)),
                      ),
                      _StarRow(
                        value: _categories[c.key] ?? 0,
                        size: 22,
                        color: _accent(context),
                        onChanged: (v) =>
                            setState(() => _categories[c.key] = v),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: AppDimensions.sp12),

            // ── Text ─────────────────────────────────────────────────
            TextField(
              controller: _controller,
              maxLines: 5,
              maxLength: _maxChars,
              textCapitalization: TextCapitalization.sentences,
              style: t.bodyMedium?.copyWith(color: onSurface),
              decoration: InputDecoration(
                hintText: l10n.reviewHint,
                counterText: '${_controller.text.characters.length}/$_maxChars',
              ),
            ),
            const SizedBox(height: AppDimensions.sp16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  ReviewDraft(
                    rating: _rating,
                    text: _controller.text.trim(),
                    // Only rows actually touched — a zero would be a lie.
                    categories: Map.of(_categories)
                      ..removeWhere((_, v) => v <= 0),
                  ),
                ),
                child: Text(l10n.btnSubmit),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable 1–5 stars. A [value] of 0 means "not scored", which the categories
/// use to stay out of the payload.
class _StarRow extends StatelessWidget {
  final int value;
  final double size;
  final Color color;
  final ValueChanged<int> onChanged;

  const _StarRow({
    required this.value,
    required this.size,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < value;
        return IconButton(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sp2),
          constraints: const BoxConstraints(),
          visualDensity: VisualDensity.compact,
          tooltip: '${i + 1} star${i == 0 ? '' : 's'}',
          onPressed: () => onChanged(i + 1),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: filled
                ? color
                : (Theme.of(context).brightness == Brightness.dark
                    ? AppColors.kDarkBorder
                    : AppColors.kColorBorderStrong),
          ),
        );
      }),
    );
  }
}
