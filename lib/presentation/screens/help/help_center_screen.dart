import 'package:flutter/material.dart';
import 'package:sampada/presentation/screens/help/help_content.dart';
import 'package:sampada/presentation/screens/help/help_screens.dart';
import 'package:sampada/presentation/screens/help/help_widgets.dart';

/// The Sampada Help & Support centre — the dedicated screen opened from the
/// support icon in Settings. Faithful to the approved prototype, rendered on the
/// app theme so it looks right in light and dark.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});
  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  String _query = '';

  bool _matches(String label) =>
      _query.trim().isEmpty || label.toLowerCase().contains(_query.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);

    // Popular topics.
    final topics = <_Topic>[
      _Topic('Account', Icons.person_outline,
          () => pushHelp(context, const HelpInfoScreen(
              title: 'Account', subtitle: 'Manage your profile',
              eyebrow: 'Profile & settings', points: [
                HelpTopicInfo('Profile & verification', 'Update your name, photo and phone number, and verify your email to unlock reviews, RSVPs and guide bookings.'),
                HelpTopicInfo('Language & theme', 'Switch between English and Nepali and choose a light or dark theme from Profile > Settings.'),
                HelpTopicInfo('Delete account', 'Permanently remove your account and data from Profile > Account Settings. This can\'t be undone.'),
              ]))),
      _Topic('Booking Guide', Icons.description_outlined,
          () => pushHelp(context, HelpInfoScreen(
              title: 'Booking Guide', subtitle: 'How guide bookings work',
              eyebrow: 'From request to review', points: helpTopicInfo['booking']!))),
      _Topic('Events', Icons.event_outlined,
          () => pushHelp(context, HelpInfoScreen(
              title: 'Events', subtitle: 'Festivals & happenings',
              eyebrow: 'Cultural events', points: helpTopicInfo['events']!))),
      _Topic('Heritage Sites', Icons.account_balance_outlined,
          () => pushHelp(context, HelpInfoScreen(
              title: 'Heritage Sites', subtitle: 'Explore & discover',
              eyebrow: 'Discovering heritage', points: helpTopicInfo['heritage']!))),
      _Topic('Offline Mode', Icons.wifi_off,
          () => pushHelp(context, const HelpArticleScreen(articleKey: 'offline'))),
      _Topic('Notifications', Icons.notifications_none,
          () => pushHelp(context, const HelpArticleScreen(articleKey: 'notif'))),
      _Topic('Payments', Icons.credit_card,
          () => pushHelp(context, HelpInfoScreen(
              title: 'Payments', subtitle: 'Paying your guide',
              eyebrow: 'Direct guide payment', points: helpTopicInfo['payments']!))),
    ];

    // Get support.
    final support = <_Entry>[
      _Entry('Contact Support', 'Submit a new request', Icons.chat_bubble_outline,
          () => pushHelp(context, const HelpContactSupportScreen())),
      _Entry('My Support Requests', 'Track your requests', Icons.receipt_long_outlined,
          () => pushHelp(context, const HelpMyRequestsScreen())),
      _Entry('Live Chat', 'Usually replies in minutes', Icons.forum_outlined,
          () => pushHelp(context, const HelpLiveChatScreen())),
      _Entry('Report a Problem', 'Guide, user, event, site or bug', Icons.flag_outlined,
          () => pushHelp(context, const HelpReportScreen())),
    ];

    // Browse.
    final browse = <_Entry>[
      _Entry('FAQs', 'Booking, cancellations, language', Icons.help_outline,
          () => pushHelp(context, const HelpFaqsScreen())),
      _Entry('Troubleshooting', 'GPS, login, offline maps', Icons.build_outlined,
          () => pushHelp(context, const HelpTroubleshootingScreen())),
      _Entry('Safety Center', 'Travel with confidence', Icons.shield_outlined,
          () => pushHelp(context, const HelpInfoScreen(
              title: 'Safety Center', subtitle: 'Travel with confidence',
              eyebrow: 'Your safety first', points: helpSafetyPoints))),
      _Entry('Emergency Contacts', 'Police, ambulance, fire', Icons.emergency_outlined,
          () => pushHelp(context, const HelpEmergencyScreen())),
      _Entry('Feedback', 'Rate the app', Icons.star_outline,
          () => pushHelp(context, const HelpFeedbackScreen())),
      _Entry('Contact Information', 'Email, phone, office hours', Icons.mail_outline,
          () => pushHelp(context, const HelpContactInfoScreen())),
      _Entry('About the App', 'Version, legal & licences', Icons.info_outline,
          () => openAbout(context)),
    ];

    final filteredTopics = topics.where((t) => _matches(t.label)).toList();
    final filteredSupport = support.where((e) => _matches(e.title)).toList();
    final filteredBrowse = browse.where((e) => _matches(e.title)).toList();
    final nothing = filteredTopics.isEmpty && filteredSupport.isEmpty && filteredBrowse.isEmpty;

    return HelpScaffold(
      title: 'Help Center',
      subtitle: 'We\'re here when you need us',
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          HelpSearchField(hint: 'Search for help...', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 4),

          if (nothing)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(children: [
                Icon(Icons.search_off, size: 44, color: p.faint),
                const SizedBox(height: 12),
                Text('No help topics match "$_query"',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.muted)),
                const SizedBox(height: 6),
                Text('Try "booking", "offline" or "login".',
                    style: TextStyle(fontSize: 12, color: p.faint)),
              ]),
            ),

          if (filteredTopics.isNotEmpty) ...[
            const HelpSectionTitle('Popular topics'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              // >1 → wider than tall. 0.92 made the cells taller than they were
              // wide, which is what left them looking oversized.
              childAspectRatio: 1.15,
              children: [
                for (final t in filteredTopics)
                  HelpTopicTile(icon: t.icon, label: t.label, onTap: t.onTap),
              ],
            ),
          ],

          if (filteredSupport.isNotEmpty) ...[
            const HelpSectionTitle('Get support'),
            HelpMenuList(children: [
              for (final e in filteredSupport)
                HelpMenuItem(icon: e.icon, title: e.title, subtitle: e.subtitle, onTap: e.onTap),
            ]),
          ],

          if (filteredBrowse.isNotEmpty) ...[
            const HelpSectionTitle('Browse'),
            HelpMenuList(children: [
              for (final e in filteredBrowse)
                HelpMenuItem(icon: e.icon, title: e.title, subtitle: e.subtitle, onTap: e.onTap),
            ]),
          ],

          const SizedBox(height: 20),
          Center(child: Text('सम्पदा help center — every answer, one tap away',
              style: TextStyle(fontSize: 11, color: p.faint))),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _Topic {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _Topic(this.label, this.icon, this.onTap);
}

class _Entry {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _Entry(this.title, this.subtitle, this.icon, this.onTap);
}
