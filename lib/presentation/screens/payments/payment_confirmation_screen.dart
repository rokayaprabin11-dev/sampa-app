import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/services/cloudinary_uploader.dart';
import 'package:sampada/core/services/secure_screen.dart';
import 'package:sampada/data/models/payment_model.dart';
import 'package:sampada/injection.dart' as di;
import 'package:sampada/presentation/screens/bookings/booking_widgets.dart';
import 'package:sampada/presentation/screens/payments/payment_widgets.dart';
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';
import 'package:sampada/providers/payment_provider.dart';

/// "I have paid" — the tourist tells the guide what they sent.
///
/// This screen creates a *claim*, not a payment. The wording throughout says so,
/// because a screen that congratulates the tourist on a completed payment when
/// the guide has not seen the money yet is precisely the lie this module was
/// built to remove.
class PaymentConfirmationScreen extends StatefulWidget {
  final int bookingId;
  final String guideName;
  final double? amount;
  final GuidePaymentDestinations destinations;

  const PaymentConfirmationScreen({
    super.key,
    required this.bookingId,
    required this.guideName,
    required this.amount,
    required this.destinations,
  });

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen>
    with SecureScreenMixin {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  late PaymentMethod _method;
  XFile? _screenshot;
  bool _uploading = false;
  String? _screenshotError;

  @override
  void initState() {
    super.initState();
    // Default to the guide's preferred method when they can actually take it,
    // otherwise the first one they published — never a method they cannot
    // receive, which is what a hardcoded list used to do.
    final methods = widget.destinations.ordered.map((d) => d.method).toList();
    _method = methods.isEmpty ? PaymentMethod.cash : methods.first;
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final payments = context.watch<PaymentProvider>();
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SampadaAppBar(title: Text('Confirm Your Payment')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.sp16),
          children: [
            PaymentAmountCard(
              amount: widget.amount,
              title: 'You are confirming',
              subtitle: 'Paid to ${widget.guideName}',
            ),
            const SizedBox(height: AppDimensions.sp16),

            BookingSection(
              icon: Icons.account_balance_wallet_outlined,
              title: 'How you paid',
              child: Column(
                children: [
                  for (final destination in widget.destinations.ordered)
                    PaymentDestinationTile(
                      destination: destination,
                      preferred:
                          destination.method == widget.destinations.preferred,
                      selected: destination.method == _method,
                      onTap: () => setState(() => _method = destination.method),
                    ),
                ],
              ),
            ),

            BookingSection(
              icon: Icons.tag,
              title: _method.needsReference
                  ? 'Transaction reference'
                  : 'Reference (not needed for cash)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _referenceController,
                    enabled: _method.needsReference,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [LengthLimitingTextInputFormatter(100)],
                    style: t.bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: _method.needsReference
                          ? 'e.g. 9K3F2M8T1'
                          : 'Cash needs no reference',
                    ),
                    validator: (value) {
                      if (!_method.needsReference) return null;
                      // The guide verifies against this; without it they have
                      // nothing to match the money to, and the server refuses.
                      if ((value ?? '').trim().isEmpty) {
                        return 'Enter the reference from your ${_method.label} payment.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppDimensions.sp8),
                  Text(
                    _method.needsReference
                        ? 'Copy it from the ${_method.label} receipt. It is how ${widget.guideName} finds your payment.'
                        : 'Your guide will confirm they received the cash.',
                    style: t.bodySmall?.copyWith(color: bookingMuted(context)),
                  ),
                ],
              ),
            ),

            BookingSection(
              icon: Icons.image_outlined,
              title: 'Screenshot (optional)',
              child: _screenshotField(context),
            ),

            BookingSection(
              icon: Icons.notes_outlined,
              title: 'Note to your guide (optional)',
              child: TextFormField(
                controller: _notesController,
                maxLines: 3,
                inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                style: t.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                decoration: const InputDecoration(
                  hintText: 'Anything that helps them find the payment',
                ),
              ),
            ),

            if (payments.error != null) ...[
              BookingBanner(
                icon: Icons.error_outline,
                title: 'Could not submit',
                message: payments.error,
                bg: AppColors.statusError.withValues(alpha: 0.08),
                fg: AppColors.statusError,
              ),
            ],

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: payments.submitting || _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.kColorTextOnPrimary),
                      )
                    : const Icon(Icons.send_outlined, size: AppDimensions.iconSm),
                label: Text(_uploading
                    ? 'Uploading screenshot…'
                    : payments.submitting
                        ? 'Submitting…'
                        : 'Submit for Confirmation'),
                onPressed: payments.submitting || _uploading ? null : _submit,
              ),
            ),
            const SizedBox(height: AppDimensions.sp10),
            Text(
              '${widget.guideName} will check their account and confirm. Your '
              'booking is marked paid only once they do.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: bookingMuted(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _screenshotField(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final picked = _screenshot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (picked != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
            child: Image.file(
              File(picked.path),
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        if (picked != null) const SizedBox(height: AppDimensions.sp10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_library_outlined,
                    size: AppDimensions.iconSm),
                label: Text(picked == null ? 'Add Screenshot' : 'Replace'),
                onPressed: _pickScreenshot,
              ),
            ),
            if (picked != null) ...[
              const SizedBox(width: AppDimensions.sp8),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline),
                color: AppColors.statusError,
                onPressed: () => setState(() {
                  _screenshot = null;
                  _screenshotError = null;
                }),
              ),
            ],
          ],
        ),
        if (_screenshotError != null) ...[
          const SizedBox(height: AppDimensions.sp8),
          Text(_screenshotError!,
              style: t.bodySmall?.copyWith(color: AppColors.statusError)),
        ],
        const SizedBox(height: AppDimensions.sp8),
        Text(
          'A screenshot settles most disputes in one look. It is stored with the '
          'payment and seen only by you, your guide, and Sampada support.',
          style: t.bodySmall?.copyWith(color: bookingMuted(context)),
        ),
      ],
    );
  }

  Future<void> _pickScreenshot() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Screenshots are text on a flat background; this keeps the upload small
      // without making the transaction ID unreadable.
      maxWidth: 1400,
      imageQuality: 85,
    );
    if (file == null) return;
    setState(() {
      _screenshot = file;
      _screenshotError = null;
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payments = context.read<PaymentProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    String screenshotUrl = '';
    final file = _screenshot;
    if (file != null) {
      setState(() {
        _uploading = true;
        _screenshotError = null;
      });
      try {
        final uploader = CloudinaryUploader(apiClient: di.sl<ApiClient>());
        screenshotUrl = await uploader.upload(file, 'sampada/payments') ?? '';
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _uploading = false;
          // Do not silently submit without the proof the tourist chose to
          // attach — they would think the guide can see it.
          _screenshotError =
              'The screenshot could not be uploaded. Try again, or remove it and '
              'submit with the reference alone.';
        });
        return;
      }
      if (!mounted) return;
      setState(() => _uploading = false);
    }

    final confirmation = await payments.submit(
      bookingId: widget.bookingId,
      method: _method,
      reference: _referenceController.text,
      screenshotUrl: screenshotUrl,
      notes: _notesController.text,
    );
    if (!mounted || confirmation == null) return;

    messenger.showSnackBar(SnackBar(
      content: Text('Sent to ${widget.guideName}. They will confirm it.'),
    ));
    navigator.pop(true);
  }
}
