import 'package:flutter/material.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/providers/guide_provider.dart';

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _bio = TextEditingController(text: (p['bio'] as String?) ?? '');
    _rate = TextEditingController(text: _rateText(p['hourly_rate']));
    _languages = TextEditingController(text: _joinList(p['languages']));
    _specialties = TextEditingController(text: _joinList(p['specialties']));
  }

  @override
  void dispose() {
    _bio.dispose();
    _rate.dispose();
    _languages.dispose();
    _specialties.dispose();
    super.dispose();
  }

  String _rateText(dynamic v) {
    if (v == null) return '';
    if (v is num) return v.toString();
    return v.toString();
  }

  String _joinList(dynamic v) =>
      v is List ? v.whereType<String>().join(', ') : '';

  List<String> _splitList(String s) => s
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _save() async {
    setState(() => _saving = true);
    final data = <String, dynamic>{
      'bio': _bio.text.trim(),
      'languages': _splitList(_languages.text),
      'specialties': _splitList(_specialties.text),
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
    final accent = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.btnEditProfile),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(l10n.fieldBio, _bio, maxLines: 4, hint: l10n.bioHint),
            _field(l10n.fieldHourlyRate, _rate,
                keyboardType: TextInputType.number, hint: l10n.rateHint),
            _field(l10n.labelLanguages, _languages, hint: l10n.languagesHint),
            _field(l10n.fieldSpecialties, _specialties, hint: l10n.specialtiesHint),
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
