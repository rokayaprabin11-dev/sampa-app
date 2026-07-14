import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/theme/app_theme.dart';

/// About Sampada.
///
/// The visual language is the app's own — the maroon→terracotta header, the
/// cream card surfaces, Cinzel headings over Crimson Pro body text, and the
/// Devanagari wordmark. Nothing here introduces a colour or a typeface that is
/// not already an [AppColors] token or a slot in the app [TextTheme]; the screen
/// reads as Sampada in the dark theme for the same reason.
///
/// Every row that says it does something actually does it: the version comes
/// from the installed package rather than a constant, the mail rows open a real
/// composer with the build details already filled in, and Open Source Licenses
/// opens Flutter's own [showLicensePage] over the packages actually linked into
/// this build. There is deliberately no "Rate on Play Store" row — the app is
/// not published, and a button that opens a missing listing is worse than no
/// button at all.

/// Where support mail goes. One address, so a bug report and a feature idea land
/// in the same inbox rather than one of them going nowhere.
const String _supportEmail = 'rokayaprabin11@gmail.com';

/// Maintained by hand at each release — nothing in the bundle records when it
/// was built, and inventing a date from the clock would be a lie on a stale
/// install. Update this line when you cut a release.
const String _lastUpdated = 'July 2026';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  PackageInfo? _info;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _info = info);
    } catch (_) {
      // Platform channel unavailable (a test harness, say). The version chip
      // simply stays quiet rather than showing a made-up number.
    }
  }

  String get _version => _info?.version ?? '—';
  String get _build => _info?.buildNumber ?? '—';

  String get _platform {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return Platform.operatingSystem;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        // Bounce past the ends rather than a hard stop — the hero is the first
        // thing you see and an overscroll glow chops it flat.
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: _Hero(version: _version, buildNumber: _build),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(AppDimensions.sp20,
                AppDimensions.sp24, AppDimensions.sp20, AppDimensions.sp40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _SectionLabel('About Sampada'),
                _AboutCard(child: _aboutText(context, dark)),

                const _SectionLabel('What You Can Do'),
                const _Capabilities(),

                const _SectionLabel('Our Vision'),
                _AboutCard(
                  child: _Quote(
                    title: 'A country that can explain itself',
                    text: 'A Nepal where every carved strut and every festival '
                        'drum has its story within reach — to the traveller who '
                        'arrived yesterday, and to the child who grew up in its '
                        'shadow and was never told.',
                  ),
                ),

                const _SectionLabel('Our Mission'),
                _AboutCard(
                  child: _Quote(
                    title: 'Heritage, made discoverable',
                    text: 'To carry Nepal’s heritage into the phone in your '
                        'hand without flattening it — accurate about the '
                        'history, honest about the practicalities, and fair to '
                        'the guides and communities who keep these places '
                        'standing.',
                  ),
                ),

                const _SectionLabel('Developed By'),
                const _Team(),

                const _SectionLabel('Application Information'),
                _AboutCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.sp20,
                      vertical: AppDimensions.sp8),
                  child: Column(
                    children: [
                      _InfoRow(label: 'Version', value: _version),
                      _InfoRow(label: 'Build', value: _build),
                      // Derived, not asserted: a debug build says so instead of
                      // claiming to be the stable one.
                      _InfoRow(
                          label: 'Release',
                          value: kDebugMode ? 'Debug' : 'Stable'),
                      _InfoRow(label: 'Platform', value: _platform),
                      _InfoRow(
                          label: 'Last Updated',
                          value: _lastUpdated,
                          last: true),
                    ],
                  ),
                ),

                const _SectionLabel('Contact & Support'),
                _AboutCard(
                  child: Column(
                    children: [
                      _ActionRow(
                        icon: Icons.support_agent_outlined,
                        label: 'Contact Support',
                        hint: 'Ask us anything about the app',
                        onTap: () => _mail(context, 'Sampada — Support request'),
                      ),
                      _ActionRow(
                        icon: Icons.rate_review_outlined,
                        label: 'Send Feedback',
                        hint: 'Tell us what to build next',
                        onTap: () => _mail(context, 'Sampada — Feedback'),
                      ),
                      _ActionRow(
                        icon: Icons.bug_report_outlined,
                        label: 'Report an Issue',
                        hint: 'Something broken or wrong',
                        onTap: () => _mail(context, 'Sampada — Issue report'),
                      ),
                      _ActionRow(
                        icon: Icons.ios_share_outlined,
                        label: 'Share the App',
                        hint: 'Pass Sampada on',
                        onTap: _share,
                        last: true,
                      ),
                    ],
                  ),
                ),

                const _SectionLabel('Legal'),
                _AboutCard(
                  child: Column(
                    children: [
                      _ActionRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        onTap: () => Navigator.pushNamed(
                            context, AppStrings.privacyPolicyPath),
                      ),
                      _ActionRow(
                        icon: Icons.description_outlined,
                        label: 'Terms & Conditions',
                        onTap: () =>
                            Navigator.pushNamed(context, AppStrings.termsPath),
                      ),
                      _ActionRow(
                        icon: Icons.article_outlined,
                        label: 'Open Source Licenses',
                        hint: 'The software Sampada is built on',
                        onTap: () => _openLicenses(context),
                      ),
                      _ActionRow(
                        icon: Icons.volunteer_activism_outlined,
                        label: 'Acknowledgements',
                        onTap: () => _openAcknowledgements(context),
                        last: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppDimensions.sp8),
                const _Footer(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutText(BuildContext context, bool dark) {
    final t = Theme.of(context).textTheme;
    final body = t.bodyLarge?.copyWith(
      height: 1.6,
      color: dark ? AppColors.kDarkTextPrimary : AppColors.kColorTextBody,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The Devanagari line is not decoration: for a large part of the
        // audience it is the sentence they read first, so it leads.
        Text(
          'सम्पदा नेपालको सांस्कृतिक, ऐतिहासिक र प्राकृतिक सम्पदा खोज्न, बुझ्न र '
          'अनुभव गर्न बनाइएको डिजिटल प्लेटफर्म हो — मन्दिर, स्तूप, दरबार '
          'क्षेत्रदेखि जीवित परम्परा र जात्रासम्म।',
          style: GoogleFonts.notoSerifDevanagari(
            fontSize: 15,
            height: 1.75,
            fontWeight: FontWeight.w500,
            color: dark ? AppColors.kColorAccentLight : AppColors.kColorDeep,
          ),
        ),
        const SizedBox(height: AppDimensions.sp14),
        Text(
          'Sampada — सम्पदा, “inheritance” — is a heritage and travel companion '
          'for Nepal. It gathers the temples, stupas, durbar squares and living '
          'traditions of this country into one place, and tries to explain them '
          'rather than merely list them.',
          style: body,
        ),
        const SizedBox(height: AppDimensions.sp10),
        Text(
          'Search a site by name, by district, or simply by what you half '
          'remember about it. Follow the festivals as the calendar turns. Hire a '
          'guide who actually grew up with these stones, agree the price before '
          'you set out, and settle it afterwards. Save what moved you, and say '
          'what the visit was really like.',
          style: body,
        ),
        const SizedBox(height: AppDimensions.sp10),
        Text(
          'The app is built for the way Nepal is actually travelled: in both '
          'Nepali and English, and often far from a signal. Sites you have '
          'opened stay readable when the network does not, because a courtyard '
          'in the hills should not need four bars to be understood.',
          style: body,
        ),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Opens the mail composer with the build details already in the body — a bug
  /// report without a version and a platform costs a round trip to be useful.
  Future<void> _mail(BuildContext context, String subject) async {
    final messenger = ScaffoldMessenger.of(context);
    final body = '\n\n---\nSampada $_version (build $_build) · $_platform';
    final uri = Uri.parse(
      'mailto:$_supportEmail'
      '?subject=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (opened) return;
    } catch (_) {
      // No mail app configured — fall through and hand over the address, which
      // is the only thing the user actually needs from us.
    }
    messenger.showSnackBar(const SnackBar(
      content: Text('No mail app found. Write to $_supportEmail'),
    ));
  }

  Future<void> _share() async {
    // No store link and no website yet, so the share is the pitch itself rather
    // than a URL that would 404.
    await SharePlus.instance.share(ShareParams(
      text: 'Sampada — discover the living heritage of Nepal: heritage sites, '
          'cultural events, and verified local guides.',
      subject: 'Sampada',
    ));
  }

  /// Flutter's own licence registry, so the list is the packages actually linked
  /// into this build rather than one we curated and let rot.
  void _openLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'Sampada · सम्पदा',
      applicationVersion: 'Version $_version (build $_build)',
      applicationLegalese: '© 2026 DevelopMENTAL. All rights reserved.',
      applicationIcon: const Padding(
        padding: EdgeInsets.only(top: AppDimensions.sp8),
        child: _AppLogo(size: 64),
      ),
    );
  }

  void _openAcknowledgements(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    // Every line here is something Sampada genuinely depends on. The map
    // attribution in particular is a condition of using the tiles, not a
    // courtesy.
    const credits = <(String, String)>[
      (
        'The custodians of these places',
        'The priests, caretakers, guthis and neighbourhoods who have kept these '
            'courtyards standing for centuries. Sampada only describes what they '
            'preserve.'
      ),
      (
        'OpenStreetMap contributors',
        'Every map in this app is drawn from their data. © OpenStreetMap '
            'contributors, licensed under the ODbL.'
      ),
      (
        'Flutter & Dart',
        'The framework and language Sampada is written in.'
      ),
      (
        'Firebase & Cloudinary',
        'Sign-in, notifications, the guide chat, and the delivery of every '
            'photograph you scroll past.'
      ),
      (
        'Google Fonts',
        'Cinzel, Crimson Pro and Noto Serif Devanagari — the three typefaces '
            'this app speaks in.'
      ),
      (
        'The open-source community',
        'The packages listed under Open Source Licenses. Without them, four '
            'developers could not have built this.'
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppDimensions.kRadiusXxl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.sp20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDimensions.sp16),
                  decoration: BoxDecoration(
                    color: dark
                        ? AppColors.kDarkBorder
                        : AppColors.kColorBorderSubtle,
                    borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
                  ),
                ),
              ),
              Text('Acknowledgements', style: t.titleMedium),
              const SizedBox(height: AppDimensions.sp4),
              Text(
                'Sampada is built on other people’s work, and on heritage that '
                'belongs to no one company.',
                style: t.bodySmall?.copyWith(
                    height: 1.4,
                    color: dark
                        ? AppColors.kDarkTextSecond
                        : AppColors.kColorTextSecondary),
              ),
              const SizedBox(height: AppDimensions.sp16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (name, what) in credits)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppDimensions.sp14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 5),
                                child: Icon(Icons.brightness_1,
                                    size: 6, color: AppColors.kColorAccent),
                              ),
                              const SizedBox(width: AppDimensions.sp10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: t.titleSmall),
                                    const SizedBox(height: AppDimensions.sp2),
                                    Text(what,
                                        style: t.bodySmall?.copyWith(
                                            height: 1.45,
                                            color: dark
                                                ? AppColors.kDarkTextSecond
                                                : AppColors
                                                    .kColorTextSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────

/// Maroon→terracotta header with the pagoda mark, the bilingual wordmark, and
/// the real installed version. Sizes to its content, so it neither clips on a
/// small phone nor leaves a dead band on a tall one.
class _Hero extends StatelessWidget {
  final String version;

  /// Named `buildNumber`, not `build` — a field called `build` would collide
  /// with [StatelessWidget.build].
  final String buildNumber;

  const _Hero({required this.version, required this.buildNumber});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppTheme.navGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppDimensions.kRadiusXxl + 14),
          bottomRight: Radius.circular(AppDimensions.kRadiusXxl + 14),
        ),
      ),
      child: Stack(
        children: [
          // Mandala rings, clipped by the header itself. Purely atmospheric, so
          // they are hidden from screen readers.
          Positioned.fill(
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppDimensions.kRadiusXxl + 14),
                  bottomRight: Radius.circular(AppDimensions.kRadiusXxl + 14),
                ),
                child: CustomPaint(painter: _RingsPainter()),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppDimensions.sp8,
                  AppDimensions.sp4, AppDimensions.sp8, AppDimensions.sp32),
              child: Column(
                children: [
                  Row(
                    children: [
                      // 48dp target, unlike a bare Icon.
                      IconButton(
                        tooltip: MaterialLocalizations.of(context)
                            .backButtonTooltip,
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.kColorTextOnHeader),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'ABOUT',
                          textAlign: TextAlign.center,
                          style: t.labelSmall?.copyWith(
                            color: AppColors.kColorAccentLight,
                            fontSize: 11,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // balances the back button
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sp12),
                  const _AppLogo(size: 104),
                  const SizedBox(height: AppDimensions.sp16),
                  // One label for the pair: a reader should hear the app's name
                  // once, not the same word twice in two scripts.
                  Semantics(
                    label: 'Sampada',
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          Text(
                            'सम्पदा',
                            style: GoogleFonts.notoSerifDevanagari(
                              fontSize: 34,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: AppColors.kColorAccentLight,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.sp6),
                          Text(
                            'SAMPADA',
                            style: GoogleFonts.cinzel(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 6,
                              color: AppColors.kColorTextOnHeader
                                  .withValues(alpha: 0.92),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sp12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.sp32),
                    child: Text(
                      'The living heritage of Nepal,\nin the palm of your hand',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                        color: AppColors.kColorTextOnHeader
                            .withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sp16),
                  _VersionChip(version: version, buildNumber: buildNumber),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VersionChip extends StatelessWidget {
  final String version;
  final String buildNumber;

  const _VersionChip({required this.version, required this.buildNumber});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Version $version, build $buildNumber',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.sp16, vertical: AppDimensions.sp6),
          decoration: BoxDecoration(
            color: AppColors.kColorAccentLight.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
            border: Border.all(
                color: AppColors.kColorAccentLight.withValues(alpha: 0.42)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.brightness_1,
                  size: 6, color: AppColors.kColorAccentLight),
              const SizedBox(width: AppDimensions.sp8),
              Text(
                'VERSION $version · BUILD $buildNumber',
                style: GoogleFonts.cinzel(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: AppColors.kColorAccentLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Sampada emblem — the same `assets/images/Sampada-logo.png` the splash
/// screen opens with, so the app introduces itself here with the face it wears
/// everywhere else.
///
/// It is a full-colour circular crest, and it sits on the maroon header, so it
/// gets a soft gold halo behind it: without one the dark rim of the emblem
/// disappears into the gradient. The image is decorative — the wordmark beneath
/// already says the app's name, and a screen reader announcing it twice is noise.
class _AppLogo extends StatelessWidget {
  final double size;
  const _AppLogo({this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.kColorAccentLight.withValues(alpha: 0.35),
              blurRadius: 26,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Color(0x59000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Image.asset(
          'assets/images/Sampada-logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
          // The emblem is the one asset that must never fail open: if it cannot
          // be decoded, fall back to the wordmark's own gold rather than a
          // broken-image glyph on the header.
          errorBuilder: (_, __, ___) => Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.kColorAccentLight, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              'सम्पदा',
              style: GoogleFonts.notoSerifDevanagari(
                fontSize: size * 0.22,
                fontWeight: FontWeight.w600,
                color: AppColors.kColorAccentLight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The faint concentric rings behind the hero.
class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.kColorAccentLight.withValues(alpha: 0.16);
    final centre = Offset(size.width / 2, size.height * 0.46);
    for (final r in [130.0, 180.0, 235.0, 290.0]) {
      canvas.drawCircle(centre, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) => false;
}

// ── Layout primitives ────────────────────────────────────────────────────────

bool _isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

Color _muted(BuildContext c) =>
    _isDark(c) ? AppColors.kDarkTextMuted : AppColors.kColorTextMuted;
Color _secondary(BuildContext c) =>
    _isDark(c) ? AppColors.kDarkTextSecond : AppColors.kColorTextSecondary;
Color _border(BuildContext c) =>
    _isDark(c) ? AppColors.kDarkBorder : AppColors.kColorBorderSubtle;

/// Cinzel eyebrow with a hairline running off to the right — the section rhythm
/// the rest of the app already uses, in its own tokens.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppDimensions.sp4, AppDimensions.sp24, 0, AppDimensions.sp12),
      child: Row(
        children: [
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                text.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: _isDark(context)
                          ? AppColors.kColorAccentLight
                          : AppColors.kColorAccentSafe,
                    ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sp10),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_border(context), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app's standard surface card: theme surface, subtle border, soft shadow.
class _AboutCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _AboutCard({
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.sp20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
        border: Border.all(color: _border(context)),
        boxShadow: _isDark(context) ? null : AppTheme.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Vision / Mission: a gold-to-terracotta rule down the left, a Cinzel title,
/// and the statement itself.
class _Quote extends StatelessWidget {
  final String title;
  final String text;

  const _Quote({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.kColorAccentLight, AppColors.kColorAccent],
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sp16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: AppDimensions.sp8),
                Text(
                  text,
                  style: t.bodyLarge?.copyWith(
                      height: 1.55, color: _secondary(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── What you can do ──────────────────────────────────────────────────────────

/// Six things the app actually does. Every one of these is a screen that exists
/// — this is a description, not a roadmap.
class _Capabilities extends StatelessWidget {
  const _Capabilities();

  static const _items = <(IconData, String, String)>[
    (
      Icons.account_balance_outlined,
      'Explore Heritage Sites',
      'Temples, stupas, durbar squares and monuments across all 77 districts — '
          'each with its history, its rituals, and how to reach it.'
    ),
    (
      Icons.near_me_outlined,
      'Nearby Discovery',
      'See what heritage stands around you right now, and get a quiet nudge when '
          'you walk within reach of something worth stopping for.'
    ),
    (
      Icons.tour_outlined,
      'Book Local Guides',
      'Verified guides with real reviews. Pick a package, agree the price up '
          'front, message them before the tour, and settle up after it.'
    ),
    (
      Icons.celebration_outlined,
      'Follow the Festivals',
      'Indra Jatra, Bisket, Losar and the smaller jatras in between — what is '
          'happening, where, and when the crowds gather.'
    ),
    (
      Icons.star_outline,
      'Save & Review',
      'Bookmark the places that stayed with you, keep a record of where you have '
          'been, and tell the next traveller what the visit was really like.'
    ),
    (
      Icons.cloud_off_outlined,
      'Works Offline',
      'Sites you have opened stay with you when the signal does not — up the '
          'valleys, inside the temples, on the trail.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // A fixed-ratio grid clips the moment the user turns text size up, so the
    // cards are laid out as rows that grow with their content instead.
    return Column(
      children: [
        for (final (icon, title, blurb) in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.sp10),
            child: _AboutCard(
              padding: const EdgeInsets.all(AppDimensions.sp14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _isDark(context)
                          ? AppColors.kDarkBgCard
                          : AppColors.kColorTagBg,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.kRadiusLg),
                      border: Border.all(
                          color: AppColors.kColorAccentPale
                              .withValues(alpha: _isDark(context) ? 0.3 : 1)),
                    ),
                    child: Icon(icon,
                        size: AppDimensions.iconMd,
                        color: _isDark(context)
                            ? AppColors.kColorAccentLight
                            : AppColors.kColorAccentSafe),
                  ),
                  const SizedBox(width: AppDimensions.sp14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.titleSmall),
                        const SizedBox(height: AppDimensions.sp4),
                        Text(
                          blurb,
                          style: t.bodyMedium?.copyWith(
                              height: 1.45, color: _secondary(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Team ─────────────────────────────────────────────────────────────────────

class _Team extends StatelessWidget {
  const _Team();

  static const _members = <(String, String)>[
    ('Prabin Rokaya', 'Lead Developer · Full-stack'),
    ('Kushal Malla', 'Developer'),
    ('Sailendra Shahi', 'Developer'),
    ('Sulove Manandhar', 'Developer'),
  ];

  static const _avatarGradients = <List<Color>>[
    [AppColors.kColorAccent, AppColors.kColorDeep],
    [AppColors.kColorAccentLight, AppColors.kColorAccentDark],
    [AppColors.kColorPrimary, AppColors.kColorBrownDarkest],
    [AppColors.kColorPrimaryLight, AppColors.kColorPrimaryDark],
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return _AboutCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // The team crest. Not a tappable row — there is nowhere to go.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.sp20, vertical: AppDimensions.sp16),
            decoration: BoxDecoration(
              color: _isDark(context)
                  ? AppColors.kDarkBgCard
                  : AppColors.kColorBgWarm,
              border: Border(bottom: BorderSide(color: _border(context))),
            ),
            child: Column(
              children: [
                Text(
                  'DevelopMENTAL',
                  style: GoogleFonts.cinzel(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: _isDark(context)
                        ? AppColors.kColorAccentLight
                        : AppColors.kColorDeep,
                  ),
                ),
                const SizedBox(height: AppDimensions.sp4),
                Text(
                  'Four developers, one country worth documenting',
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic, color: _secondary(context)),
                ),
              ],
            ),
          ),
          for (var i = 0; i < _members.length; i++)
            _MemberRow(
              name: _members[i].$1,
              role: _members[i].$2,
              gradient: _avatarGradients[i % _avatarGradients.length],
              last: i == _members.length - 1,
            ),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final String name;
  final String role;
  final List<Color> gradient;
  final bool last;

  const _MemberRow({
    required this.name,
    required this.role,
    required this.gradient,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.sp16, vertical: AppDimensions.sp12),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: _border(context))),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
            ),
            child: Text(
              name.characters.first,
              style: GoogleFonts.cinzel(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.kColorTextOnPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.sp14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.titleSmall?.copyWith(fontSize: 15)),
                const SizedBox(height: AppDimensions.sp2),
                Text(
                  role,
                  style: t.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic, color: _secondary(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Rows ─────────────────────────────────────────────────────────────────────

/// Label ↔ value, for Application Information.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool last;

  const _InfoRow({required this.label, required this.value, this.last = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(bottom: BorderSide(color: _border(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: t.bodyMedium?.copyWith(color: _secondary(context))),
              ),
              const SizedBox(width: AppDimensions.sp12),
              Text(
                value,
                style: t.titleSmall?.copyWith(fontSize: 13.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable row: icon in a tinted square, label, optional hint, chevron.
/// Minimum 56dp tall, so it clears the 48dp touch target even before the user
/// turns text size up.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;
  final VoidCallback onTap;
  final bool last;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = _isDark(context);

    return Semantics(
      button: true,
      label: label,
      hint: hint,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.kColorPrimary.withValues(alpha: 0.08),
            highlightColor: AppColors.kColorPrimary.withValues(alpha: 0.05),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(vertical: AppDimensions.sp10),
              decoration: BoxDecoration(
                border: last
                    ? null
                    : Border(bottom: BorderSide(color: _border(context))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: dark
                          ? AppColors.kDarkBgCard
                          : AppColors.kColorAccentLight.withValues(alpha: 0.14),
                      borderRadius:
                          BorderRadius.circular(AppDimensions.kRadiusLg),
                      border: Border.all(
                          color: AppColors.kColorAccentLight
                              .withValues(alpha: 0.28)),
                    ),
                    child: Icon(icon,
                        size: 18,
                        color: dark
                            ? AppColors.kColorAccentLight
                            : AppColors.kColorAccentDark),
                  ),
                  const SizedBox(width: AppDimensions.sp14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: t.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: dark
                                    ? AppColors.kDarkTextPrimary
                                    : AppColors.kColorTextBody)),
                        if (hint != null) ...[
                          const SizedBox(height: AppDimensions.sp2),
                          Text(hint!,
                              style:
                                  t.bodySmall?.copyWith(color: _muted(context))),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: AppDimensions.iconMd, color: _muted(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Footer ───────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.sp32),
      child: Column(
        children: [
          // Hairline with a heritage rosette sitting on it.
          SizedBox(
            height: 18,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(width: 70, height: 1, color: _border(context)),
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.sp8),
                  child: const Icon(Icons.brightness_7,
                      size: 13, color: AppColors.kColorAccentLight),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.sp16),
          Text(
            'Preserving Nepal’s Heritage,\nOne Journey at a Time.',
            textAlign: TextAlign.center,
            style: t.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: _secondary(context),
            ),
          ),
          const SizedBox(height: AppDimensions.sp12),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Made with '),
                TextSpan(
                  text: '♥',
                  style: TextStyle(
                      color: _isDark(context)
                          ? AppColors.kColorAccentLight
                          : AppColors.kColorDeep),
                ),
                const TextSpan(text: ' in '),
                TextSpan(
                  text: 'Nepal',
                  style: t.titleSmall?.copyWith(
                    fontSize: 15,
                    color: _isDark(context)
                        ? AppColors.kColorAccentLight
                        : AppColors.kColorAccentSafe,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic, color: _secondary(context)),
          ),
          const SizedBox(height: AppDimensions.sp10),
          Text(
            '© 2026 DEVELOPMENTAL · ALL RIGHTS RESERVED',
            textAlign: TextAlign.center,
            style: t.labelSmall?.copyWith(
                fontSize: 9.5, letterSpacing: 1.2, color: _muted(context)),
          ),
          const SizedBox(height: AppDimensions.sp4),
          Text(
            'वि.सं. २०८३',
            style: GoogleFonts.notoSerifDevanagari(
              fontSize: 12,
              color: _muted(context),
            ),
          ),
        ],
      ),
    );
  }
}
