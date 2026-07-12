import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_endpoints.dart';
import 'package:sampada/injection.dart' as di;
import 'package:sampada/providers/guide_provider.dart';
import 'package:sampada/features/auth/presentation/providers/auth_provider.dart';

class BecomeGuideScreen extends StatefulWidget {
  const BecomeGuideScreen({super.key});

  @override
  State<BecomeGuideScreen> createState() => _BecomeGuideScreenState();
}

class _BecomeGuideScreenState extends State<BecomeGuideScreen> {
  int _step = 0;

  // Step 1 – Personal Details
  final _fullNameController   = TextEditingController();
  final _phoneController      = TextEditingController();
  final _emailController      = TextEditingController();
  final _introController      = TextEditingController();
  String _selectedLocation    = 'Kathmandu';
  DateTime? _dateOfBirth;
  final Set<String> _languages = {'Nepali', 'English'};
  // Languages the applicant typed in via "+ Add Other" — kept apart from the
  // preset list so they can still be rendered as chips (and re-shown when an
  // existing application is loaded back in).
  final List<String> _customLanguages = [];

  // Step 2 – Expertise
  final Set<String> _specializations = {'Temples', 'Stupas'};
  String _yearsExperience = '3 – 5 years';
  final Set<String> _areas     = {'Kathmandu', 'Lalitpur', 'Bhaktapur'};
  final Set<String> _tourTypes = {'Walking Tours', 'Heritage Tours', 'Cultural Tours'};
  String _knowledgeLevel = 'Expert';

  // Profile photo (step 1)
  String? _existingPhotoUrl;
  XFile? _pickedProfilePhoto;

  // Step 3 – Verify
  XFile? _idFront;
  XFile? _idBack;
  XFile? _certification;
  final _emergencyController = TextEditingController();
  final _referralController  = TextEditingController();
  bool _confirmedAccuracy = false;
  bool _isUploading = false;

  // Application gate: block re-submitting while a submission is under review.
  bool _statusChecked = false;   // profile fetch done
  String? _appStatus;            // pending / approved / rejected / revoked / null
  bool _justSubmitted = false;   // true right after a successful submit

  final _picker = ImagePicker();

  static const _allLanguages = ['Nepali', 'English', 'Hindi', 'Chinese', 'Japanese'];
  static const _allSpecializations = [
    'Heritage Sites', 'Temples', 'Stupas', 'Durbar Squares',
    'Museums', 'Newari Culture', 'Festivals & Rituals', 'Local Food & Cuisine',
  ];
  static const _allAreas = [
    'Kathmandu', 'Lalitpur', 'Bhaktapur', 'Pokhara', 'Lumbini', 'Mustang', 'Everest Region',
  ];
  static const _allTourTypes = [
    'Walking Tours', 'Heritage Tours', 'Cultural Tours', 'Food Tours',
    'Photography Tours', 'Trekking Tours', 'Educational Tours',
  ];
  static const _locations = [
    'Kathmandu', 'Lalitpur', 'Bhaktapur', 'Pokhara', 'Chitwan', 'Lumbini', 'Mustang',
  ];
  static const _experienceLevels = [
    'Less than 1 year', '1 – 2 years', '3 – 5 years', '5 – 10 years', '10+ years',
  ];
  static const _knowledgeLevels = ['Beginner', 'Intermediate', 'Advanced', 'Expert'];

  static const Map<String, IconData> _specIcons = {
    'Heritage Sites':       Icons.account_balance,
    'Temples':              Icons.temple_hindu,
    'Stupas':               Icons.account_balance_wallet,
    'Durbar Squares':       Icons.location_city,
    'Museums':              Icons.museum,
    'Newari Culture':       Icons.people_outline,
    'Festivals & Rituals':  Icons.celebration_outlined,
    'Local Food & Cuisine': Icons.restaurant_outlined,
  };

  static const Map<String, IconData> _tourIcons = {
    'Walking Tours':     Icons.directions_walk,
    'Heritage Tours':    Icons.account_balance,
    'Cultural Tours':    Icons.palette_outlined,
    'Food Tours':        Icons.restaurant_outlined,
    'Photography Tours': Icons.camera_alt_outlined,
    'Trekking Tours':    Icons.terrain,
    'Educational Tours': Icons.school_outlined,
  };

  Future<String?> _uploadToCloudinary(XFile file, String folder) async {
    final apiClient = di.sl<ApiClient>();
    final sig = await apiClient.post(
      ApiEndpoints.uploadSignature,
      data: {'folder': folder},
    ) as Map<String, dynamic>;

    final bytes = await File(file.path).readAsBytes();
    final ext   = file.name.split('.').last.toLowerCase();
    final res   = await apiClient.dio.post<Map<String, dynamic>>(
      'https://api.cloudinary.com/v1_1/${sig['cloud_name']}/image/upload',
      data: {
        'file':      'data:image/$ext;base64,${_b64(bytes)}',
        'api_key':   sig['api_key'],
        'timestamp': sig['timestamp'].toString(),
        'signature': sig['signature'],
        'folder':    sig['folder'],
      },
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
    return res.data?['secure_url'] as String?;
  }

  String _b64(List<int> bytes) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final out = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i], b1 = i + 1 < bytes.length ? bytes[i + 1] : 0, b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      out.write(chars[(b0 >> 2) & 0x3F]);
      out.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      out.write(i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      out.write(i + 2 < bytes.length ? chars[b2 & 0x3F] : '=');
    }
    return out.toString();
  }

  /// All language chips shown in step 1: the presets plus anything typed in.
  List<String> get _languageOptions => [..._allLanguages, ..._customLanguages];

  /// Case/space-insensitive match against a language already offered or added,
  /// so "nepali " can't be added a second time alongside "Nepali".
  String? _existingLanguageMatch(String candidate) {
    final needle = candidate.toLowerCase();
    for (final l in _languageOptions) {
      if (l.toLowerCase() == needle) return l;
    }
    return null;
  }

  /// Prompts for a language not in the preset list, then adds it as a selected
  /// chip. Submitted verbatim in the `languages` list (the backend stores it as
  /// free-form JSON), so it is trimmed and length-capped here.
  Future<void> _addCustomLanguage() async {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);

    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void submit() {
              final value = controller.text.trim();
              if (value.isEmpty) {
                setDialogState(() => errorText = 'Enter a language.');
                return;
              }
              if (value.length > 30) {
                setDialogState(() => errorText = 'Keep it under 30 characters.');
                return;
              }
              if (!RegExp(r"^[\p{L}][\p{L} '\-]*$", unicode: true).hasMatch(value)) {
                setDialogState(() => errorText = 'Letters only.');
                return;
              }
              final duplicate = _existingLanguageMatch(value);
              if (duplicate != null) {
                setDialogState(() => errorText = '$duplicate is already listed.');
                return;
              }
              Navigator.pop(dialogContext, value);
            }

            return AlertDialog(
              backgroundColor: isDark ? AppColors.darkBgCard : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
              ),
              title: Text(
                'Add a language',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(dialogContext).colorScheme.onSurface,
                ),
              ),
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => submit(),
                style: TextStyle(
                  color: Theme.of(dialogContext).colorScheme.onSurface,
                  fontSize: 14,
                ),
                decoration: _inputDecor(isDark, 'e.g. Newari, French').copyWith(
                  errorText: errorText,
                  counterText: '',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : Colors.grey[700])),
                ),
                TextButton(
                  onPressed: submit,
                  child: Text('Add', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
    if (entered == null || !mounted) return;
    setState(() {
      _customLanguages.add(entered);
      _languages.add(entered);
    });
  }

  Future<void> _pickImage(void Function(XFile) onPicked) async {
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    // 5 MB size check
    final bytes = await file.length();
    if (bytes > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.fileTooLarge), backgroundColor: Colors.red),
        );
      }
      return;
    }

    // Type check: jpg / jpeg / png only
    final ext = file.name.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png'].contains(ext)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.onlyJpgPng), backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() => onPicked(file));
  }

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _fullNameController.text = user?.displayName ?? '';
    _emailController.text    = user?.email ?? '';
    _existingPhotoUrl        = user?.photoURL;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gp = context.read<GuideProvider>();
      await gp.fetchMyProfile();
      if (!mounted) return;
      final p = gp.myProfile;
      if (p != null) {
        _appStatus = p['status'] as String?;
        _introController.text = p['bio'] ?? '';
        final langs = p['languages'];
        if (langs is List) {
          _languages.clear();
          _languages.addAll(langs.cast<String>());
          // Anything saved that isn't a preset was typed in on a previous pass —
          // re-register it so it renders as a (selected) chip rather than being
          // silently dropped from the form.
          _customLanguages.addAll(
            _languages.where((l) => !_allLanguages.contains(l)),
          );
        }
        final specs = p['specialties'];
        if (specs is List) { _specializations.clear(); _specializations.addAll(specs.cast<String>()); }
      }
      setState(() => _statusChecked = true);
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _introController.dispose();
    _emergencyController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _nextStep() {
    final error = _validateStep(_step);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.red));
      return;
    }
    if (_step < 2) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  String? _validateStep(int step) {
    switch (step) {
      case 0:
        if (_existingPhotoUrl == null && _pickedProfilePhoto == null) return 'Upload a profile photo.';
        if (_fullNameController.text.trim().isEmpty) return 'Enter your full name.';
        if (_phoneController.text.trim().isEmpty)    return 'Enter your phone number.';
        if (!RegExp(r'^\d{10}$').hasMatch(_phoneController.text.trim())) return 'Phone number must be 10 digits.';
        if (_emailController.text.trim().isEmpty) return 'Enter your email address.';
        if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(_emailController.text.trim())) return 'Enter a valid email address.';
        if (_dateOfBirth == null) return 'Select your date of birth.';
        if (_dateOfBirth!.isAfter(DateTime.now())) return 'Birthdate cannot be in the future.';
        if (DateTime.now().difference(_dateOfBirth!).inDays < 365 * 18) return 'You must be at least 18 years old.';
        if (_languages.isEmpty)                      return 'Select at least one language.';
        if (_introController.text.trim().isEmpty)    return 'Write a short introduction.';
        return null;
      case 1:
        if (_specializations.isEmpty) return 'Select at least one specialization.';
        if (_areas.isEmpty)           return 'Select at least one area you guide in.';
        if (_tourTypes.isEmpty)       return 'Select at least one tour type.';
        return null;
      case 2:
        if (_idFront == null) return 'Upload government ID front side.';
        if (_idBack == null)  return 'Upload government ID back side.';
        if (_emergencyController.text.trim().isEmpty) return 'Enter emergency contact number.';
        if (!RegExp(r'^\d{10}$').hasMatch(_emergencyController.text.trim())) return 'Emergency contact must be 10 digits.';
        if (!_confirmedAccuracy) return 'Confirm that the information is true and accurate.';
        return null;
    }
    return null;
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    setState(() => _isUploading = true);
    final gp = context.read<GuideProvider>();
    try {
      // Upload all images to Cloudinary concurrently
      final results = await Future.wait([
        _pickedProfilePhoto != null
            ? _uploadToCloudinary(_pickedProfilePhoto!, 'sampada/guides/photos')
            : Future.value(_existingPhotoUrl),
        _uploadToCloudinary(_idFront!, 'sampada/guides/id'),
        _uploadToCloudinary(_idBack!,  'sampada/guides/id'),
        _certification != null
            ? _uploadToCloudinary(_certification!, 'sampada/guides/certs')
            : Future.value(null),
      ]);

      final photoUrl   = results[0];
      final idFrontUrl = results[1];
      final idBackUrl  = results[2];
      final certUrl    = results[3];

      await gp.applyAsGuide({
        'bio':               _introController.text.trim(),
        'languages':         _languages.toList(),
        'specialties':       _specializations.toList(),
        'areas':             _areas.toList(),
        'tour_types':        _tourTypes.toList(),
        'knowledge_level':   _knowledgeLevel,
        'years_experience':  _yearsExperience,
        'emergency_contact': _emergencyController.text.trim(),
        'referral_code':     _referralController.text.trim(),
        'hourly_rate':       2500.0,
        if (photoUrl   != null) 'photo_url':        photoUrl,
        if (idFrontUrl != null) 'id_front_url':     idFrontUrl,
        if (idBackUrl  != null) 'id_back_url':      idBackUrl,
        if (certUrl    != null) 'certification_url': certUrl,
        'message': [
          'Name: ${_fullNameController.text.trim()}',
          'Phone: +977 ${_phoneController.text.trim()}',
          'Email: ${_emailController.text.trim()}',
          'Location: $_selectedLocation',
          'Experience: $_yearsExperience',
          'Languages: ${_languages.join(', ')}',
          'Specializations: ${_specializations.join(', ')}',
          'Areas: ${_areas.join(', ')}',
          'Tour Types: ${_tourTypes.join(', ')}',
          'Knowledge Level: $_knowledgeLevel',
          'Bio: ${_introController.text.trim()}',
        ].join('\n'),
      });

      if (!mounted) return;
      if (gp.error == null) {
        // Show the success screen and lock the form until admin reviews.
        setState(() {
          _appStatus = 'pending';
          _justSubmitted = true;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(gp.error!), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.uploadFailed(e.toString())), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gp     = context.watch<GuideProvider>();

    // Still checking whether a submission already exists.
    if (!_statusChecked) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // A submission is under review → block the form, show the status screen.
    if (_appStatus == 'pending') {
      return _buildSubmittedScreen(context, isDark);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context, isDark),
          _buildStepIndicator(context, isDark),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_step == 0) _buildStep1(context, isDark),
                  if (_step == 1) _buildStep2(context, isDark),
                  if (_step == 2) _buildStep3(context, isDark),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: gp.isLoading || _isUploading ? null : _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg)),
                      ),
                      child: gp.isLoading || _isUploading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _step == 2 ? 'Submit for Review' : 'Save & Continue',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 8),
                                Icon(_step == 2 ? Icons.send_outlined : Icons.arrow_forward, size: 18),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildFooter(context, isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Shown after a successful submit, or when a pending application already
  // exists. Blocks re-submission until admin approves/rejects/revokes.
  Widget _buildSubmittedScreen(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final accent = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context, isDark),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        color: (isDark ? AppColors.goldMain : const Color(0xFF7B1E00)).withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle, size: 56, color: accent),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _justSubmitted ? 'Application Submitted!' : 'Application Under Review',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF3DC),
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
                      ),
                      child: Text(
                        l10n.pendingReview,
                        style: const TextStyle(color: Color(0xFF9A6200), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.applicationReviewMsg,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? AppColors.darkTextSecondary : Colors.grey[700]),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.applicationReviewNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextTertiary : Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg)),
                        ),
                        child: Text(l10n.btnBackToHome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [AppColors.brownDeep, AppColors.brownDark]
              : const [Color(0xFF5C1A0A), Color(0xFFA83210), Color(0xFFC8501A)],
          stops: isDark ? null : const [0.0, 0.6, 1.0],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
          bottomRight: Radius.circular(AppDimensions.kRadiusXxl),
        ),
      ),
      // Sizes to its content instead of a fixed screen-height fraction.
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: _prevStep,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.becomeGuide, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text(AppLocalizations.of(context)!.becomeGuideSubtitle, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context, bool isDark) {
    const steps = ['Profile', 'Expertise', 'Verify'];
    final activeColor = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    final inactiveColor = isDark ? AppColors.darkBorder : const Color(0xFFE0D5CC);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final stepIndex = i ~/ 2;
            return Expanded(
              child: Container(height: 2, color: _step > stepIndex ? activeColor : inactiveColor),
            );
          }
          final stepIndex = i ~/ 2;
          final isActive    = _step == stepIndex;
          final isCompleted = _step > stepIndex;
          return Column(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isActive || isCompleted) ? activeColor : Colors.transparent,
                  border: Border.all(
                    color: (isActive || isCompleted) ? activeColor : inactiveColor,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, size: 16, color: isDark ? Colors.black : Colors.white)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold,
                            color: isActive
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? AppColors.darkTextTertiary : Colors.grey),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                steps[stepIndex],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive ? activeColor : (isDark ? AppColors.darkTextTertiary : Colors.grey),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ─── Step 1: Personal Details ─────────────────────────────────

  Widget _buildStep1(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBar(context, isDark),
        const SizedBox(height: 24),

        // Profile photo
        Center(
          child: GestureDetector(
            onTap: () => _pickImage((f) => _pickedProfilePhoto = f),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: isDark ? AppColors.darkBgCard : const Color(0xFFF0EAE4),
                  backgroundImage: _pickedProfilePhoto != null
                      ? FileImage(File(_pickedProfilePhoto!.path))
                      : (_existingPhotoUrl != null ? NetworkImage(_existingPhotoUrl!) : null) as ImageProvider?,
                  child: (_pickedProfilePhoto == null && _existingPhotoUrl == null)
                      ? Icon(Icons.person, size: 48, color: isDark ? AppColors.darkTextTertiary : Colors.grey[400])
                      : null,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt, size: 16, color: isDark ? Colors.black : Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        _field(context, isDark, 'Full Name', 'Enter your full name', _fullNameController),
        const SizedBox(height: 16),

        _label(context, isDark, 'Phone Number'),
        const SizedBox(height: 8),
        _phoneRow(context, isDark, _phoneController, '98XXXXXXXX'),
        const SizedBox(height: 16),

        _field(context, isDark, 'Email Address', 'your@email.com', _emailController, type: TextInputType.emailAddress),
        const SizedBox(height: 16),

        _label(context, isDark, 'Location / District'),
        const SizedBox(height: 8),
        _dropdown(context, isDark, _selectedLocation, _locations, (v) => setState(() => _selectedLocation = v!)),
        const SizedBox(height: 16),

        _label(context, isDark, 'Date of Birth'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _dateOfBirth ?? DateTime(1995),
              firstDate: DateTime(1940),
              lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
            );
            if (picked != null) setState(() => _dateOfBirth = picked);
          },
          child: _dateTile(context, isDark),
        ),
        const SizedBox(height: 24),

        _secHeader(context, isDark, 'Languages Spoken', Icons.language),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context)!.selectAllApply, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ..._languageOptions.map((l) => _chip(
              context, isDark, l, _languages.contains(l),
              () => setState(() => _languages.contains(l) ? _languages.remove(l) : _languages.add(l)),
              showCheck: true,
            )),
            _outlineChip(context, isDark, '+ Add Other', onTap: _addCustomLanguage),
          ],
        ),
        const SizedBox(height: 24),

        _secHeader(context, isDark, 'Short Introduction', Icons.edit_outlined),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context)!.aboutYourselfDesc,
          style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _introController,
          maxLines: 4,
          maxLength: 300,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          decoration: _inputDecor(isDark, 'Write a short introduction...').copyWith(
            counterStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : Colors.grey, fontSize: 11),
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Guide Expertise ──────────────────────────────────

  Widget _buildStep2(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBar(context, isDark),
        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.star_outline, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.guideExpertise, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  Text(AppLocalizations.of(context)!.guideExpertiseDesc, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Primary Specialization
        _rowLabel(context, isDark, 'Primary Specialization', '(Select up to 3)'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ..._allSpecializations.map((s) {
              final sel = _specializations.contains(s);
              return _iconChip(context, isDark, s, _specIcons[s] ?? Icons.place, sel, () {
                setState(() {
                  if (sel) {
                    _specializations.remove(s);
                  } else if (_specializations.length < 3) {
                    _specializations.add(s);
                  }
                });
              });
            }),
            _outlineChip(context, isDark, '+ More'),
          ],
        ),
        const SizedBox(height: 24),

        Text(AppLocalizations.of(context)!.yearsExperience, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        _dropdown(context, isDark, _yearsExperience, _experienceLevels,
            (v) => setState(() => _yearsExperience = v!), prefixIcon: Icons.bar_chart),
        const SizedBox(height: 24),

        _rowLabel(context, isDark, 'Areas You Guide In', '(Select all that apply)'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            ..._allAreas.map((a) => _iconChip(
              context, isDark, a, Icons.location_on_outlined, _areas.contains(a),
              () => setState(() => _areas.contains(a) ? _areas.remove(a) : _areas.add(a)),
            )),
            _outlineChip(context, isDark, '+ Other'),
          ],
        ),
        const SizedBox(height: 24),

        _rowLabel(context, isDark, 'Tour Types', '(Select all that apply)'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _allTourTypes.map((t) => _iconChip(
            context, isDark, t, _tourIcons[t] ?? Icons.tour, _tourTypes.contains(t),
            () => setState(() => _tourTypes.contains(t) ? _tourTypes.remove(t) : _tourTypes.add(t)),
          )).toList(),
        ),
        const SizedBox(height: 24),

        Text(AppLocalizations.of(context)!.knowledgeLevel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 8),
        _dropdown(context, isDark, _knowledgeLevel, _knowledgeLevels,
            (v) => setState(() => _knowledgeLevel = v!), prefixIcon: Icons.bar_chart),
      ],
    );
  }

  // ─── Step 3: Verification ─────────────────────────────────────

  Widget _buildStep3(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoBar(context, isDark),
        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context)!.verification, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  Text(AppLocalizations.of(context)!.verificationDesc, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text(AppLocalizations.of(context)!.governmentId, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context)!.governmentIdDesc, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _uploadBox(context, isDark, 'Upload ID Front Side', Icons.credit_card, _idFront != null, () => _pickImage((f) => _idFront = f))),
            const SizedBox(width: 12),
            Expanded(child: _uploadBox(context, isDark, 'Upload ID Back Side', Icons.credit_card_outlined, _idBack != null, () => _pickImage((f) => _idBack = f))),
          ],
        ),
        const SizedBox(height: 24),

        Text(AppLocalizations.of(context)!.profilePhoto, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context)!.profilePhotoDesc, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
        const SizedBox(height: 12),
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: isDark ? AppColors.darkBgCard : const Color(0xFFF0EAE4),
            backgroundImage: _pickedProfilePhoto != null
                ? FileImage(File(_pickedProfilePhoto!.path))
                : (_existingPhotoUrl != null ? NetworkImage(_existingPhotoUrl!) : null) as ImageProvider?,
            child: (_pickedProfilePhoto == null && _existingPhotoUrl == null)
                ? Icon(Icons.person, size: 48, color: isDark ? AppColors.darkTextTertiary : Colors.grey[400])
                : null,
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Text(AppLocalizations.of(context)!.certification, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(width: 6),
            Text('(Optional)', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
          ],
        ),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context)!.certificationDesc, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
        const SizedBox(height: 12),
        _uploadBox(context, isDark, 'Upload Certificate', Icons.workspace_premium_outlined, _certification != null, () => _pickImage((f) => _certification = f)),
        const SizedBox(height: 24),

        Text(AppLocalizations.of(context)!.additionalInfo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 16),

        _label(context, isDark, 'Emergency Contact Number'),
        const SizedBox(height: 8),
        _phoneRow(context, isDark, _emergencyController, '98XXXXXXXX'),
        const SizedBox(height: 16),

        _field(context, isDark, 'Referral Code (Optional)', 'Enter referral code (if any)', _referralController),
        const SizedBox(height: 24),

        GestureDetector(
          onTap: () => setState(() => _confirmedAccuracy = !_confirmedAccuracy),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20, height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
                  border: Border.all(
                    color: _confirmedAccuracy
                        ? (isDark ? AppColors.goldMain : const Color(0xFF7B1E00))
                        : (isDark ? AppColors.darkBorder : Colors.grey),
                  ),
                  color: _confirmedAccuracy
                      ? (isDark ? AppColors.goldMain : const Color(0xFF7B1E00))
                      : Colors.transparent,
                ),
                child: _confirmedAccuracy
                    ? Icon(Icons.check, size: 14, color: isDark ? Colors.black : Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.confirmInfoAccurate,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Shared Widgets ───────────────────────────────────────────

  Widget _infoBar(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: isDark ? AppColors.darkBgCard : const Color(0xFFF7EED3),
              child: Icon(Icons.people_outline, size: 16, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00)),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.joinVerifiedGuides, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                Text(AppLocalizations.of(context)!.earnFromHeritage, style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : Colors.grey)),
              ],
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBgCard : const Color(0xFFF7EED3),
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
            border: isDark ? Border.all(color: AppColors.darkBorder) : null,
          ),
          child: Text(
            'NPR 2,500 / day avg',
            style: TextStyle(color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00), fontWeight: FontWeight.bold, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    const data = [
      (Icons.list_alt_outlined, 'What happens next?', 'Our team will review your application and verify your details.'),
      (Icons.access_time_outlined, 'What happens next?', 'You\'ll be notified within 1 – 2 business days via email or app.'),
      (Icons.bookmark_outline, 'What happens next?', 'Once approved, you can start receiving bookings and earning!'),
    ];
    final (icon, title, body) = data[_step];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : const Color(0xFFF7EED3),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00), size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                Text(body, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _secHeader(BuildContext context, bool isDark, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00)),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
      ],
    );
  }

  Widget _rowLabel(BuildContext context, bool isDark, String main, String sub) {
    return Row(
      children: [
        Text(main, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(width: 6),
        Text(sub, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
      ],
    );
  }

  Widget _label(BuildContext context, bool isDark, String text) {
    return Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextTertiary : Colors.grey));
  }

  InputDecoration _inputDecor(bool isDark, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : Colors.grey, fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: isDark,
      fillColor: isDark ? AppColors.darkBgCard : Colors.transparent,
      border:        OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg), borderSide: BorderSide(color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00))),
    );
  }

  Widget _field(BuildContext context, bool isDark, String label, String hint, TextEditingController ctrl, {int maxLines = 1, TextInputType type = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, isDark, label),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: type,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          decoration: _inputDecor(isDark, hint),
        ),
      ],
    );
  }

  Widget _phoneRow(BuildContext context, bool isDark, TextEditingController ctrl, String hint) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          decoration: BoxDecoration(
            border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
            color: isDark ? AppColors.darkBgCard : Colors.transparent,
          ),
          child: Row(
            children: [
              Text('+977', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 16, color: isDark ? AppColors.darkTextTertiary : Colors.grey),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
            decoration: _inputDecor(isDark, hint),
          ),
        ),
      ],
    );
  }

  Widget _dateTile(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        color: isDark ? AppColors.darkBgCard : Colors.transparent,
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 16, color: isDark ? AppColors.darkTextTertiary : Colors.grey),
          const SizedBox(width: 8),
          Text(
            _dateOfBirth != null
                ? '${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}'
                : 'Select your date of birth',
            style: TextStyle(
              fontSize: 14,
              color: _dateOfBirth != null
                  ? Theme.of(context).colorScheme.onSurface
                  : (isDark ? AppColors.darkTextTertiary : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(BuildContext context, bool isDark, String value, List<String> items, ValueChanged<String?> onChanged, {IconData? prefixIcon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        color: isDark ? AppColors.darkBgCard : Colors.transparent,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down),
          iconEnabledColor: Colors.grey,
          dropdownColor: isDark ? AppColors.darkBgCard : Colors.white,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          items: items.map((e) => DropdownMenuItem(
            value: e,
            child: Row(
              children: [
                if (prefixIcon != null) ...[
                  Icon(prefixIcon, size: 16, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00)),
                  const SizedBox(width: 8),
                ],
                Text(e),
              ],
            ),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, bool isDark, String label, bool selected, VoidCallback onTap, {bool showCheck = false}) {
    final activeBg   = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    final inactiveBg = isDark ? AppColors.darkBgCard : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(color: selected ? activeBg : (isDark ? AppColors.darkBorder : const Color(0xFFE0D5CC))),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? (isDark ? Colors.black : Colors.white) : (isDark ? AppColors.darkTextSecondary : Colors.grey[700]),
              ),
            ),
            if (selected && showCheck) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, size: 12, color: isDark ? Colors.black : Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconChip(BuildContext context, bool isDark, String label, IconData icon, bool selected, VoidCallback onTap) {
    final activeBg   = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    final inactiveBg = isDark ? AppColors.darkBgCard : Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(color: selected ? activeBg : (isDark ? AppColors.darkBorder : const Color(0xFFE0D5CC))),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon, size: 14,
              color: selected ? (isDark ? Colors.black : Colors.white) : (isDark ? AppColors.darkTextTertiary : Colors.grey[600]),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? (isDark ? Colors.black : Colors.white) : (isDark ? AppColors.darkTextSecondary : Colors.grey[700]),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check, size: 12, color: isDark ? Colors.black : Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  /// Without [onTap] this is a static affordance — the "+ More" / "+ Other"
  /// chips on step 2 are still inert.
  Widget _outlineChip(BuildContext context, bool isDark, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgCard : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE0D5CC)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : Colors.grey[600])),
      ),
    );
  }

  Widget _uploadBox(BuildContext context, bool isDark, String label, IconData icon, bool uploaded, VoidCallback onTap) {
    final accentColor = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgCard : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
          border: Border.all(
            color: uploaded ? accentColor : (isDark ? AppColors.darkBorder : const Color(0xFFCCBCAF)),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            Icon(uploaded ? Icons.check_circle : icon, color: accentColor, size: 28),
            const SizedBox(height: 8),
            Text(
              uploaded ? 'Uploaded' : label,
              textAlign: TextAlign.center,
              style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            if (!uploaded) ...[
              const SizedBox(height: 4),
              Text(AppLocalizations.of(context)!.fileTypeHint, textAlign: TextAlign.center, style: TextStyle(color: isDark ? AppColors.darkTextTertiary : Colors.grey, fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}
