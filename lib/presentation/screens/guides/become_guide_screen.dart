import 'package:flutter/material.dart';
import 'package:sampada/core/constants/app_colors.dart';

class BecomeGuideScreen extends StatefulWidget {
  const BecomeGuideScreen({super.key});

  @override
  State<BecomeGuideScreen> createState() => _BecomeGuideScreenState();
}

class _BecomeGuideScreenState extends State<BecomeGuideScreen> {
  bool _agreedToTerms = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                        hoverColor: Colors.white.withValues(alpha: 0.1),
                        splashColor: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 16),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Become a Guide',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Share your heritage knowledge',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- Scrollable Form Content ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join 248 verified guides',
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'Earn from sharing Nepal\'s\nliving heritage',
                            style: TextStyle(
                              fontSize: 12, 
                              color: isDark ? AppColors.darkTextSecondary : Colors.grey,
                            ),
                          ),
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
                          style: TextStyle(
                            color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00), 
                            fontWeight: FontWeight.bold, 
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Stepper UI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStep(context, 1, 'Profile', isActive: true),
                      _buildStepDivider(context),
                      _buildStep(context, 2, 'Expertise', isActive: false),
                      _buildStepDivider(context),
                      _buildStep(context, 3, 'Verify', isActive: false),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Personal Details Section
                  _buildSectionHeader(context, 'Personal Details'),
                  const SizedBox(height: 16),
                  _buildTextField(context, 'Full Name', 'Prabin Rokaya'),
                  const SizedBox(height: 16),
                  _buildTextField(context, 'Phone Number', '+977-XXXXXXXXXX'),
                  const SizedBox(height: 16),
                  _buildTextField(context, 'Location / District', 'Kathmandu'),
                  const SizedBox(height: 16),
                  Text('Languages Spoken', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildChip(context, 'Nepali', isSelected: true),
                      _buildChip(context, 'English', isSelected: true),
                      _buildChip(context, 'Hindi'),
                      _buildChip(context, '+ Add', isOutlined: true),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Guide Expertise Section
                  _buildSectionHeader(context, 'Guide Expertise'),
                  const SizedBox(height: 16),
                  Text('Specializations', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(context, 'Temples', isSelected: true),
                      _buildChip(context, 'Stupas', isSelected: true),
                      _buildChip(context, 'Palaces'),
                      _buildChip(context, 'Durbar Squares'),
                      _buildChip(context, 'Newari Culture'),
                      _buildChip(context, 'Trekking', isSelected: true),
                      _buildChip(context, 'Photography'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(context, 'Years of Experience', '3 years'),
                  const SizedBox(height: 16),
                  _buildTextField(context, 'Guide Bio', 'Describe your experience with Nepal\'s heritage...', maxLines: 4),

                  const SizedBox(height: 24),
                  Text('Pricing (NPR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(context, 'Half Day', '2,500')),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField(context, 'Full Day', '3,000-6,000')),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Verification Documents Section
                  _buildSectionHeader(context, 'Verification Documents'),
                  const SizedBox(height: 16),
                  _buildUploadTile(
                    context: context,
                    title: 'Citizenship / National ID',
                    subtitle: 'JPG, PNG or PDF — max 5 MB',
                    isUploaded: false,
                  ),
                  const SizedBox(height: 12),
                  _buildUploadTile(
                    context: context,
                    title: 'Guide Certification',
                    subtitle: 'guide_certificate_2024.pdf - 2.1 MB',
                    isUploaded: true,
                  ),

                  const SizedBox(height: 20),

                  // Terms Agreement
                  Row(
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
                        activeColor: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
                        side: isDark ? BorderSide(color: AppColors.darkBorder) : null,
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: 'I agree to ',
                            children: [
                              TextSpan(text: 'Sampada\'s Guide Terms', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00))),
                              const TextSpan(text: ' & Code of Conduct'),
                            ],
                          ),
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Submit Guide Application', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Center(
                    child: Column(
                      children: [
                        Text('Applications reviewed within 3-5 business days.', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
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

  Widget _buildStep(BuildContext context, int number, String label, {bool isActive = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    final inactiveColor = isDark ? AppColors.darkBgCard : Colors.white;
    final borderColor = isActive ? activeColor : (isDark ? AppColors.darkBorder : const Color(0xFFF7EED3));

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Center(
            child: Text(
              '$number',
              style: TextStyle(color: isActive ? (isDark ? Colors.black : Colors.white) : (isDark ? AppColors.darkTextTertiary : Colors.grey), fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: isActive ? activeColor : (isDark ? AppColors.darkTextTertiary : Colors.grey), fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStepDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFF8C7162), letterSpacing: 0.5),
        ),
        const SizedBox(width: 16),
        Expanded(child: Divider(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3))),
      ],
    );
  }

  Widget _buildTextField(BuildContext context, String label, String hint, {int maxLines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          maxLines: maxLines,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? AppColors.darkTextTertiary : Colors.black, fontSize: 14),
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

  Widget _buildChip(BuildContext context, String label, {bool isSelected = false, bool isOutlined = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    final inactiveBg = isDark ? AppColors.darkBgCard : Colors.white;
    final activeText = isDark ? Colors.black : Colors.white;
    final inactiveText = isDark ? AppColors.darkTextSecondary : Colors.grey;
    final borderColor = isSelected ? activeBg : (isDark ? AppColors.darkBorder : const Color(0xFFF7EED3));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(color: isSelected ? activeText : inactiveText, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  Widget _buildUploadTile({required BuildContext context, required String title, required String subtitle, required bool isUploaded}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uploadedBg = isDark ? const Color(0xFF1B3A26) : const Color(0xFFE8F5E9);
    final uploadedBorder = isDark ? const Color(0xFF2E7D32) : const Color(0xFF3DA35D);
    final uploadedText = isDark ? const Color(0xFF81C784) : const Color(0xFF3DA35D);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUploaded ? uploadedBg : (isDark ? AppColors.darkBgCard : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUploaded ? uploadedBorder : (isDark ? AppColors.darkBorder : const Color(0xFFF7EED3))),
      ),
      child: Row(
        children: [
          Icon(isUploaded ? Icons.check_circle : Icons.badge_outlined, color: isUploaded ? uploadedText : (isDark ? AppColors.darkTextTertiary : Colors.grey)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : Colors.grey)),
              ],
            ),
          ),
          if (isUploaded)
            TextButton.icon(
              onPressed: () {},
              icon: Icon(Icons.close, size: 14, color: uploadedText),
              label: Text('Remove', style: TextStyle(color: uploadedText, fontSize: 12)),
            )
          else
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.darkBgPage : const Color(0xFFF7EED3),
                foregroundColor: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: isDark ? BorderSide(color: AppColors.darkBorder) : null,
              ),
              child: const Text('Upload', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}







