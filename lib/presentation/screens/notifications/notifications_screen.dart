import 'package:flutter/material.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // --- Header Section ---
          Stack(
            children: [
              Container(
                height: size.height * 0.15,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF5D1700),
                      Color(0xFF9E3D1A),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                            hoverColor: Colors.white.withValues(alpha: 0.1),
                            splashColor: Colors.white.withValues(alpha: 0.2),
                          ),
                          Text(
                            l10n.notifTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Mark all read',
                              style: TextStyle(color: Color(0xFFC89932), fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Filters
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFilterChip(l10n.notifFilterAll),
                          _buildFilterChip(l10n.notifFilterEvents),
                          _buildFilterChip('Heritage'),
                          _buildFilterChip('Alerts'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- Notifications List ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                _NotificationCard(
                  title: 'Indra Jatra starts in 3 days!',
                  subtitle: 'Event reminder • Sep 18',
                  icon: Icons.masks,
                  accentColor: Colors.red,
                  isUnread: true,
                ),
                _NotificationCard(
                  title: 'New site added: Changu Narayan',
                  subtitle: 'Heritage update • Bhaktapur',
                  icon: Icons.temple_hindu,
                  accentColor: Colors.orange,
                  isUnread: true,
                ),
                _NotificationCard(
                  title: 'Tihar Festival this weekend',
                  subtitle: 'Event reminder • Oct 28',
                  icon: Icons.light,
                  accentColor: Colors.orangeAccent,
                ),
                _NotificationCard(
                  title: 'Bhaktapur guide downloaded',
                  subtitle: 'Available offline now',
                  icon: Icons.download_for_offline,
                  accentColor: Colors.teal,
                ),
                _NotificationCard(
                  title: 'Boudhanath info updated',
                  subtitle: 'Heritage update • Kathmandu',
                  icon: Icons.temple_buddhist,
                  accentColor: Colors.amber,
                ),
                _NotificationCard(
                  title: 'Patan Durbar bookmarked',
                  subtitle: 'Your activity',
                  icon: Icons.bookmark,
                  accentColor: Colors.deepPurpleAccent,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC89932) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isUnread;

  const _NotificationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.isUnread = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left Accent Border
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5EFEC) : AppColors.darkBgCard,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF4A342B) : AppColors.goldMain, size: 28),
                    ),
                    const SizedBox(width: 16),
                    // Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Unread Dot
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFC89932),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}







