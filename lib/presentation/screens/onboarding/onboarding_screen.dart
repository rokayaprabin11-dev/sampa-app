import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/providers/locale_provider.dart';
import 'package:sampada/core/services/permission_service.dart';
import 'package:sampada/core/services/location_service.dart';

class SlideData {
  final String location;
  final String imageUrl;

  SlideData({required this.location, required this.imageUrl});
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  late PageController _pageController;
  Timer? _timer;

  List<SlideData> _getSlides(AppLocalizations l10n) => [
    SlideData(
      location: l10n.pashupatinath,
      imageUrl: 'assets/images/onboarding/pashupatinath-nepal.jpg',
    ),
    SlideData(
      location: l10n.lumbini,
      imageUrl: 'assets/images/onboarding/lumbini.jpg',
    ),
    SlideData(
      location: l10n.swayambhunath,
      imageUrl: 'assets/images/onboarding/Swayambhunath-Stupa.jpg',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      const totalSlides = 3;
      _currentPage = (_currentPage + 1) % totalSlides;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;
    final slides = _getSlides(l10n);

    return Scaffold(
      body: Stack(
        children: [
          // Top image slider
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.55,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: slides.length,
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      slides[index].imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF4A1F0D),
                        child: const Icon(Icons.image_not_supported, color: Colors.white),
                      ),
                    ),
                    Positioned(
                      bottom: size.height * 0.05 + 12,
                      left: 20,
                      right: 20,
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            slides[index].location,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Bottom content card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppDimensions.kRadiusXxl),
                  topRight: Radius.circular(AppDimensions.kRadiusXxl),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Slide indicators
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        slides.length,
                        (i) => _buildIndicator(i == _currentPage),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    l10n.discoverNepal,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textHeadline,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 45,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.goldMain,
                      borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.onboardingDesc,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),

                  // Get Started
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () async {
                        await PermissionService().requestInitialPermissions();
                        LocationService().getCurrentPosition();
                        if (context.mounted) {
                          Navigator.pushReplacementNamed(context, AppStrings.homePath);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brownDark,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill)),
                        elevation: 0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            l10n.getStarted,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Language toggler
                  Row(
                    children: [
                      Text(
                        "${l10n.language}:",
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildLanguageButton(context, "en", "EN"),
                      const SizedBox(width: 8),
                      _buildLanguageButton(context, "ne", "नेपाली"),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 6,
      width: isActive ? 24 : 6,
      decoration: BoxDecoration(
        color: isActive ? AppColors.brownDark : AppColors.brownUltraLight,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
      ),
    );
  }

  Widget _buildLanguageButton(BuildContext context, String langCode, String text) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isSelected = localeProvider.locale.languageCode == langCode;

    return GestureDetector(
      onTap: () => localeProvider.setLocale(Locale(langCode)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brownDark : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(
            color: isSelected ? AppColors.brownDark : AppColors.brownLight,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
