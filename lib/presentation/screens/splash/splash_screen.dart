import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SplashScreen for Sampada — Nepal's Heritage in Your Pocket
///
/// Usage:
///   Replace `_SplashScreenState._logoPlaceholder()` with:
///   Image.asset('assets/images/sampada_logo.png', fit: BoxFit.contain)
///
///   The pulsing rings are handled by [_RippleRings] and animate automatically.
///   Page indicator dots at the bottom reflect the current onboarding page (0-indexed).
///   Pass [currentPage] and [totalPages] to customise.
class SplashScreen extends StatefulWidget {
  /// Which dot is highlighted (0-indexed). Default 1 matches the design.
  final int currentPage;

  /// Total number of onboarding pages.
  final int totalPages;

  /// Called when the screen is ready to navigate forward.
  final VoidCallback? onReady;

  const SplashScreen({
    super.key,
    this.currentPage = 1,
    this.totalPages = 3,
    this.onReady,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ── Controllers ────────────────────────────────────────────────────────────
  late final AnimationController _logoController;
  late final AnimationController _textController;
  late final AnimationController _dotsController;

  // ── Animations ─────────────────────────────────────────────────────────────
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _dotsOpacity;

  // ── State for Animated Dots ────────────────────────────────────────────────
  int _activeDotIndex = 0;
  Timer? _dotTimer;
  final Stopwatch _stopwatch = Stopwatch();

  // ── Colors (from the design) ────────────────────────────────────────────────
  // Removed local constants, using AppColors instead

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.brownDeep,
      ),
    );

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _dotsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dotsController, curve: Curves.easeIn),
    );

    _startSequence();
    _startDotAnimation();
  }

  void _startDotAnimation() {
    _dotTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (mounted) {
        setState(() {
          _activeDotIndex = (_activeDotIndex + 1) % widget.totalPages;
        });
      }
    });
  }

  Future<void> _startSequence() async {
    _stopwatch.start();
    await Future.delayed(const Duration(milliseconds: 300));
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _textController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _dotsController.forward();
    
    // Ensure total time is at least 3 seconds
    final elapsed = _stopwatch.elapsedMilliseconds;
    const totalTarget = 2500;
    if (elapsed < totalTarget) {
      await Future.delayed(Duration(milliseconds: totalTarget - elapsed));
    }
    
    // Wait for AuthProvider to be initialized if not already
    if (mounted) {
      final authProvider = context.read<AuthProvider>();
      final navigator = Navigator.of(context);

      // If Firebase is still checking the session, wait for it
      int retryCount = 0;
      while (!authProvider.isInitialized && retryCount < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        retryCount++;
      }

      if (!mounted) return;
      if (authProvider.isAuthenticated) {
        navigator.pushReplacementNamed(AppStrings.homePath);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final seen = prefs.getBool('hasSeenOnboarding') ?? false;
        if (seen) {
          navigator.pushReplacementNamed(AppStrings.homePath);
        } else {
          await prefs.setBool('hasSeenOnboarding', true);
          widget.onReady?.call();
        }
      }
    }
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    _logoController.dispose();
    _textController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.shortestSide >= 600;
    final isLargeTablet = size.shortestSide >= 900;

    // The native launch splash renders the emblem at a fixed 135dp on every
    // device (flutter_native_splash sizes it density-independently). The Flutter
    // splash must show it at the SAME size, or the logo visibly resizes on the
    // handoff — so this is a fixed 135, not a screen fraction.
    const logoSize = 135.0;
    final titleFontSize = isLargeTablet
        ? 56.0
        : isTablet
        ? 48.0
        : size.width * 0.115;
    final devanagariSize = isLargeTablet
        ? 28.0
        : isTablet
        ? 24.0
        : size.width * 0.058;
    final taglineSize = isLargeTablet
        ? 18.0
        : isTablet
        ? 16.0
        : size.width * 0.038;
    final ringMaxRadius = isLargeTablet
        ? 360.0
        : isTablet
        ? 300.0
        : size.width * 1;
    final dotSize = isTablet ? 10.0 : 8.0;
    final dotSpacing = isTablet ? 10.0 : 8.0;

    return Scaffold(
      backgroundColor: AppColors.brownDeep,
      body: Stack(
        children: [
          _buildBackground(),

          // CENTER AREA (logo + ripple)
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                _RippleRings(
                  maxRadius: ringMaxRadius,
                  ringColor: const Color(0x33C8851A),
                  ringCount: 3,
                ),
                _LogoBadge(size: logoSize),
              ],
            ),
          ),

          // BOTTOM CONTENT (text + dots)
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Spacer(), // pushes content down
                FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Center(
                      child: _TextBlock(
                        titleFontSize: titleFontSize,
                        devanagariSize: devanagariSize,
                        taglineSize: taglineSize,
                        gold: AppColors.goldMain,
                        lightGold: AppColors.goldLight,
                        creamWhite: AppColors.bgCream,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                FadeTransition(
                  opacity: _dotsOpacity,
                  child: _PageDots(
                    current: _activeDotIndex,
                    total: widget.totalPages,
                    dotSize: dotSize,
                    spacing: dotSpacing,
                    activeColor: AppColors.goldMain,
                    inactiveColor: const Color(0x33C8851A),
                  ),
                ),

                SizedBox(height: isTablet ? 48 : 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    // Flat temple-red, identical to the native launch window (and to the
    // Android 12 system splash, which only supports a solid colour). A gradient
    // here would make the handoff from the native splash visibly change colour.
    return const ColoredBox(color: AppColors.brownDeep);
  }
}

// ── Logo badge ────────────────────────────────────────────────────────────────

class _LogoBadge extends StatelessWidget {
  final double size;

  const _LogoBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    // The bare emblem, exactly as the native launch splash shows it
    // (@drawable/splash is the same PNG, centred). No extra gold ring, shadow,
    // or radial background — those would make the Flutter logo look different
    // from the native one at the handoff. The emblem already carries its own
    // gold border in the artwork.
    return Image.asset(
      'assets/images/Sampada-logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

// ── Ripple rings ──────────────────────────────────────────────────────────────

class _RippleRings extends StatefulWidget {
  final double maxRadius;
  final Color ringColor;
  final int ringCount;

  const _RippleRings({
    required this.maxRadius,
    required this.ringColor,
    required this.ringCount,
  });

  @override
  State<_RippleRings> createState() => _RippleRingsState();
}

class _RippleRingsState extends State<_RippleRings>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widget.maxRadius * 2, widget.maxRadius * 2),
          painter: _RipplePainter(
            progress: _ctrl.value,
            maxRadius: widget.maxRadius,
            ringColor: widget.ringColor,
            ringCount: widget.ringCount,
          ),
        );
      },
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;
  final double maxRadius;
  final Color ringColor;
  final int ringCount;

  const _RipplePainter({
    required this.progress,
    required this.maxRadius,
    required this.ringColor,
    required this.ringCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < ringCount; i++) {
      final offset = i / ringCount;
      final rawProgress = (progress + offset) % 1.0;

      // Ease in-out for smoother pulse
      final eased = _easeInOut(rawProgress);

      final radius = maxRadius * (0.35 + eased * 0.65);
      final opacity = (1.0 - eased).clamp(0.0, 1.0) * 0.55;

      final paint = Paint()
        ..color = ringColor.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  double _easeInOut(double t) =>
      t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}

// ── Text block ────────────────────────────────────────────────────────────────

class _TextBlock extends StatelessWidget {
  final double titleFontSize;
  final double devanagariSize;
  final double taglineSize;
  final Color gold;
  final Color lightGold;
  final Color creamWhite;

  const _TextBlock({
    required this.titleFontSize,
    required this.devanagariSize,
    required this.taglineSize,
    required this.gold,
    required this.lightGold,
    required this.creamWhite,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // SAMPADA wordmark
        Text(
          AppStrings.appName,
          style: TextStyle(
            fontSize: titleFontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: titleFontSize * 0.1,
            color: lightGold,
            shadows: [
              Shadow(
                color: gold.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),

        // Devanagari subtitle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            'सम्पदा',
            style: TextStyle(
              fontSize: devanagariSize,
              fontWeight: FontWeight.w500,
              color: gold,
              letterSpacing: 2.0,
            ),
          ),
        ),

        // Gold divider line
        Container(
          width: 48,
          height: 1.5,
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: gold,
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
          ),
        ),

        // Tagline
        Text(
          "Nepal's Heritage in Your Pocket",
          style: TextStyle(
            fontSize: taglineSize,
            fontWeight: FontWeight.w400,
            color: creamWhite.withValues(alpha: 0.85),
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Page dots ─────────────────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int current;
  final int total;
  final double dotSize;
  final double spacing;
  final Color activeColor;
  final Color inactiveColor;

  const _PageDots({
    required this.current,
    required this.total,
    required this.dotSize,
    required this.spacing,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: EdgeInsets.symmetric(horizontal: spacing / 2),
          width: isActive ? dotSize * 2.5 : dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(dotSize / 2),
          ),
        );
      }),
    );
  }
}






