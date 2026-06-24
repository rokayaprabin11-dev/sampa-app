import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/providers/guide_provider.dart';
import 'package:sampada/features/auth/presentation/providers/auth_provider.dart';
import 'guide_terms_screen.dart';

class BecomeGuideScreen extends StatefulWidget {
  const BecomeGuideScreen({super.key});

  @override
  State<BecomeGuideScreen> createState() => _BecomeGuideScreenState();
}

class _BecomeGuideScreenState extends State<BecomeGuideScreen> {
  final _fullNameController    = TextEditingController();
  final _phoneController       = TextEditingController();
  final _locationController    = TextEditingController();
  final _bioController         = TextEditingController();
  final _yearsController       = TextEditingController();
  final _halfDayController     = TextEditingController();
  final _fullDayController     = TextEditingController();

  final Set<String> _languages       = {'Nepali', 'English'};
  final Set<String> _specializations = {'Temples', 'Stupas'};
  bool _agreedToTerms = false;
  bool _submitted = false;

  static const _allLanguages = ['Nepali', 'English', 'Hindi', 'Tibetan', 'Chinese', 'Japanese'];
  static const _allSpecializations = [
    'Temples', 'Stupas', 'Palaces', 'Durbar Squares',
    'Newari Culture', 'Trekking', 'Photography', 'Buddhism',
  ];

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _fullNameController.text = user?.displayName ?? '';

    // Check if already applied
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gp = context.read<GuideProvider>();
      await gp.fetchMyProfile();
      if (mounted && gp.myProfile != null) {
        final p = gp.myProfile!;
        _bioController.text = p['bio'] ?? '';
        final langs = p['languages'];
        if (langs is List) {
          _languages.clear();
          _languages.addAll(langs.cast<String>());
        }
        final specs = p['specialties'];
        if (specs is List) {
          _specializations.clear();
          _specializations.addAll(specs.cast<String>());
        }
        if (p['hourly_rate'] != null) {
          _halfDayController.text = p['hourly_rate'].toString();
        }
        setState(() => _submitted = p['status'] != null);
      }
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    _yearsController.dispose();
    _halfDayController.dispose();
    _fullDayController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms & Code of Conduct.')),
      );
      return;
    }
    if (_bioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a guide bio.')),
      );
      return;
    }

    final message = '''
Name: ${_fullNameController.text.trim()}
Phone: ${_phoneController.text.trim()}
Location: ${_locationController.text.trim()}
Experience: ${_yearsController.text.trim()} years
Languages: ${_languages.join(', ')}
Specializations: ${_specializations.join(', ')}
Half Day Rate (NPR): ${_halfDayController.text.trim()}
Full Day Rate (NPR): ${_fullDayController.text.trim()}

Bio:
${_bioController.text.trim()}
'''.trim();

    final hourly = double.tryParse(_halfDayController.text.trim().replaceAll(',', ''));

    await context.read<GuideProvider>().applyAsGuide({
      'message': message,
      'bio': _bioController.text.trim(),
      'languages': _languages.toList(),
      'specialties': _specializations.toList(),
      if (hourly != null) 'hourly_rate': hourly,
    });

    if (!mounted) return;
    final gp = context.read<GuideProvider>();
    if (gp.error == null) {
      setState(() => _submitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Application submitted! You\'ll be notified within 3–5 business days.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(gp.error!), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size  = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gp    = context.watch<GuideProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          Stack(
            children: [
              Container(
                height: size.height * 0.15,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      isDark ? AppColors.brownDeep : const Color(0xFF5D1700),
                      isDark ? AppColors.brownDark : const Color(0xFF9E3D1A),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Become a Guide', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          Text('Share your heritage knowledge', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Join verified guides', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                          Text('Earn from sharing Nepal\'s\nliving heritage', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBgCard : const Color(0xFFF7EED3),
                          borderRadius: BorderRadius.circular(20),
                          border: isDark ? Border.all(color: AppColors.darkBorder) : null,
                        ),
                        child: Text(
                          'NPR 2,500 / day avg',
                          style: TextStyle(color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),

                  // Already applied banner
                  if (_submitted) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1B3A26) : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? const Color(0xFF2E7D32) : const Color(0xFF3DA35D)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF3DA35D)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Application Submitted', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3DA35D))),
                                Text(
                                  gp.myProfile?['status'] == 'approved'
                                      ? 'Your guide profile is active!'
                                      : 'Under review. You\'ll be notified via push notification.',
                                  style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Personal Details
                  _sectionHeader(context, isDark, 'Personal Details'),
                  const SizedBox(height: 16),
                  _field(context, isDark, 'Full Name', 'Enter your full name', _fullNameController),
                  const SizedBox(height: 16),
                  _field(context, isDark, 'Phone Number', '+977-XXXXXXXXXX', _phoneController, type: TextInputType.phone),
                  const SizedBox(height: 16),
                  _field(context, isDark, 'Location / District', 'e.g. Kathmandu', _locationController),
                  const SizedBox(height: 16),

                  Text('Languages Spoken', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      ..._allLanguages.map((l) => _chip(context, isDark, l, _languages.contains(l), () => setState(() => _languages.contains(l) ? _languages.remove(l) : _languages.add(l)))),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Expertise
                  _sectionHeader(context, isDark, 'Guide Expertise'),
                  const SizedBox(height: 16),
                  Text('Specializations', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      ..._allSpecializations.map((s) => _chip(context, isDark, s, _specializations.contains(s), () => setState(() => _specializations.contains(s) ? _specializations.remove(s) : _specializations.add(s)))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _field(context, isDark, 'Years of Experience', 'e.g. 3', _yearsController, type: TextInputType.number),
                  const SizedBox(height: 16),
                  _field(context, isDark, 'Guide Bio', 'Describe your experience with Nepal\'s heritage...', _bioController, maxLines: 4),

                  const SizedBox(height: 24),
                  Text('Pricing (NPR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _field(context, isDark, 'Half Day', '2,500', _halfDayController, type: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: _field(context, isDark, 'Full Day', '3,000–6,000', _fullDayController, type: TextInputType.number)),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Terms
                  Row(
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                        activeColor: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
                        side: isDark ? BorderSide(color: AppColors.darkBorder) : null,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuideTermsScreen())),
                          child: Text.rich(
                            TextSpan(
                              text: 'I agree to ',
                              children: [
                                TextSpan(
                                  text: 'Sampada\'s Guide Terms & Code of Conduct',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00), decoration: TextDecoration.underline),
                                ),
                              ],
                            ),
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: gp.isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: gp.isLoading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(_submitted ? 'Update Application' : 'Submit Guide Application', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Text('Applications reviewed within 3–5 business days.', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
                        Text('You will be notified via push notification.', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, bool isDark, String title) {
    return Row(
      children: [
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFF8C7162), letterSpacing: 0.5)),
        const SizedBox(width: 16),
        Expanded(child: Divider(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3))),
      ],
    );
  }

  Widget _field(BuildContext context, bool isDark, String label, String hint, TextEditingController ctrl, {int maxLines = 1, TextInputType type = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: type,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : Colors.grey, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: isDark,
            fillColor: isDark ? AppColors.darkBgCard : Colors.transparent,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00))),
          ),
        ),
      ],
    );
  }

  Widget _chip(BuildContext context, bool isDark, String label, bool selected, VoidCallback onTap) {
    final activeBg   = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    final inactiveBg = isDark ? AppColors.darkBgCard : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? activeBg : (isDark ? AppColors.darkBorder : const Color(0xFFF7EED3))),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? (isDark ? Colors.black : Colors.white) : (isDark ? AppColors.darkTextSecondary : Colors.grey),
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
