import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/services/secure_screen.dart';
import 'package:sampada/data/models/payment_model.dart';
import 'package:sampada/presentation/screens/bookings/booking_widgets.dart';
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';
import 'package:sampada/providers/guide_payment_provider.dart';

/// Where the guide publishes how they want to be paid.
///
/// Until they fill this in, a tourist who owes them money has nowhere to send it
/// and has to ask in chat — which is how it worked before, and why it kept going
/// wrong. The identifiers here are shown only to tourists who have actually
/// booked this guide, never in the public directory.
class GuidePaymentSettingsScreen extends StatefulWidget {
  const GuidePaymentSettingsScreen({super.key});

  @override
  State<GuidePaymentSettingsScreen> createState() =>
      _GuidePaymentSettingsScreenState();
}

class _GuidePaymentSettingsScreenState extends State<GuidePaymentSettingsScreen>
    with SecureScreenMixin {
  final _formKey = GlobalKey<FormState>();
  final _esewa = TextEditingController();
  final _khalti = TextEditingController();
  final _fonepay = TextEditingController();
  final _notes = TextEditingController();

  PaymentMethod _preferred = PaymentMethod.esewa;
  bool _isActive = true;
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _esewa.dispose();
    _khalti.dispose();
    _fonepay.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<GuidePaymentProvider>();
    await provider.loadInformation();
    if (!mounted) return;
    final info = provider.information;
    setState(() {
      _loaded = true;
      if (info == null) return;
      _esewa.text = info.esewaId;
      _khalti.text = info.khaltiMobile;
      _fonepay.text = info.fonepayNumber;
      _notes.text = info.notes;
      _preferred = info.preferred;
      _isActive = info.isActive;
    });
  }

  /// Cash is not a wallet: it needs no account, so it can never be the thing
  /// that makes a form "filled in". Mirrors the server's rule exactly.
  bool get _hasWallet =>
      _esewa.text.trim().isNotEmpty ||
      _khalti.text.trim().isNotEmpty ||
      _fonepay.text.trim().isNotEmpty;

  /// The methods this guide can actually be paid by right now — cash always
  /// qualifies, the rest only once their account is filled in. Offering a
  /// preferred method the guide left blank would point tourists at nothing.
  List<PaymentMethod> get _available => [
        if (_esewa.text.trim().isNotEmpty) PaymentMethod.esewa,
        if (_khalti.text.trim().isNotEmpty) PaymentMethod.khalti,
        if (_fonepay.text.trim().isNotEmpty) PaymentMethod.fonepay,
        PaymentMethod.cash,
      ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final provider = context.watch<GuidePaymentProvider>();

    if (!_loaded && provider.loadingInformation) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const SampadaAppBar(title: Text('Payment Information')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SampadaAppBar(title: Text('Payment Information')),
      body: Form(
        key: _formKey,
        onChanged: () => setState(() {}), // keeps the preferred list honest
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.sp16),
          children: [
            if (!_hasWallet)
              BookingBanner(
                icon: Icons.info_outline,
                title: 'Tourists cannot pay you yet',
                message: 'Add at least one account. It is shown only to tourists '
                    'who have booked you.',
                bg: AppColors.statusWarning.withValues(alpha: 0.10),
                fg: AppColors.statusWarning,
              ),

            BookingSection(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Your accounts',
              child: Column(
                children: [
                  _walletField(
                    controller: _esewa,
                    label: 'eSewa ID',
                    hint: 'Mobile number or eSewa ID',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _walletField(
                    controller: _khalti,
                    label: 'Khalti mobile',
                    hint: '10-digit mobile number',
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _walletField(
                    controller: _fonepay,
                    label: 'Fonepay number',
                    hint: 'Mobile or Fonepay account number',
                    icon: Icons.qr_code_2,
                  ),
                ],
              ),
            ),

            BookingSection(
              icon: Icons.star_outline,
              title: 'Preferred method',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: AppDimensions.sp8,
                    runSpacing: AppDimensions.sp8,
                    children: [
                      for (final method in _available)
                        ChoiceChip(
                          label: Text(method.label),
                          selected: _preferred == method,
                          onSelected: (_) => setState(() => _preferred = method),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sp10),
                  Text(
                    'Shown first when a tourist opens the payment screen.',
                    style: t.bodySmall?.copyWith(color: bookingMuted(context)),
                  ),
                ],
              ),
            ),

            BookingSection(
              icon: Icons.notes_outlined,
              title: 'Note for tourists (optional)',
              child: TextFormField(
                controller: _notes,
                maxLines: 3,
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                style: t.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                decoration: const InputDecoration(
                  hintText: 'e.g. Put your booking reference in the remarks.',
                ),
              ),
            ),

            BookingSection(
              icon: Icons.toggle_on_outlined,
              title: 'Accepting payments',
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                onChanged: (value) => setState(() => _isActive = value),
                title: Text(
                  _isActive ? 'Your details are visible' : 'Your details are hidden',
                  style: t.bodyMedium
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                ),
                subtitle: Text(
                  _isActive
                      ? 'Tourists who booked you can see where to pay.'
                      : 'Tourists will be told to ask you in chat. Turn this back '
                          'on when you can take payments again.',
                  style: t.bodySmall?.copyWith(color: bookingMuted(context)),
                ),
              ),
            ),

            if (provider.error != null)
              BookingBanner(
                icon: Icons.error_outline,
                title: 'Could not save',
                message: provider.error,
                bg: AppColors.statusError.withValues(alpha: 0.08),
                fg: AppColors.statusError,
              ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.kColorTextOnPrimary),
                      )
                    : const Icon(Icons.save_outlined, size: AppDimensions.iconSm),
                label: Text(_saving ? 'Saving…' : 'Save Payment Details'),
                onPressed: _saving ? null : _save,
              ),
            ),
            const SizedBox(height: AppDimensions.sp12),
            Text(
              'Sampada never holds your money. Tourists pay these accounts '
              'directly, and you confirm each payment yourself.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: bookingMuted(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _walletField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sp12),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.text,
        inputFormatters: [LengthLimitingTextInputFormatter(60)],
        style: t.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: AppDimensions.iconMd),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_hasWallet) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Add at least one account so tourists can pay you.'),
      ));
      return;
    }
    // A preferred method the guide has not filled in would send tourists to an
    // empty account; fall back to one they can actually receive on.
    if (!_available.contains(_preferred)) {
      setState(() => _preferred = _available.first);
    }

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<GuidePaymentProvider>();

    final error = await provider.saveInformation(GuidePaymentInformation(
      preferred: _preferred,
      esewaId: _esewa.text,
      khaltiMobile: _khalti.text,
      fonepayNumber: _fonepay.text,
      notes: _notes.text,
      isActive: _isActive,
      availableMethods: _available,
    ));
    if (!mounted) return;
    setState(() => _saving = false);

    messenger.showSnackBar(SnackBar(
      content: Text(error ?? 'Tourists who book you can now see where to pay.'),
    ));
  }
}
