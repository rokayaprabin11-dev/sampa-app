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

// ── Shared contact info ──────────────────────────────────────────────────────
const _developer = 'Prabin Rokaya';
const _location  = 'Kailali, Nepal';
const _email     = 'rokayaprabin11@gmail.com';
const _contact   = 'Developer: $_developer\nLocation: $_location\nEmail: $_email';

// ── Policy screens ───────────────────────────────────────────────────────────

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) => const PolicyScreen(
    title: 'Privacy Policy',
    lastUpdated: 'June 21, 2026',
    sections: [
      PolicySection('1. Introduction',
        'Sampada ("we", "our", or "us") is a heritage tourism application developed by '
        '$_developer, Kailali, Nepal. This Privacy Policy explains how we collect, use, '
        'disclose, and safeguard your information when you use the Sampada mobile application '
        'for exploring Nepal\'s cultural and historical heritage sites.'),
      PolicySection('2. Information We Collect',
        'Account information: your name, email address, and profile photo when you register '
        'or sign in with Google.\n\n'
        'Usage data: heritage sites you view, bookmark, or mark as visited.\n\n'
        'Booking data: guide booking requests, scheduled dates, and related communication.\n\n'
        'Payment data: when payments are processed through the app, transaction records are '
        'stored. Direct payments between tourists and guides are not handled or stored by us.\n\n'
        'Device data: device type, operating system version, and crash reports used solely '
        'for app improvement.\n\n'
        'Location data: only when you explicitly open the map feature. We do not track '
        'your location in the background.'),
      PolicySection('3. How We Use Your Information',
        '• Provide and personalise your Sampada experience\n'
        '• Process guide bookings and send booking confirmations\n'
        '• Sync your bookmarks and visit history across devices\n'
        '• Deliver push notifications for booking updates and important alerts\n'
        '• Process payments where applicable within the app\n'
        '• Improve app performance, stability, and features\n'
        '• Comply with applicable laws of Nepal'),
      PolicySection('4. Third-Party Services',
        'We use the following third-party services. Each is governed by its own privacy policy:\n\n'
        '• Firebase (Google) — user authentication and push notifications\n'
        '• Google Sign-In — optional social login\n'
        '• Supabase (PostgreSQL) — secure cloud database for all user and heritage data\n'
        '• Cloudinary — image storage and optimised delivery\n'
        '• Upstash Redis — background task queuing and caching\n'
        '• Celery — background job processing (booking confirmations, notifications)\n'
        '• Render — cloud hosting of the backend API\n\n'
        'We do not sell your personal data to any third party under any circumstances.'),
      PolicySection('5. Data Retention',
        'Your data is retained for as long as your account remains active. '
        'When you delete your account, all personal data — including bookmarks, visit history, '
        'booking records, and profile information — is permanently and irreversibly deleted '
        'from our servers within 30 days of your request.'),
      PolicySection('6. Your Rights',
        'You have the right to:\n'
        '• Access the personal data we hold about you\n'
        '• Correct inaccurate or incomplete data\n'
        '• Request permanent deletion of your data (via Settings > Account > Delete Account)\n'
        '• Withdraw consent to data processing at any time\n'
        '• Lodge a complaint with Nepal\'s relevant data protection authority\n\n'
        'To exercise any of these rights, contact us at:\n$_email'),
      PolicySection('7. Security',
        'All data is transmitted exclusively over HTTPS. Passwords are never stored by '
        'Sampada — authentication is handled entirely by Firebase. We apply industry-standard '
        'security measures including encrypted storage, access controls, and regular security '
        'reviews to protect your information.'),
      PolicySection('8. Children\'s Privacy',
        'Sampada is intended for users aged 12 and above. We do not knowingly collect '
        'personal information from children under 12. If we become aware that a child '
        'under 12 has provided us with personal information, we will delete it immediately. '
        'Parents or guardians who believe their child has submitted data should contact us at $_email.'),
      PolicySection('9. Changes to This Policy',
        'We may update this Privacy Policy from time to time to reflect changes in our '
        'practices or applicable law. We will notify you of significant changes through '
        'an in-app notice. Continued use of Sampada after the effective date of changes '
        'constitutes your acceptance of the updated policy.'),
      PolicySection('10. Contact Us',
        'For any privacy-related questions, requests, or concerns:\n$_contact'),
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
        'by these Terms and Conditions. These Terms form a legally binding agreement between '
        'you and $_developer ("we", "us", or "our"), the developer of Sampada, based in '
        '$_location. If you do not agree with any part of these Terms, do not use the app.'),
      PolicySection('2. Eligibility',
        'You must be at least 12 years of age to use Sampada. By using the app, you confirm '
        'that you meet this age requirement. Users under 18 should have parental or guardian '
        'consent before using the guide booking features.'),
      PolicySection('3. Use of the App',
        'Sampada is a heritage tourism platform for exploring Nepal\'s cultural and historical '
        'sites and connecting tourists with licensed local heritage guides. You agree to use '
        'the app only for lawful purposes and in accordance with these Terms and all applicable '
        'laws of Nepal.'),
      PolicySection('4. User Accounts',
        '• You are responsible for maintaining the confidentiality of your account credentials.\n'
        '• You must provide accurate, current, and complete information when creating an account.\n'
        '• You are solely responsible for all activity that occurs under your account.\n'
        '• You must notify us immediately at $_email of any unauthorised use of your account.'),
      PolicySection('5. Guide Bookings & Payments',
        'Sampada facilitates connections between tourists and independent heritage guides. '
        'Payments for guide services may be made either:\n\n'
        '• Through the Sampada in-app payment system, or\n'
        '• Directly between the tourist and the guide in person.\n\n'
        'By making a booking you agree that:\n'
        '• All booking information provided must be accurate and truthful.\n'
        '• Cancellation policies set by individual guides apply and must be respected.\n'
        '• Sampada acts as a platform intermediary only and is not a party to the service contract '
        'between you and the guide.\n'
        '• For in-app payments, refund requests must be submitted within 48 hours of the scheduled tour date.\n'
        '• For direct payments, Sampada accepts no responsibility for payment disputes.'),
      PolicySection('6. User-Generated Content',
        'By submitting reviews, ratings, photos, or other content, you grant Sampada a '
        'non-exclusive, royalty-free, worldwide licence to use, display, and distribute '
        'that content within the app and its promotional materials. You retain full ownership '
        'of your content. You must not submit content that is false, offensive, defamatory, '
        'or that infringes any third-party intellectual property rights.'),
      PolicySection('7. Prohibited Activities',
        '• Impersonating any person, guide, or official entity\n'
        '• Posting false, misleading, or incentivised reviews\n'
        '• Attempting to gain unauthorised access to our systems or data\n'
        '• Using the app to transmit spam, malware, or harmful code\n'
        '• Scraping or harvesting content or data without written permission\n'
        '• Vandalising, defacing, or damaging heritage sites promoted on the platform\n'
        '• Booking guides with no intention of completing the tour'),
      PolicySection('8. Intellectual Property',
        'All content within Sampada — including text, graphics, logos, icons, images, and '
        'software — is the property of $_developer or its licensed content suppliers and is '
        'protected under copyright law. You may not reproduce, distribute, or create derivative '
        'works without express written permission from us.'),
      PolicySection('9. Disclaimer of Warranties',
        'Sampada is provided "as is" and "as available" without warranties of any kind, '
        'express or implied. We do not guarantee that the app will be error-free, '
        'uninterrupted, or that heritage site information (opening hours, entry fees, '
        'accessibility) is always current. Verify important details directly with site '
        'authorities before visiting.'),
      PolicySection('10. Limitation of Liability',
        'To the maximum extent permitted by the laws of Nepal, $_developer shall not be '
        'liable for any indirect, incidental, special, or consequential damages arising '
        'from your use of or inability to use the app, including but not limited to personal '
        'injury, property damage, or financial loss at heritage sites or in connection with '
        'guide bookings.'),
      PolicySection('11. Termination',
        'We reserve the right to suspend or permanently terminate your account without notice '
        'if you violate these Terms or engage in conduct harmful to the Sampada community. '
        'You may delete your own account at any time via Settings > Account Settings > Delete Account.'),
      PolicySection('12. Governing Law',
        'These Terms and Conditions are governed by and construed in accordance with the laws '
        'of Nepal. Any disputes arising under these Terms shall be subject to the exclusive '
        'jurisdiction of the competent courts of Nepal.'),
      PolicySection('13. Contact',
        'Questions or concerns about these Terms:\n$_contact'),
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
        'Sampada is built to celebrate, promote, and protect Nepal\'s extraordinary cultural '
        'heritage. These Community Guidelines exist to keep this space respectful, authentic, '
        'and welcoming for travellers, local communities, guides, and heritage enthusiasts of '
        'all backgrounds. By using Sampada, you agree to uphold these standards.'),
      PolicySection('1. Respect Heritage Sites',
        '• Never encourage, document, or glorify vandalism, graffiti, or any damage to '
        'heritage structures, monuments, or sacred spaces.\n'
        '• Do not post content that promotes the removal, sale, or illegal trade of '
        'cultural artefacts.\n'
        '• Respect local customs, dress codes, and religious sensitivities at each site.\n'
        '• Follow all posted site rules, government preservation regulations, and UNESCO guidelines.'),
      PolicySection('2. Honest and Authentic Content',
        '• Write reviews and ratings based solely on your own genuine personal experience.\n'
        '• Do not post fake, incentivised, or fabricated reviews about sites or guides.\n'
        '• Do not review a site or guide you have not actually visited or used.\n'
        '• Do not manipulate ratings for personal, competitive, or commercial gain.\n'
        '• Photos must accurately represent the actual site — heavily edited or AI-generated '
        'images presented as real are not permitted.'),
      PolicySection('3. Respectful Communication',
        '• Treat all community members — tourists, local residents, and guides — with dignity '
        'and respect.\n'
        '• Hate speech, harassment, bullying, or discrimination based on race, ethnicity, '
        'religion, caste, gender, sexual orientation, nationality, age, or disability is '
        'strictly prohibited.\n'
        '• Constructive and honest feedback about sites and guides is welcome; personal attacks '
        'against individuals are not.'),
      PolicySection('4. No Spam or Commercial Abuse',
        '• Do not post unsolicited advertisements, promotional content, or affiliate links.\n'
        '• Registered guides must not solicit bookings outside the official Sampada booking system.\n'
        '• Do not create multiple accounts to game rankings, inflate ratings, or circumvent bans.'),
      PolicySection('5. Privacy of Others',
        '• Do not share another user\'s personal information — name, contact details, or location — '
        'without their explicit consent.\n'
        '• Photographs or videos featuring other visitors at heritage sites must be taken '
        'respectfully and not in secret.\n'
        '• Do not publicly share private messages or conversations from other users.'),
      PolicySection('6. Legal Content Only',
        '• Do not post content that violates any law of Nepal or applicable international law.\n'
        '• Only share photographs, text, and media that you own or have explicit rights to share.\n'
        '• Do not promote or encourage trespassing, access to restricted heritage areas, or '
        'any other illegal activity.'),
      PolicySection('7. Guide Conduct Standards',
        'Heritage guides registered on Sampada must:\n'
        '• Hold all licences and permits required by Nepalese law for guide services.\n'
        '• Accurately represent their qualifications, experience, and services in their profile.\n'
        '• Treat all tourists with professionalism, fairness, and respect regardless of origin.\n'
        '• Not engage in price-fixing, collusion, or coercive sales tactics.\n'
        '• Promptly report any safety hazards or incidents at heritage sites to relevant authorities.'),
      PolicySection('8. Reporting Violations',
        'If you encounter content, a review, or behaviour that violates these guidelines, '
        'please report it directly through the app or contact us at $_email. '
        'We review all reports and take appropriate action, which may include content removal, '
        'warnings, temporary suspension, or permanent banning.'),
      PolicySection('9. Enforcement',
        'Violations of these Community Guidelines may result in:\n'
        '• Removal of the offending content\n'
        '• A formal warning issued to the account\n'
        '• Temporary suspension of account privileges\n'
        '• Permanent account termination\n\n'
        'All enforcement decisions are made at Sampada\'s sole discretion. Serious or repeated '
        'violations will result in immediate and permanent removal from the platform.'),
      PolicySection('10. Contact',
        'To report a community violation or ask questions about these guidelines:\n$_contact'),
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
      PolicySection('General',
        'The Sampada application is developed and maintained by $_developer, $_location. '
        'The information provided within the app is for general informational and tourism '
        'purposes only. While we strive to keep information accurate and up to date, we make '
        'no representation or warranty of any kind — express or implied — regarding the '
        'accuracy, completeness, reliability, or availability of any content on the platform.'),
      PolicySection('Heritage Site Information',
        'Descriptions, photographs, opening hours, entry fees, accessibility details, and '
        'historical information about heritage sites are sourced from publicly available '
        'records, government publications, and partner data providers. This information may '
        'change without notice. Sampada is not responsible for outdated, incomplete, or '
        'inaccurate site information. We strongly recommend confirming all details directly '
        'with the site authority or relevant government office before your visit.'),
      PolicySection('Guide Services',
        'Sampada acts solely as a technology platform connecting tourists with independent '
        'local heritage guides. We do not employ, train, or directly supervise any guide '
        'listed on the platform. We do not guarantee the quality, accuracy, safety, legality, '
        'or suitability of any guide\'s services.\n\n'
        'Users engage guides entirely at their own risk. Sampada is not liable for any '
        'personal injury, financial loss, property damage, or dispute arising from guide '
        'bookings made through or outside the platform, whether payment was made in-app '
        'or directly.'),
      PolicySection('Payment Information',
        'Where in-app payments are facilitated, Sampada relies on third-party payment '
        'processors. We do not store full payment card details. Transaction accuracy depends '
        'on third-party systems and Sampada accepts no liability for payment errors, '
        'processing failures, or fraudulent transactions beyond our reasonable control. '
        'For direct cash or transfer payments between tourists and guides, Sampada bears '
        'no responsibility whatsoever.'),
      PolicySection('Navigation and Maps',
        'Map data and navigation features are provided for general orientation and discovery '
        'purposes only. Do not rely solely on Sampada for navigation, especially in remote, '
        'mountainous, or restricted heritage areas. Always carry physical maps, follow '
        'official signage, and heed advice from local authorities.'),
      PolicySection('No Professional Advice',
        'Nothing within Sampada constitutes professional travel, legal, medical, financial, '
        'or safety advice. Heritage sites in Nepal may involve physical risks including '
        'uneven terrain, steep staircases, altitude, and crowd conditions. Users should '
        'assess their own physical fitness and consult appropriate professionals before '
        'visiting high-altitude or physically demanding sites.'),
      PolicySection('External Links',
        'The app may contain links or references to external websites or third-party services. '
        'These are provided for convenience only. Sampada has no control over the content, '
        'accuracy, or availability of external sites and accepts no responsibility for any '
        'loss or damage arising from their use.'),
      PolicySection('Limitation of Liability',
        'Under no circumstances shall $_developer, Sampada, or its contributors be liable '
        'for any direct, indirect, incidental, consequential, or punitive damages of any '
        'nature arising out of your use of, or inability to use, the Sampada application '
        'or any content or services accessed through it.'),
      PolicySection('Changes to This Disclaimer',
        'We reserve the right to update this Disclaimer at any time without prior notice. '
        'Continued use of the app after any changes constitutes your acceptance of the '
        'revised Disclaimer.'),
      PolicySection('Contact',
        'For questions or concerns regarding this Disclaimer:\n$_contact'),
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
      PolicySection('1. Ownership',
        '© 2026 Sampada — $_developer. All rights reserved.\n\n'
        'All original content within the Sampada application — including but not limited to '
        'text, heritage site descriptions, UI design, graphics, icons, the Sampada logo, '
        'and software source code — is the exclusive intellectual property of $_developer '
        'and is protected under the Copyright Act of Nepal and applicable international '
        'copyright treaties.'),
      PolicySection('2. Heritage Site Images',
        'Photographs and visual media of heritage sites displayed in Sampada are either:\n\n'
        '• Created by or for Sampada and its content contributors\n'
        '• Licensed from individual photographers and content partners\n'
        '• Sourced from publicly available government, Department of Archaeology (Nepal), '
        'or UNESCO archives under appropriate permissions\n\n'
        'Unauthorised reproduction, redistribution, or commercial use of any image from '
        'Sampada is strictly prohibited without written permission.'),
      PolicySection('3. User-Generated Content',
        'By submitting photographs, reviews, ratings, or any other content to Sampada, '
        'you confirm that:\n\n'
        '• You are the original creator of the submitted content, OR\n'
        '• You hold all necessary rights and permissions to submit and license it.\n\n'
        'You grant Sampada a worldwide, non-exclusive, royalty-free licence to use, reproduce, '
        'display, and distribute your submitted content within the app and related promotional '
        'materials. You retain full copyright ownership of your content and may request its '
        'removal at any time by contacting us at $_email.'),
      PolicySection('4. Prohibited Uses',
        'Without express written permission from $_developer, you may not:\n\n'
        '• Copy, reproduce, republish, or redistribute any Sampada content for commercial purposes\n'
        '• Modify, adapt, translate, or create derivative works based on Sampada\'s original content\n'
        '• Systematically scrape, crawl, or download content or data from the platform\n'
        '• Remove, obscure, or alter any copyright notices, watermarks, or attributions\n'
        '• Use the Sampada name, logo, or branding in any form without prior written authorisation'),
      PolicySection('5. Fair Use',
        'Limited non-commercial use of Sampada content may be permissible for purposes of '
        'commentary, criticism, education, journalism, or research, provided that:\n\n'
        '• Sampada is clearly credited as the original source\n'
        '• The use does not misrepresent or damage the Sampada brand\n'
        '• The amount used is reasonable and proportionate to the purpose'),
      PolicySection('6. Reporting Copyright Infringement',
        'If you believe that content published on Sampada infringes your copyright, '
        'please send a written notice to us at $_email including:\n\n'
        '• A description of the copyrighted work you believe has been infringed\n'
        '• The specific location (screen/section) of the allegedly infringing content within the app\n'
        '• Your full name and contact information\n'
        '• A statement that you have a good-faith belief the use is not authorised by the '
        'copyright owner, its agent, or the law\n'
        '• A statement that the information in your notice is accurate and, under penalty of '
        'perjury, that you are the copyright owner or authorised to act on their behalf\n\n'
        'We will acknowledge valid notices within 7 business days and take appropriate action, '
        'including removal of infringing content where confirmed.'),
      PolicySection('7. Counter-Notices',
        'If you believe your content was removed in error, you may submit a counter-notice '
        'to $_email. Please include your name, a description of the removed content, '
        'a statement under penalty of perjury that you have a good-faith belief the content '
        'was removed by mistake, and your consent to the jurisdiction of competent courts '
        'in Nepal. We will review counter-notices and restore content where appropriate.'),
      PolicySection('8. Third-Party Intellectual Property',
        'Sampada respects the intellectual property rights of all parties. Third-party '
        'trademarks, logos, and copyrighted content referenced or displayed in the app '
        '(e.g. Google, Firebase, UNESCO marks) remain the exclusive property of their '
        'respective owners. Their presence in the app does not imply endorsement of Sampada.'),
      PolicySection('9. Contact',
        'For all copyright-related enquiries, infringement notices, or licensing requests:\n$_contact'),
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
