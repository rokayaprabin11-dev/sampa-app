import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/providers/guide_provider.dart';
import 'package:sampada/presentation/screens/guides/guide_detail_screen.dart';

/// Guide's own listing dashboard. Reached from the Profile screen once the
/// guide application has been approved (status == 'approved').
class GuideProfileScreen extends StatefulWidget {
  const GuideProfileScreen({super.key});

  @override
  State<GuideProfileScreen> createState() => _GuideProfileScreenState();
}

class _GuideProfileScreenState extends State<GuideProfileScreen> {
  // Local-only settings toggles. No backend fields yet — defaults are sensible
  // and reset each visit. TODO: persist via PATCH /guides/me/ when supported.
  bool _availableForBookings = true;
  bool _bookingNotifications = true;
  bool _autoAccept = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Refresh in case we arrived without a recent fetch.
      final gp = context.read<GuideProvider>();
      gp.fetchMyProfile();
      gp.fetchIncomingBookings();
    });
  }

  Color _accent(bool isDark) => isDark ? AppColors.goldMain : const Color(0xFF7B1E00);

  // DRF serializes DecimalField (rating_avg, hourly_rate) as a String.
  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final gp = context.watch<GuideProvider>();
    final p = gp.myProfile;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context, isDark, size),
          if (p == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBar(context, isDark, p),
                    const SizedBox(height: 20),
                    _buildBookingRequests(context, isDark, gp),
                    _buildListingCard(context, isDark, p),
                    const SizedBox(height: 16),
                    _buildStatsCard(context, isDark, p),
                    const SizedBox(height: 24),
                    _buildSettings(context, isDark),
                    const SizedBox(height: 24),
                    _buildActions(context, isDark, p),
                    const SizedBox(height: 20),
                    _buildEarnings(context, isDark),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Booking requests (accept / reject) ───────────────────────

  Future<void> _respond(int bookingId, String action) async {
    final err = await context.read<GuideProvider>().respondToBooking(bookingId, action);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(err ?? (action == 'accept' ? 'Booking accepted.' : 'Booking declined.')),
    ));
  }

  Widget _buildBookingRequests(BuildContext context, bool isDark, GuideProvider gp) {
    final pending = gp.incomingBookings.where((b) => b['status'] == 'pending').toList();
    if (pending.isEmpty) return const SizedBox.shrink();
    final accent = _accent(isDark);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('BOOKING REQUESTS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8, color: accent)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(20)),
              child: Text('${pending.length}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.black : Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...pending.map((b) => _requestCard(context, isDark, b)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _requestCard(BuildContext context, bool isDark, Map<String, dynamic> b) {
    final id = b['id'] as int;
    final name = (b['tourist_name'] ?? 'Tourist').toString();
    final date = (b['date'] ?? '').toString();
    String t(dynamic v) => (v ?? '').toString().length >= 5 ? (v).toString().substring(0, 5) : (v ?? '').toString();
    final when = '$date · ${t(b['start_time'])}–${t(b['end_time'])}';
    final notes = (b['notes'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isDark ? AppColors.darkBgCard : const Color(0xFF7B1E00),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Color(0xFFDCA73A), fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(when, style: TextStyle(fontSize: 11.5, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
                  ],
                ),
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(notes, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B5041))),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _respond(id, 'reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC0392B),
                    side: const BorderSide(color: Color(0xFFE0B4AE)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _respond(id, 'accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark, Size size) {
    return Stack(
      children: [
        Container(
          height: size.height * 0.14,
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
                const SizedBox(width: 8),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Guide Profile', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('Manage your listing', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Verified / Active status bar ─────────────────────────────

  Widget _buildStatusBar(BuildContext context, bool isDark, Map<String, dynamic> p) {
    final isVerified = (p['is_verified'] as bool?) ?? false;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : const Color(0xFFE8F5EC),
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, color: AppColors.statusSuccess, size: 10),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isVerified ? 'Verified Guide · Active' : 'Active',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF2E5A3A),
              ),
            ),
          ),
          _outlineButton(context, isDark, 'Edit Listing', _onEdit),
        ],
      ),
    );
  }

  // ─── Main listing card ────────────────────────────────────────

  Widget _buildListingCard(BuildContext context, bool isDark, Map<String, dynamic> p) {
    final accent = _accent(isDark);
    final user = p['user'] as Map<String, dynamic>? ?? {};
    final fullName = (user['full_name'] ?? user['username'] ?? 'Guide').toString();
    final initials = fullName.split(' ').take(2).map((s) => s.isNotEmpty ? s[0].toUpperCase() : '').join();
    final photoUrl = p['photo_url'] as String?;
    final rate = p['hourly_rate'];
    final rating = _toDouble(p['rating_avg']);
    final reviewCount = (p['review_count'] as int?) ?? 0;
    final isVerified = (p['is_verified'] as bool?) ?? false;
    final isTopGuide = rating >= 4.5 && reviewCount >= 10;
    final specialties = ((p['specialties'] as List?) ?? []).cast<String>();
    final languages = ((p['languages'] as List?) ?? []).cast<String>();
    final areas = ((p['areas'] as List?) ?? []).cast<String>();
    final location = areas.isNotEmpty ? areas.first : 'Nepal';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: isDark ? AppColors.darkBgCard : const Color(0xFF3A241C),
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? Text(initials, style: const TextStyle(color: Color(0xFFDCA73A), fontSize: 18, fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(location, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
                  ],
                ),
              ),
              if (rate != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('NPR $rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: accent)),
                    Text('per hour', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Badges
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              if (isTopGuide) _badge(isDark, '⭐ Top Guide', const Color(0xFFFDF3DC), const Color(0xFF9A6200)),
              if (isVerified) _badge(isDark, '✓ Verified', const Color(0xFFE8F5EC), const Color(0xFF2E7D32)),
            ],
          ),
          if (specialties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: specialties.map((s) => _softChip(context, isDark, s, accent.withValues(alpha: 0.35))).toList(),
            ),
          ],
          if (languages.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: languages.map((l) => _softChip(context, isDark, l, isDark ? AppColors.darkBorder : const Color(0xFFE0D5CC))).toList(),
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBgCard : const Color(0xFFFBF6EC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.star, color: Color(0xFFDCA73A), size: 16),
                const SizedBox(width: 4),
                Text('${rating.toStringAsFixed(1)} ($reviewCount reviews)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _availableForBookings ? 'Available today 9 AM – 6 PM' : 'Not accepting bookings',
                    style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats ────────────────────────────────────────────────────

  Widget _buildStatsCard(BuildContext context, bool isDark, Map<String, dynamic> p) {
    final reviewCount = (p['review_count'] as int?) ?? 0;
    final rating = _toDouble(p['rating_avg']);
    final yearsExp = (p['years_experience'] as String?) ?? '—';
    // Tours-done has no backend source yet. TODO: wire when a guide-side
    // bookings/tours endpoint exists.
    const toursDone = 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat(context, isDark, '$reviewCount', 'Reviews'),
          _statDivider(isDark),
          _stat(context, isDark, '$toursDone', 'Tours Done'),
          _statDivider(isDark),
          _stat(context, isDark, rating.toStringAsFixed(1), 'Rating'),
          _statDivider(isDark),
          _stat(context, isDark, _shortExperience(yearsExp), 'Active'),
        ],
      ),
    );
  }

  String _shortExperience(String raw) {
    // '3 – 5 years' → '3–5y', '10+ years' → '10+y', fallback to raw.
    final digits = RegExp(r'\d+\+?').allMatches(raw).map((m) => m.group(0)).toList();
    if (digits.isEmpty) return '—';
    return '${digits.join('–')}y';
  }

  // ─── Availability & settings ──────────────────────────────────

  Widget _buildSettings(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AVAILABILITY & SETTINGS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: isDark ? AppColors.goldMain : const Color(0xFFC8851A),
          ),
        ),
        const SizedBox(height: 12),
        _settingTile(context, isDark, Icons.circle, const Color(0xFF3DA35D), 'Available for bookings',
            _availableForBookings, (v) => setState(() => _availableForBookings = v)),
        const SizedBox(height: 10),
        _settingTile(context, isDark, Icons.notifications_none, const Color(0xFFDCA73A), 'Booking notifications',
            _bookingNotifications, (v) => setState(() => _bookingNotifications = v)),
        const SizedBox(height: 10),
        _settingTile(context, isDark, Icons.flash_on, const Color(0xFFDCA73A), 'Auto-accept booking requests',
            _autoAccept, (v) => setState(() => _autoAccept = v)),
      ],
    );
  }

  Widget _settingTile(BuildContext context, bool isDark, IconData icon, Color iconColor, String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: _accent(isDark),
          ),
        ],
      ),
    );
  }

  // ─── Action buttons ───────────────────────────────────────────

  Widget _buildActions(BuildContext context, bool isDark, Map<String, dynamic> p) {
    final accent = _accent(isDark);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GuideDetailScreen(guide: p)),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: BorderSide(color: accent),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View My Listing', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _onEdit,
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  // ─── Earnings ─────────────────────────────────────────────────

  Widget _buildEarnings(BuildContext context, bool isDark) {
    // No earnings endpoint yet — show zeroed card rather than fabricated
    // numbers. TODO: wire to a guide earnings summary when available.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : const Color(0xFFFDF3DC),
        borderRadius: BorderRadius.circular(12),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("This Month's Earnings",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9A6200))),
                const SizedBox(height: 4),
                Text('NPR 0',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFF9A6200))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('0 tours', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9A6200))),
              Text('— avg rating', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9A6200))),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shared bits ──────────────────────────────────────────────

  void _onEdit() {
    // Re-submitting the application form resets status to 'pending', which would
    // un-verify an approved guide — so we don't route back there. A dedicated
    // edit flow (PATCH /guides/me/) is TODO.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Listing editing is coming soon.')),
    );
  }

  Widget _stat(BuildContext context, bool isDark, String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFFC8851A))),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
      ],
    );
  }

  Widget _statDivider(bool isDark) {
    return Container(width: 1, height: 32, color: isDark ? AppColors.darkBorder : const Color(0xFFEADFCB));
  }

  Widget _badge(bool isDark, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: isDark ? AppColors.darkBgCard : bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : fg)),
    );
  }

  Widget _softChip(BuildContext context, bool isDark, String label, Color borderColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B5041))),
    );
  }

  Widget _outlineButton(BuildContext context, bool isDark, String label, VoidCallback onTap) {
    final accent = _accent(isDark);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accent)),
      ),
    );
  }
}
