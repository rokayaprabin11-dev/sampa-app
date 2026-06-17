import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/providers/locale_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import 'package:sampada/core/services/permission_service.dart';
import 'package:sampada/core/services/location_service.dart';

// --- Data Model for Slides ---
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
  bool _showAuthOptions = false;

  // --- Dummy Data ---
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

    // Auto-slider logic
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      // Note: This length check is a bit tricky with localized slides.
      // We assume 3 slides as per the data model.
      const totalSlides = 3;
      if (_currentPage < totalSlides - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

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
          // --- Top Section: Image Slider ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.55, // Takes up top 55% of screen
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: slides.length,
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      slides[index].imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xFF4A1F0D),
                        child: const Icon(Icons.image_not_supported, color: Colors.white),
                            ),
                    ),

                    // Location Text
                    Positioned(
                      bottom: size.height * 0.5 + 20,
                      left: 20,
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/icons/mark.png',
                            width: 20,
                            height: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            slides[index].location,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                );
              },
            ),
          ),

          // --- Bottom Section: Content Card ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: size.height * 0.5, // Takes bottom 50%
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              decoration: const BoxDecoration(
                color: AppColors.bgPage, // Off-white background
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  final offsetAnimation = Tween<Offset>(
                    begin: const Offset(0.0, 0.2),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ));
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    ),
                  );
                },
                child: _showAuthOptions
                    ? _buildAuthBlock(context, l10n, AppColors.brownDark, AppColors.textHeadline)
                    : _buildInfoBlock(context, l10n, slides, AppColors.brownDark, AppColors.textHeadline),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock(BuildContext context, AppLocalizations l10n, List<SlideData> slides, Color primaryBrown, Color darkText) {
    return Column(
      key: const ValueKey('info_block'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Indicators (Dots)
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              slides.length,
              (index) => buildIndicator(index == _currentPage),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Title
        Text(
          l10n.discoverNepal,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: darkText,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        // Yellow Underline
        Container(
          width: 45,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.goldMain,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Description
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

        // Get Started Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () async {
              // Request permissions when user starts
              final permissionService = PermissionService();
              await permissionService.requestInitialPermissions();
              
              // Optionally pre-fetch location
              final locationService = LocationService();
              locationService.getCurrentPosition();

              setState(() {
                _showAuthOptions = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBrown,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
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
        const SizedBox(height: 24),

        // Language Toggler
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
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAuthBlock(BuildContext context, AppLocalizations l10n, Color primaryBrown, Color darkText) {
    return Column(
      key: const ValueKey('auth_block'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Back Button
        IconButton(
          onPressed: () {
            setState(() {
              _showAuthOptions = false;
            });
          },
          icon: const Icon(Icons.arrow_back, color: AppColors.textTertiary),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          hoverColor: AppColors.brownUltraLight.withValues(alpha: 0.5),
          splashColor: AppColors.brownUltraLight,
        ),
        const SizedBox(height: 16),

        // Title
        Text(
          l10n.joinJourney,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: darkText,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        // Yellow Underline
        Container(
          width: 45,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.goldMain,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        Text(
          l10n.authDesc,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),

        // Google Sign In Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () async {
              final authProvider = context.read<AuthProvider>();
              await authProvider.signInWithGoogle();
              if (context.mounted) {
                if (authProvider.isAuthenticated) {
                  Navigator.pushReplacementNamed(context, AppStrings.homePath);
                } else if (authProvider.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(authProvider.error!)),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              side: const BorderSide(color: AppColors.brownLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.g_mobiledata, size: 32, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  l10n.googleSignIn,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Login & Register Buttons
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppStrings.loginPath);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBrown,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    l10n.login,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, AppStrings.registerPath);
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    side: BorderSide(color: primaryBrown),
                  ),
                  child: Text(
                    l10n.register,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryBrown,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // Helper widget for slider dots
  Widget buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 6,
      width: isActive ? 24 : 6,
      decoration: BoxDecoration(
        color: isActive ? AppColors.brownDark : AppColors.brownUltraLight,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  // Helper widget for language buttons
  Widget _buildLanguageButton(BuildContext context, String langCode, String text) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isSelected = localeProvider.locale.languageCode == langCode;

    return GestureDetector(
      onTap: () {
        localeProvider.setLocale(Locale(langCode));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brownDark : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
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







