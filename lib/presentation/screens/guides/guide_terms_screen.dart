import 'package:flutter/material.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';

class GuideTermsScreen extends StatelessWidget {
  const GuideTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.brownDeep : AppColors.kColorDeep,
        foregroundColor: Colors.white,
        title: const Text('Guide Terms & Code of Conduct', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(isDark, 'Sampada Guide Terms & Code of Conduct'),
            _subtitle(isDark, 'Effective Date: June 2025 · Version 1.0'),
            const SizedBox(height: 8),
            _para(cs, 'By submitting a guide application on Sampada, you agree to the following terms and code of conduct. These rules protect tourists, preserve Nepal\'s heritage, and uphold the reputation of the Sampada platform.'),

            const SizedBox(height: 24),
            _section(isDark, '1. Eligibility'),
            _para(cs, 'To become a Sampada Guide, you must:'),
            _bullet(cs, 'Be at least 18 years of age.'),
            _bullet(cs, 'Hold valid identification (citizenship card or passport).'),
            _bullet(cs, 'Have working knowledge of at least one language listed in your profile.'),
            _bullet(cs, 'Not have been convicted of any criminal offence involving fraud, violence, or exploitation of tourists.'),

            const SizedBox(height: 24),
            _section(isDark, '2. Accurate Representation'),
            _bullet(cs, 'All information submitted in your application must be truthful and accurate.'),
            _bullet(cs, 'You must not falsely claim certifications, experience, or qualifications you do not hold.'),
            _bullet(cs, 'Profile photos must be a clear, recent image of yourself.'),
            _bullet(cs, 'Misrepresentation is grounds for immediate removal from the platform.'),

            const SizedBox(height: 24),
            _section(isDark, '3. Professional Conduct'),
            _para(cs, 'As a Sampada Guide, you are expected to:'),
            _bullet(cs, 'Arrive punctually for all confirmed bookings.'),
            _bullet(cs, 'Treat all tourists with courtesy and respect regardless of their nationality, religion, gender, or background.'),
            _bullet(cs, 'Communicate cancellations at least 24 hours in advance. Repeated last-minute cancellations may result in suspension.'),
            _bullet(cs, 'Not consume alcohol or be under any influence during a tour.'),
            _bullet(cs, 'Dress appropriately when visiting religious or culturally sensitive sites.'),
            _bullet(cs, 'Never pressure tourists into purchases, tips, or additional services.'),

            const SizedBox(height: 24),
            _section(isDark, '4. Heritage Preservation'),
            _para(cs, 'Nepal\'s heritage sites are irreplaceable. Guides are stewards of these spaces.'),
            _bullet(cs, 'Never encourage tourists to touch, climb, or deface heritage structures.'),
            _bullet(cs, 'Follow all rules set by the Department of Archaeology and site management.'),
            _bullet(cs, 'Correct misinformation about sites respectfully and accurately.'),
            _bullet(cs, 'Do not conduct tours in restricted or closed sections of heritage sites.'),
            _bullet(cs, 'Report any observed damage to heritage structures to the relevant authority.'),

            const SizedBox(height: 24),
            _section(isDark, '5. Pricing & Payments'),
            _bullet(cs, 'Rates displayed on your profile must reflect the actual fees charged.'),
            _bullet(cs, 'Do not request payments outside the Sampada platform to avoid disputes and protect both parties.'),
            _bullet(cs, 'Additional charges (entry fees, transport) must be disclosed upfront before the tour begins.'),
            _bullet(cs, 'Sampada retains a 10% service fee on bookings processed through the platform.'),

            const SizedBox(height: 24),
            _section(isDark, '6. Safety & Emergency'),
            _bullet(cs, 'You are responsible for the safety and well-being of tourists in your care.'),
            _bullet(cs, 'Carry a charged mobile phone during all tours.'),
            _bullet(cs, 'Know the nearest hospitals and police stations for sites you regularly guide at.'),
            _bullet(cs, 'In case of a tourist emergency, contact emergency services immediately (Police: 100, Ambulance: 102) and notify Sampada support.'),

            const SizedBox(height: 24),
            _section(isDark, '7. Privacy & Data'),
            _bullet(cs, 'Do not share tourist personal information (names, contact details, itineraries) with third parties.'),
            _bullet(cs, 'Photos or videos of tourists may only be shared publicly with their explicit consent.'),
            _bullet(cs, 'Sampada may collect booking and activity data to improve services.'),

            const SizedBox(height: 24),
            _section(isDark, '8. Reviews & Feedback'),
            _bullet(cs, 'Do not attempt to manipulate or solicit fake reviews.'),
            _bullet(cs, 'Respond to negative reviews professionally and constructively.'),
            _bullet(cs, 'Sampada investigates disputes fairly. Guides found to have acted in bad faith will be penalised.'),

            const SizedBox(height: 24),
            _section(isDark, '9. Termination'),
            _para(cs, 'Sampada reserves the right to suspend or permanently remove any guide who:'),
            _bullet(cs, 'Violates any section of this Code of Conduct.'),
            _bullet(cs, 'Receives sustained negative reviews indicating unsafe or unprofessional behaviour.'),
            _bullet(cs, 'Is found to have provided false information in their application.'),
            _bullet(cs, 'Is convicted of a criminal offence.'),

            const SizedBox(height: 24),
            _section(isDark, '10. Amendments'),
            _para(cs, 'Sampada may update these terms at any time. Guides will be notified via push notification and must re-accept updated terms to continue operating on the platform.'),

            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBgCard : AppColors.kColorBorderCream,
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusLg),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.kColorAccentPale),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: isDark ? AppColors.goldMain : AppColors.kColorDeep, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Questions? Contact us at guides@sampada.app or through the Help section in your profile.',
                      style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.kColorDeep),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _header(bool isDark, String text) => Text(
    text,
    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? AppColors.goldMain : AppColors.kColorDeep),
  );

  Widget _subtitle(bool isDark, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(text, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.kColorTextMuted)),
  );

  Widget _section(bool isDark, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : AppColors.kColorDeep)),
  );

  Widget _para(ColorScheme cs, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.6)),
  );

  Widget _bullet(ColorScheme cs, String text) => Padding(
    padding: const EdgeInsets.only(left: 8, bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('• ', style: TextStyle(fontSize: 13, color: cs.onSurface, fontWeight: FontWeight.bold)),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.5))),
      ],
    ),
  );
}
