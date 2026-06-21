import 'package:flutter/material.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';

class PolicySection {
  final String heading;
  final String body;
  const PolicySection(this.heading, this.body);
}

class PolicyScreen extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final List<PolicySection> sections;

  const PolicyScreen({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.brownDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Last updated: $lastUpdated',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ...sections.map((s) => _buildSection(s)),
        ],
      ),
    );
  }

  Widget _buildSection(PolicySection s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.heading,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7B2D1E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.body,
            style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4A3728)),
          ),
        ],
      ),
    );
  }
}

// ── Policy content factories ─────────────────────────────────────────────────

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => const PolicyScreen(
    title: 'Privacy Policy',
    lastUpdated: 'June 21, 2026',
    sections: [
      PolicySection('1. Introduction',
        'Sampada ("we", "our", or "us") is committed to protecting your personal information. '
        'This Privacy Policy explains how we collect, use, disclose, and safeguard your information '
        'when you use the Sampada mobile application for exploring Nepal\'s heritage sites.'),
      PolicySection('2. Information We Collect',
        'Account information: name, email address, and profile photo when you register or sign in with Google.\n\n'
        'Usage data: heritage sites you view, bookmark, or mark as visited.\n\n'
        'Booking data: guide booking requests, dates, and communication.\n\n'
        'Device data: device type, operating system, and crash reports for app improvement.\n\n'
        'Location data: only when you explicitly use the map feature; we do not track location in the background.'),
      PolicySection('3. How We Use Your Information',
        '• Provide and personalise the Sampada experience\n'
        '• Process guide bookings and send booking confirmations\n'
        '• Sync your bookmarks and visit history across devices\n'
        '• Send important service notifications (e.g. booking updates)\n'
        '• Improve app performance and fix bugs\n'
        '• Comply with legal obligations'),
      PolicySection('4. Third-Party Services',
        'We use the following third-party services, each governed by their own privacy policies:\n\n'
        '• Firebase (Google) — authentication and push notifications\n'
        '• Supabase — secure cloud database storage\n'
        '• Cloudinary — image storage and delivery\n'
        '• Google Sign-In — optional social login\n\n'
        'We do not sell your personal data to any third party.'),
      PolicySection('5. Data Retention',
        'We retain your data for as long as your account is active. '
        'When you delete your account, all personal data including bookmarks, visit history, '
        'and booking records are permanently removed from our servers within 30 days.'),
      PolicySection('6. Your Rights',
        'You have the right to:\n'
        '• Access the personal data we hold about you\n'
        '• Correct inaccurate data\n'
        '• Request deletion of your data (via Account Settings > Delete Account)\n'
        '• Withdraw consent at any time\n\n'
        'To exercise these rights, contact us at support@sampada.app'),
      PolicySection('7. Security',
        'All data is transmitted over HTTPS. Passwords are never stored — '
        'authentication is handled entirely by Firebase. We apply industry-standard '
        'security practices to protect your information.'),
      PolicySection('8. Children\'s Privacy',
        'Sampada is not directed at children under 13. We do not knowingly collect '
        'personal information from children under 13. If we become aware that a child '
        'under 13 has provided us with personal information, we will delete it immediately.'),
      PolicySection('9. Changes to This Policy',
        'We may update this Privacy Policy from time to time. We will notify you of '
        'significant changes through the app. Continued use of Sampada after changes '
        'constitutes acceptance of the updated policy.'),
      PolicySection('10. Contact Us',
        'For privacy-related questions or requests:\n'
        'Email: support@sampada.app\n'
        'Developer: Prabin Rokaya, Kathmandu, Nepal'),
    ],
  );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) => const PolicyScreen(
    title: 'Terms & Conditions',
    lastUpdated: 'June 21, 2026',
    sections: [
      PolicySection('1. Acceptance of Terms',
        'By downloading, installing, or using the Sampada application, you agree to be bound '
        'by these Terms and Conditions. If you do not agree, please do not use the app.'),
      PolicySection('2. Use of the App',
        'Sampada is a heritage tourism platform for exploring Nepal\'s cultural and historical sites. '
        'You agree to use the app only for lawful purposes and in accordance with these Terms. '
        'You must not use the app in any way that violates applicable local, national, or international law.'),
      PolicySection('3. User Accounts',
        '• You are responsible for maintaining the confidentiality of your account credentials.\n'
        '• You must provide accurate and complete information when creating an account.\n'
        '• You are responsible for all activity that occurs under your account.\n'
        '• You must notify us immediately of any unauthorised use of your account.'),
      PolicySection('4. Guide Bookings',
        'Sampada facilitates connections between tourists and local heritage guides. '
        'By making a booking you agree that:\n\n'
        '• Booking information provided must be accurate.\n'
        '• Cancellation policies set by individual guides apply.\n'
        '• Sampada is a platform intermediary and is not directly responsible for guide services.\n'
        '• Payment disputes must be resolved between the tourist and guide directly.'),
      PolicySection('5. User-Generated Content',
        'By submitting reviews, photos, or other content, you grant Sampada a non-exclusive, '
        'royalty-free licence to use, display, and distribute that content within the app. '
        'You retain ownership of your content. You must not submit content that is false, '
        'offensive, defamatory, or infringes any third-party rights.'),
      PolicySection('6. Prohibited Activities',
        '• Impersonating any person or entity\n'
        '• Posting false or misleading reviews\n'
        '• Attempting to gain unauthorised access to our systems\n'
        '• Using the app to transmit spam or malware\n'
        '• Scraping or harvesting data without permission\n'
        '• Damaging or defacing heritage sites promoted on the platform'),
      PolicySection('7. Intellectual Property',
        'All content within Sampada — including text, graphics, logos, icons, images, and software — '
        'is the property of Sampada or its content suppliers and is protected by copyright law. '
        'You may not reproduce, distribute, or create derivative works without express written permission.'),
      PolicySection('8. Disclaimer of Warranties',
        'Sampada is provided "as is" without warranties of any kind. We do not guarantee that '
        'the app will be error-free, uninterrupted, or that heritage site information is always '
        'current and accurate. We recommend verifying important information before visiting a site.'),
      PolicySection('9. Limitation of Liability',
        'To the maximum extent permitted by law, Sampada shall not be liable for any indirect, '
        'incidental, special, or consequential damages arising from your use of the app, '
        'including but not limited to loss of data, personal injury, or property damage '
        'at heritage sites.'),
      PolicySection('10. Termination',
        'We reserve the right to suspend or terminate your account at our discretion if you '
        'violate these Terms. You may delete your account at any time via Account Settings.'),
      PolicySection('11. Governing Law',
        'These Terms are governed by the laws of Nepal. Any disputes shall be subject to '
        'the exclusive jurisdiction of the courts of Kathmandu, Nepal.'),
      PolicySection('12. Contact',
        'Questions about these Terms:\nEmail: support@sampada.app'),
    ],
  );
}

class CommunityPolicyScreen extends StatelessWidget {
  const CommunityPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => const PolicyScreen(
    title: 'Community Guidelines',
    lastUpdated: 'June 21, 2026',
    sections: [
      PolicySection('Our Mission',
        'Sampada is built to celebrate and protect Nepal\'s extraordinary cultural heritage. '
        'Our community guidelines exist to keep this space respectful, authentic, and '
        'welcoming for travellers, locals, guides, and heritage enthusiasts alike.'),
      PolicySection('1. Respect Heritage Sites',
        '• Never encourage or document vandalism, graffiti, or damage to heritage structures.\n'
        '• Do not post content that promotes removing or trading cultural artefacts.\n'
        '• Respect local customs, dress codes, and sacred spaces when visiting sites.\n'
        '• Follow all site rules and government preservation guidelines.'),
      PolicySection('2. Honest and Authentic Content',
        '• Write reviews based on your genuine personal experience.\n'
        '• Do not post fake reviews, paid reviews, or reviews about sites you have not visited.\n'
        '• Do not manipulate ratings for personal or commercial gain.\n'
        '• Photos must represent the actual site — do not use heavily edited or misleading images.'),
      PolicySection('3. Respectful Communication',
        '• Treat all community members — tourists, guides, and locals — with respect.\n'
        '• No harassment, bullying, hate speech, or discrimination based on race, '
        'ethnicity, religion, gender, nationality, or disability.\n'
        '• Constructive criticism is welcome; personal attacks are not.'),
      PolicySection('4. No Spam or Commercial Abuse',
        '• Do not post unsolicited commercial content or advertisements.\n'
        '• Guides must not solicit bookings outside the official Sampada booking system.\n'
        '• Do not create multiple accounts to manipulate rankings or reviews.'),
      PolicySection('5. Privacy of Others',
        '• Do not share personal information about other users without their consent.\n'
        '• Photographs of people at heritage sites should be respectful and not taken covertly.\n'
        '• Do not share private messages or personal conversations publicly.'),
      PolicySection('6. Legal Content Only',
        '• Do not post content that violates Nepal\'s laws or international law.\n'
        '• No copyright-infringing content — only share photos and text you own or have rights to.\n'
        '• Do not promote illegal activities, including trespassing at restricted heritage sites.'),
      PolicySection('7. Guide Conduct',
        'Guides registered on Sampada must:\n'
        '• Hold valid licences where required by law.\n'
        '• Provide services as described in their profile.\n'
        '• Treat all tourists with professionalism and respect.\n'
        '• Not engage in price-fixing or colluding with other guides.\n'
        '• Report safety concerns at heritage sites to relevant authorities.'),
      PolicySection('8. Reporting Violations',
        'If you encounter content or behaviour that violates these guidelines, '
        'please report it through the app. We review all reports and take appropriate action, '
        'which may include content removal, warnings, or account suspension.'),
      PolicySection('9. Enforcement',
        'Violations of these guidelines may result in:\n'
        '• Content removal\n'
        '• Temporary suspension\n'
        '• Permanent account termination\n\n'
        'Decisions are made at Sampada\'s discretion. Repeated or severe violations '
        'will result in permanent bans.'),
      PolicySection('10. Contact',
        'To report a community concern:\nEmail: community@sampada.app'),
    ],
  );
}

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});
  @override
  Widget build(BuildContext context) => const PolicyScreen(
    title: 'Disclaimer',
    lastUpdated: 'June 21, 2026',
    sections: [
      PolicySection('General Information',
        'The information provided in the Sampada application is for general informational '
        'and tourism purposes only. All information is provided in good faith; however, '
        'we make no representation or warranty of any kind, express or implied, regarding '
        'the accuracy, adequacy, validity, reliability, availability, or completeness of '
        'any information on the platform.'),
      PolicySection('Heritage Site Information',
        'Details about heritage sites — including opening hours, entry fees, accessibility, '
        'and historical descriptions — are sourced from publicly available records and '
        'partner data providers. This information may change without notice. '
        'Sampada is not responsible for outdated or inaccurate site information. '
        'We strongly recommend confirming details directly with site authorities before visiting.'),
      PolicySection('Guide Services',
        'Sampada acts solely as a platform connecting tourists with independent heritage guides. '
        'We do not employ the guides listed on our platform. We do not guarantee the quality, '
        'safety, or suitability of any guide\'s services. Users engage with guides entirely at '
        'their own risk. Sampada is not liable for any loss, injury, or dispute arising from '
        'guide bookings made through the platform.'),
      PolicySection('Navigation and Maps',
        'Map data and navigation features are provided for general orientation only. '
        'Do not rely solely on Sampada for navigation in remote or restricted areas. '
        'Always carry physical maps and follow official signage at heritage sites.'),
      PolicySection('External Links',
        'The app may contain links to external websites or third-party services. '
        'These links are provided for convenience only. Sampada has no control over '
        'the content of external sites and accepts no responsibility for them or for '
        'any loss or damage that may arise from your use of them.'),
      PolicySection('No Professional Advice',
        'Nothing on Sampada constitutes professional travel, legal, medical, or safety advice. '
        'Heritage sites may involve physical risks including uneven terrain, stairs, and '
        'altitude. Consult appropriate professionals and assess your own physical fitness '
        'before visiting.'),
      PolicySection('Limitation of Liability',
        'Under no circumstances shall Sampada, its developers, or affiliates be liable '
        'for any direct, indirect, incidental, consequential, or punitive damages '
        'arising out of your use of, or inability to use, the application or its content.'),
      PolicySection('Changes',
        'We reserve the right to update this Disclaimer at any time. '
        'Continued use of the app following changes constitutes acceptance of the revised Disclaimer.'),
      PolicySection('Contact',
        'For concerns regarding this Disclaimer:\nEmail: support@sampada.app'),
    ],
  );
}

class CopyrightPolicyScreen extends StatelessWidget {
  const CopyrightPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => const PolicyScreen(
    title: 'Copyright Policy',
    lastUpdated: 'June 21, 2026',
    sections: [
      PolicySection('1. Ownership of Content',
        '© 2026 Sampada. All rights reserved.\n\n'
        'All original content within the Sampada application — including but not limited to '
        'text descriptions, app design, graphics, icons, logos, and software code — is the '
        'exclusive intellectual property of Sampada and is protected under the copyright laws '
        'of Nepal and applicable international copyright treaties.'),
      PolicySection('2. Heritage Site Images',
        'Photographs of heritage sites displayed in Sampada are either:\n\n'
        '• Owned by Sampada and its contributors\n'
        '• Licensed from photographers and content partners\n'
        '• Sourced from publicly available government and UNESCO archives under appropriate licences\n\n'
        'Unauthorised reproduction, distribution, or commercial use of these images is prohibited.'),
      PolicySection('3. User-Generated Content',
        'By submitting photos, reviews, or other content to Sampada, you represent that:\n\n'
        '• You are the original creator of the content, OR\n'
        '• You have obtained all necessary rights and permissions to submit it.\n\n'
        'You grant Sampada a worldwide, non-exclusive, royalty-free licence to use, reproduce, '
        'display, and distribute your submitted content within the app and its promotional materials. '
        'You retain full ownership of your content and may request its removal at any time.'),
      PolicySection('4. Prohibited Uses',
        'Without express written permission from Sampada, you may not:\n\n'
        '• Copy, reproduce, or republish any app content for commercial purposes\n'
        '• Modify, adapt, or create derivative works based on Sampada\'s content\n'
        '• Scrape or systematically download content from the platform\n'
        '• Remove or alter any copyright notices or watermarks\n'
        '• Use Sampada\'s name, logo, or branding without authorisation'),
      PolicySection('5. Fair Use',
        'Limited non-commercial use of Sampada content may be permitted under fair use provisions '
        'for purposes of commentary, criticism, education, or research, provided that appropriate '
        'credit is given to Sampada as the source.'),
      PolicySection('6. Copyright Infringement Notices (DMCA)',
        'If you believe that content on Sampada infringes your copyright, please send a written '
        'notice to our designated agent including:\n\n'
        '• A description of the copyrighted work claimed to be infringed\n'
        '• The URL or location of the allegedly infringing content\n'
        '• Your contact information\n'
        '• A statement that you have a good-faith belief that the use is not authorised\n'
        '• Your signature (electronic or physical)\n\n'
        'Send to: copyright@sampada.app\n\n'
        'We will respond to valid notices within 14 business days and remove infringing content promptly.'),
      PolicySection('7. Counter-Notices',
        'If you believe content was removed in error, you may submit a counter-notice to '
        'copyright@sampada.app. We will review counter-notices and restore content where appropriate '
        'in accordance with applicable law.'),
      PolicySection('8. Third-Party Content',
        'Sampada respects the intellectual property rights of others. Third-party trademarks, '
        'logos, and content displayed in the app remain the property of their respective owners.'),
      PolicySection('9. Contact',
        'Copyright enquiries:\nEmail: copyright@sampada.app\nDeveloper: Prabin Rokaya, Kathmandu, Nepal'),
    ],
  );
}

// Route name → widget mapping for use in app.dart
final Map<String, Widget Function(BuildContext)> policyRoutes = {
  AppStrings.privacyPolicyPath: (_) => const PrivacyPolicyScreen(),
  AppStrings.termsPath: (_) => const TermsScreen(),
  AppStrings.communityPolicyPath: (_) => const CommunityPolicyScreen(),
  AppStrings.disclaimerPath: (_) => const DisclaimerScreen(),
  AppStrings.copyrightPolicyPath: (_) => const CopyrightPolicyScreen(),
};
