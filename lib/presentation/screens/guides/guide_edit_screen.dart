import 'package:flutter/material.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';
import 'package:sampada/providers/guide_provider.dart';

/// One editable package row: label + hours + price controllers.
class _PackageRow {
  final TextEditingController label;
  final TextEditingController hours;
  final TextEditingController price;
  _PackageRow({String? labelText, String? hoursText, String? priceText})
      : label = TextEditingController(text: labelText ?? ''),
        hours = TextEditingController(text: hoursText ?? ''),
        price = TextEditingController(text: priceText ?? '');

  void dispose() {
    label.dispose();
    hours.dispose();
    price.dispose();
  }
}

/// Edit the logged-in guide's own listing via PATCH /guides/me/. This does NOT
/// reset the approval status (unlike re-submitting the application form).
class GuideEditScreen extends StatefulWidget {
  const GuideEditScreen({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<GuideEditScreen> createState() => _GuideEditScreenState();
}

class _GuideEditScreenState extends State<GuideEditScreen> {
  late final TextEditingController _bio;
  late final TextEditingController _rate;
  late final TextEditingController _languages;
  late final TextEditingController _specialties;
  late final TextEditingController _includedGroup;
  late final TextEditingController _maxGroup;
  late final TextEditingController _extraFee;
  final List<_PackageRow> _packages = [];
  bool _saving = false;

  static const _maxPackages = 10;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _bio = TextEditingController(text: (p['bio'] as String?) ?? '');
    _rate = TextEditingController(text: _numText(p['hourly_rate']));
    _languages = TextEditingController(text: _joinList(p['languages']));
    _specialties = TextEditingController(text: _joinList(p['specialties']));
    _includedGroup = TextEditingController(text: _numText(p['included_group_size'] ?? 5));
    _maxGroup = TextEditingController(text: _numText(p['max_group_size'] ?? 10));
    _extraFee = TextEditingController(text: _numText(p['extra_person_fee'] ?? 0));
    final pkgs = p['packages'];
    if (pkgs is List) {
      for (final pkg in pkgs.whereType<Map>()) {
        _packages.add(_PackageRow(
          labelText: '${pkg['label'] ?? ''}',
          hoursText: _numText(pkg['hours']),
          priceText: _numText(pkg['price']),
        ));
      }
    }
  }

  @override
  void dispose() {
    _bio.dispose();
    _rate.dispose();
    _languages.dispose();
    _specialties.dispose();
    _includedGroup.dispose();
    _maxGroup.dispose();
    _extraFee.dispose();
    for (final row in _packages) {
      row.dispose();
    }
    super.dispose();
  }

  String _numText(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      // "4.0" reads awkwardly in a form — show whole numbers plainly.
      return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    }
    final parsed = double.tryParse(v.toString());
    if (parsed != null && parsed == parsed.roundToDouble()) {
      return parsed.toInt().toString();
    }
    return v.toString();
  }

  String _joinList(dynamic v) =>
      v is List ? v.whereType<String>().join(', ') : '';

  List<String> _splitList(String s) => s
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  /// Collect package rows; returns null (and shows a snack) on invalid input.
  /// Rows left completely empty are skipped.
  List<Map<String, dynamic>>? _collectPackages() {
    final result = <Map<String, dynamic>>[];
    for (final row in _packages) {
      final label = row.label.text.trim();
      final hoursText = row.hours.text.trim();
      final priceText = row.price.text.trim();
      if (label.isEmpty && hoursText.isEmpty && priceText.isEmpty) continue;
      final hours = double.tryParse(hoursText);
      final price = double.tryParse(priceText);
      if (label.isEmpty || hours == null || price == null || hours <= 0 || hours > 24 || price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Each package needs a name, hours (up to 24) and a price above zero.')));
        return null;
      }
      result.add({'label': label, 'hours': hours, 'price': price});
    }
    return result;
  }

  Future<void> _save() async {
    final packages = _collectPackages();
    if (packages == null) return;

    final included = int.tryParse(_includedGroup.text.trim()) ?? 5;
    final maxGroup = int.tryParse(_maxGroup.text.trim()) ?? 10;
    if (included > maxGroup) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Included group size cannot exceed the maximum group size.')));
      return;
    }

    setState(() => _saving = true);
    final data = <String, dynamic>{
      'bio': _bio.text.trim(),
      'languages': _splitList(_languages.text),
      'specialties': _splitList(_specialties.text),
      'packages': packages,
      'included_group_size': included,
      'max_group_size': maxGroup,
      'extra_person_fee': double.tryParse(_extraFee.text.trim()) ?? 0,
    };
    final rate = double.tryParse(_rate.text.trim());
    if (rate != null) data['hourly_rate'] = rate;

    final err = await context.read<GuideProvider>().updateMyProfile(data);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.profileUpdated)),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.couldntSave)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.goldMain : AppColors.kColorDeep;

    return Scaffold(
      appBar: SampadaAppBar(title: Text(l10n.btnEditProfile)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(l10n.fieldBio, _bio, maxLines: 4, hint: l10n.bioHint),
            _field(l10n.labelLanguages, _languages, hint: l10n.languagesHint),
            _field(l10n.fieldSpecialties, _specialties, hint: l10n.specialtiesHint),

            // ── Tour packages ─────────────────────────────────────────────
            const SizedBox(height: 8),
            Text('Tour Packages',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 4),
            Text(
              'Tourists pick one of these when booking you. '
              'Leave empty to be booked by the hour instead.',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextMuted),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < _packages.length; i++) _packageRow(i, isDark),
            if (_packages.length < _maxPackages)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _packages.add(_PackageRow())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add package'),
                  style: TextButton.styleFrom(foregroundColor: accent),
                ),
              ),

            // ── Group pricing ────────────────────────────────────────────
            const SizedBox(height: 16),
            Text('Group Pricing',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _field('Included group size', _includedGroup,
                        keyboardType: TextInputType.number, hint: 'e.g. 5')),
                const SizedBox(width: 12),
                Expanded(
                    child: _field('Max group size', _maxGroup,
                        keyboardType: TextInputType.number, hint: 'e.g. 10')),
              ],
            ),
            _field('Extra person fee (NPR)', _extraFee,
                keyboardType: TextInputType.number,
                hint: 'Charged per person above the included size'),

            _field('${l10n.fieldHourlyRate} (fallback)', _rate,
                keyboardType: TextInputType.number, hint: l10n.rateHint),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg)),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.btnSaveChanges,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _packageRow(int index, bool isDark) {
    final row = _packages[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.label,
                  decoration: const InputDecoration(
                    hintText: 'Package name, e.g. Half Day',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.statusError,
                onPressed: () => setState(() {
                  _packages.removeAt(index).dispose();
                }),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.hours,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Hours',
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: row.price,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Price (NPR)',
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c,
      {int maxLines = 1, TextInputType? keyboardType, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd)),
            ),
          ),
        ],
      ),
    );
  }
}
