import 'package:flutter/material.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:sampada/providers/auth_provider.dart';
import 'package:sampada/providers/guide_provider.dart';

class GuideDetailScreen extends StatefulWidget {
  final Map<String, dynamic> guide;

  const GuideDetailScreen({super.key, required this.guide});

  @override
  State<GuideDetailScreen> createState() => _GuideDetailScreenState();
}

class _GuideDetailScreenState extends State<GuideDetailScreen> {
  bool _bookingExpanded = false;
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _notesController = TextEditingController();
  bool _submitting = false;

  // Package booking state (used when the guide has configured packages).
  int? _packageIndex;
  int _groupSize = 1;

  List<Map<String, dynamic>> get _packages =>
      ((widget.guide['packages'] as List?) ?? [])
          .whereType<Map>()
          .map((m) => m.cast<String, dynamic>())
          .toList();

  int get _includedGroupSize =>
      int.tryParse('${widget.guide['included_group_size'] ?? 5}') ?? 5;
  int get _maxGroupSize =>
      int.tryParse('${widget.guide['max_group_size'] ?? 10}') ?? 10;
  double get _extraPersonFee =>
      double.tryParse('${widget.guide['extra_person_fee'] ?? 0}') ?? 0;

  /// Live client-side preview; the server computes the authoritative price.
  double? get _previewTotal {
    if (_packageIndex == null) return null;
    final pkg = _packages[_packageIndex!];
    final base = double.tryParse('${pkg['price']}');
    if (base == null) return null;
    final extras = (_groupSize - _includedGroupSize).clamp(0, 1000);
    return base + extras * _extraPersonFee;
  }

  /// End time derived from the chosen package's duration, for display and for
  /// the request payload (the server re-derives and overrides it anyway).
  TimeOfDay? get _derivedEndTime {
    if (_packageIndex == null || _startTime == null) return null;
    final hours = double.tryParse('${_packages[_packageIndex!]['hours']}');
    if (hours == null) return null;
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = startMinutes + (hours * 60).round();
    if (endMinutes >= 24 * 60) return null; // past midnight — server rejects too
    return TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load own guide profile (self-booking block) + bookings (pending block).
      // Auth-gated — a logged-out browser would just get a 401.
      if (context.read<AuthProvider>().isAuthenticated) {
        final gp = context.read<GuideProvider>();
        gp.fetchMyProfile();
        gp.fetchMyBookings();
      }
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitBooking() async {
    final usePackages = _packages.isNotEmpty;
    final endTime = usePackages ? _derivedEndTime : _endTime;

    if (usePackages && _packageIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a tour package first.')),
      );
      return;
    }
    if (usePackages && _startTime != null && endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('That start time would run the tour past midnight.')),
      );
      return;
    }
    if (_selectedDate == null || _startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.selectDateTimeSlot)),
      );
      return;
    }

    final guideId = widget.guide['id'];
    if (guideId == null) return;

    setState(() => _submitting = true);
    try {
      final guideProvider = context.read<GuideProvider>();
      await guideProvider.createBooking({
        'guide': guideId,
        'date': _selectedDate!.toIso8601String().split('T').first,
        'start_time': '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}:00',
        'end_time': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00',
        'notes': _notesController.text,
        if (usePackages) 'package_index': _packageIndex,
        if (usePackages) 'group_size': _groupSize,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.bookingRequestSent),
          backgroundColor: AppColors.statusSuccess,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.bookingFailed(e.toString())), backgroundColor: AppColors.statusError),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final guide = widget.guide;
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final fullName = (user['full_name'] ?? user['username'] ?? 'Guide').toString();
    final initials = fullName.split(' ').take(2).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
    final photoUrl = guide['photo_url'] as String?;
    final bio = (guide['bio'] as String?) ?? '';
    final rating = double.tryParse('${guide['rating_avg'] ?? ''}') ?? 0.0;
    final reviewCount = (guide['review_count'] as int?) ?? 0;
    final rate = guide['hourly_rate'];
    final specialties = ((guide['specialties'] as List?) ?? []).cast<String>();
    final languages = ((guide['languages'] as List?) ?? []).cast<String>();
    final isVerified = (guide['is_verified'] as bool?) ?? false;

    final gp = context.watch<GuideProvider>();
    final myProfile = gp.myProfile;
    final isSelf = myProfile != null && myProfile['id'] != null && myProfile['id'] == guide['id'];
    final hasPending = guide['id'] is int && gp.hasPendingWith(guide['id'] as int);

    final bgGradient = [
      isDark ? AppColors.brownDeep : const Color(0xFF5D1700),
      isDark ? AppColors.brownDark : const Color(0xFF9E3D1A),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── App bar / hero ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: bgGradient.first,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: bgGradient,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: isDark ? AppColors.darkBgCard : const Color(0xFF3A241C),
                          child: (photoUrl != null && photoUrl.isNotEmpty)
                              ? ClipOval(
                                  child: AppNetworkImage(url: photoUrl, width: 96, height: 96, cloudinaryWidth: 96),
                                )
                              : Text(initials, style: const TextStyle(color: AppColors.kColorBgWarm, fontSize: 28, fontWeight: FontWeight.bold)),
                        ),
                        if (isVerified)
                          Positioned(
                            bottom: 4, right: 4,
                            child: Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.statusSuccess,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 10),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: AppColors.kColorBgWarm, size: 16),
                        const SizedBox(width: 4),
                        Text(rating.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Text('($reviewCount reviews)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rate + verified badge row. Package guides advertise their
                  // cheapest package; hourly guides keep the per-hour label.
                  Row(
                    children: [
                      if (_priceHeadline(rate) != null) ...[
                        Text(
                          _priceHeadline(rate)!,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00)),
                        ),
                        const Spacer(),
                      ],
                      if (isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFFF7EED3), borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm)),
                          child: const Text('✓ VERIFIED', style: TextStyle(color: AppColors.kColorAccentSafe, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Bio
                  if (bio.isNotEmpty) ...[
                    _sectionTitle(context, 'About'),
                    const SizedBox(height: 8),
                    Text(bio, style: TextStyle(fontSize: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, height: 1.6)),
                    const SizedBox(height: 20),
                  ],

                  // Specialties
                  if (specialties.isNotEmpty) ...[
                    _sectionTitle(context, 'Specialties'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: specialties.map((s) => _chip(context, s)).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Languages
                  if (languages.isNotEmpty) ...[
                    _sectionTitle(context, 'Languages'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: languages.map((l) => _chip(context, l, icon: Icons.language)).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Book section — hidden for the guide's own profile.
                  if (isSelf)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkBgCard : const Color(0xFFF5EFEC),
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
                        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE0D5CC)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'This is your guide profile — you can\'t book yourself.',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (hasPending)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF3DC),
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
                        border: Border.all(color: const Color(0xFFEAD9A8)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.hourglass_top, color: Color(0xFF9A6200), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.hirePendingBanner,
                              style: const TextStyle(color: Color(0xFF9A6200), fontSize: 13.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                  GestureDetector(
                    onTap: () {
                      if (!context.read<AuthProvider>().isAuthenticated) {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(l10n.loginRequired),
                            content: Text(l10n.loginRequiredDesc),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(l10n.btnCancel),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, AppStrings.loginPath);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B1E00)),
                                child: Text(l10n.login, style: const TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      setState(() => _bookingExpanded = !_bookingExpanded);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          isDark ? const Color(0xFF2A1A0A) : const Color(0xFF3A241C),
                          isDark ? const Color(0xFF3A2010) : const Color(0xFF7B1E00),
                        ]),
                        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: AppColors.kColorBgWarm, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(l10n.btnBookThisGuide, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          Icon(_bookingExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white70),
                        ],
                      ),
                    ),
                  ),

                  if (_bookingExpanded) ...[
                    const SizedBox(height: 16),
                    _buildBookingForm(context, isDark),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingForm(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    final cardColor = isDark ? AppColors.darkBgCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFF7EED3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date picker
          _fieldLabel(context, 'Select Date'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                initialEntryMode: DatePickerEntryMode.calendarOnly,
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    datePickerTheme: DatePickerThemeData(
                      headerBackgroundColor: const Color(0xFF7B1E00),
                      headerForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl)),
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE5DDD8)),
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: isDark ? AppColors.goldMain : AppColors.brownDark),
                  const SizedBox(width: 10),
                  Text(
                    _selectedDate != null
                        ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
                        : 'Choose a date',
                    style: TextStyle(color: _selectedDate != null ? Theme.of(context).colorScheme.onSurface : AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_packages.isNotEmpty) ...[
            // Package selector — duration comes from the package, so only a
            // start time is picked; end time is derived.
            _fieldLabel(context, 'Tour Package'),
            const SizedBox(height: 8),
            ..._packages.asMap().entries.map((e) => _packageOption(context, isDark, e.key, e.value)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _timePicker(context, isDark, label: 'Start Time', value: _startTime, onPicked: (t) => setState(() => _startTime = t))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel(context, 'Ends At'),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBgSurface : const Color(0xFFF7F3EE),
                          borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 15, color: isDark ? AppColors.goldMain : AppColors.brownDark),
                            const SizedBox(width: 8),
                            Text(
                              _derivedEndTime?.format(context) ?? '--:--',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _fieldLabel(context, 'Group Size'),
            const SizedBox(height: 8),
            _groupSizeStepper(context, isDark),
            const SizedBox(height: 16),
          ] else ...[
            // Legacy hourly flow: guide has no packages, free start/end times.
            Row(
              children: [
                Expanded(child: _timePicker(context, isDark, label: 'Start Time', value: _startTime, onPicked: (t) => setState(() => _startTime = t))),
                const SizedBox(width: 12),
                Expanded(child: _timePicker(context, isDark, label: 'End Time', value: _endTime, onPicked: (t) => setState(() => _endTime = t))),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Notes
          _fieldLabel(context, 'Notes (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: l10n.specialRequestsHint,
              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE5DDD8))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE5DDD8))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd), borderSide: const BorderSide(color: Color(0xFF7B1E00))),
            ),
          ),

          if (_packages.isNotEmpty && _previewTotal != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBgSurface : const Color(0xFFFDF3DC),
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
                border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFEAD9A8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary)),
                        if (_groupSize > _includedGroupSize)
                          Text(
                            '${_packages[_packageIndex!]['label']} + ${_groupSize - _includedGroupSize} extra ${_groupSize - _includedGroupSize == 1 ? 'person' : 'people'}',
                            style: TextStyle(
                                fontSize: 11,
                                color: isDark ? AppColors.darkTextTertiary : AppColors.kColorTextMuted),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    'NPR ${_previewTotal!.toStringAsFixed(_previewTotal! % 1 == 0 ? 0 : 2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.goldMain : const Color(0xFF3A241C),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg)),
              ),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l10n.confirmBookingRequest, style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  /// "From NPR 1500" for package guides (cheapest package), "NPR 700 / hr"
  /// for hourly guides, null when neither is configured.
  String? _priceHeadline(dynamic rate) {
    final prices = _packages
        .map((p) => double.tryParse('${p['price']}'))
        .whereType<double>()
        .toList();
    if (prices.isNotEmpty) {
      final min = prices.reduce((a, b) => a < b ? a : b);
      return 'From NPR ${min.toStringAsFixed(min % 1 == 0 ? 0 : 2)}';
    }
    if (rate != null) return 'NPR $rate / hr';
    return null;
  }

  Widget _packageOption(BuildContext context, bool isDark, int index, Map<String, dynamic> pkg) {
    final selected = _packageIndex == index;
    final hours = pkg['hours'];
    final hoursLabel = (hours is num && hours == hours.roundToDouble())
        ? '${hours.toInt()}h'
        : '${hours}h';
    final price = double.tryParse('${pkg['price']}');
    final priceLabel = price == null
        ? '${pkg['price']}'
        : price.toStringAsFixed(price % 1 == 0 ? 0 : 2);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _packageIndex = index),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? (isDark
                    ? AppColors.goldMain.withValues(alpha: 0.10)
                    : const Color(0xFF7B1E00).withValues(alpha: 0.06))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
            border: Border.all(
              color: selected
                  ? (isDark ? AppColors.goldMain : const Color(0xFF7B1E00))
                  : (isDark ? AppColors.darkBorder : const Color(0xFFE5DDD8)),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected
                    ? (isDark ? AppColors.goldMain : const Color(0xFF7B1E00))
                    : AppColors.kColorTextMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${pkg['label']}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Text('$hoursLabel · NPR $priceLabel',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.goldMain : AppColors.kColorAccentSafe,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupSizeStepper(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE5DDD8)),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_groupSize ${_groupSize == 1 ? 'person' : 'people'}',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface)),
                Text(
                  _extraPersonFee > 0
                      ? 'Up to $_includedGroupSize included · NPR ${_extraPersonFee.toStringAsFixed(_extraPersonFee % 1 == 0 ? 0 : 2)}/extra person'
                      : 'Up to $_maxGroupSize people',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.kColorTextMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _groupSize > 1 ? () => setState(() => _groupSize--) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
          ),
          IconButton(
            onPressed: _groupSize < _maxGroupSize ? () => setState(() => _groupSize++) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
          ),
        ],
      ),
    );
  }

  Widget _timePicker(BuildContext context, bool isDark, {required String label, required TimeOfDay? value, required ValueChanged<TimeOfDay> onPicked}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, label),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
            if (picked != null) onPicked(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFE5DDD8)),
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusMd),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 15, color: isDark ? AppColors.goldMain : AppColors.brownDark),
                const SizedBox(width: 8),
                Text(
                  value != null ? value.format(context) : '--:--',
                  style: TextStyle(color: value != null ? Theme.of(context).colorScheme.onSurface : AppColors.textTertiary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: isDark ? AppColors.goldMain : const Color(0xFF4A342B)),
    );
  }

  Widget _fieldLabel(BuildContext context, String label) {
    return Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textTertiary));
  }

  Widget _chip(BuildContext context, String label, {IconData? icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : const Color(0xFFF5EFEC),
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary), const SizedBox(width: 4)],
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        ],
      ),
    );
  }
}
