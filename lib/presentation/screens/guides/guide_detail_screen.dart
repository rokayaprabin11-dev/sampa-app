import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
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
    if (_selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date and time slot.')),
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
        'end_time': '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}:00',
        'notes': _notesController.text,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking request sent! The guide will confirm shortly.'),
          backgroundColor: AppColors.statusSuccess,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: ${e.toString()}'), backgroundColor: AppColors.statusError),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(initials, style: const TextStyle(color: Color(0xFFDCA73A), fontSize: 28, fontWeight: FontWeight.bold))
                              : null,
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
                        const Icon(Icons.star, color: Color(0xFFDCA73A), size: 16),
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
                  // Rate + verified badge row
                  Row(
                    children: [
                      if (rate != null) ...[
                        Text(
                          'NPR $rate / hr',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00)),
                        ),
                        const Spacer(),
                      ],
                      if (isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFFF7EED3), borderRadius: BorderRadius.circular(6)),
                          child: const Text('✓ VERIFIED', style: TextStyle(color: Color(0xFFDCA73A), fontSize: 11, fontWeight: FontWeight.bold)),
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
                        borderRadius: BorderRadius.circular(16),
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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFEAD9A8)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.hourglass_top, color: Color(0xFF9A6200), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Request pending — you can hire this guide again once they respond.',
                              style: TextStyle(color: Color(0xFF9A6200), fontSize: 13.5, fontWeight: FontWeight.w500),
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
                            title: const Text('Login Required'),
                            content: const Text('You need to be logged in to book a guide.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(context, AppStrings.loginPath);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7B1E00)),
                                child: const Text('Login', style: TextStyle(color: Colors.white)),
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
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFFDCA73A), size: 20),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text('Book This Guide', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
    final cardColor = isDark ? AppColors.darkBgCard : Colors.white;
    final borderColor = isDark ? AppColors.darkBorder : const Color(0xFFF7EED3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                borderRadius: BorderRadius.circular(10),
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

          // Start / end time row
          Row(
            children: [
              Expanded(child: _timePicker(context, isDark, label: 'Start Time', value: _startTime, onPicked: (t) => setState(() => _startTime = t))),
              const SizedBox(width: 12),
              Expanded(child: _timePicker(context, isDark, label: 'End Time', value: _endTime, onPicked: (t) => setState(() => _endTime = t))),
            ],
          ),

          const SizedBox(height: 16),

          // Notes
          _fieldLabel(context, 'Notes (optional)'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Any special requests, sites to visit...',
              hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE5DDD8))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : const Color(0xFFE5DDD8))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF7B1E00))),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submitBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.goldMain : const Color(0xFF3A241C),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Confirm Booking Request', style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
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
              borderRadius: BorderRadius.circular(10),
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
        borderRadius: BorderRadius.circular(20),
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
