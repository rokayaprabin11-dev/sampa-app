import 'package:flutter/material.dart';
import 'package:sampada/presentation/widgets/common/interactive_surface.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:sampada/providers/profile_provider.dart';
import 'package:sampada/providers/heritage_provider.dart';
import 'package:sampada/data/models/heritage_site_model.dart';
import 'package:sampada/data/models/site_image_model.dart';

class HeritageSiteScreen extends StatefulWidget {
  const HeritageSiteScreen({super.key});

  @override
  State<HeritageSiteScreen> createState() => _HeritageSiteScreenState();
}

class _HeritageSiteScreenState extends State<HeritageSiteScreen> {
  HeritageSiteModel? _site;
  bool _isInit = false;
  bool _loadingDetail = false;
  int _carouselIndex = 0;
  bool _descExpanded = false;
  final PageController _pageController = PageController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is HeritageSiteModel) {
        _site = args;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.read<ProfileProvider>().addToVisitHistory(_site!.id);
          _fetchFullDetail();
        });
      } else if (args is Map && args['slug'] != null) {
        // Opened from a notification deep-link (only a slug is known).
        final slug = args['slug'].toString();
        WidgetsBinding.instance.addPostFrameCallback((_) => _loadBySlug(slug));
      }
      _isInit = true;
    }
  }

  Future<void> _loadBySlug(String slug) async {
    if (slug.isEmpty) return;
    setState(() => _loadingDetail = true);
    final full = await context.read<HeritageProvider>().fetchSiteDetail(slug);
    if (!mounted) return;
    if (full is HeritageSiteModel) {
      setState(() {
        _site = full;
        _loadingDetail = false;
      });
      context.read<ProfileProvider>().addToVisitHistory(full.id);
    } else {
      setState(() => _loadingDetail = false);
    }
  }

  Future<void> _fetchFullDetail() async {
    if (_site == null || _site!.slug.isEmpty) return;
    debugPrint(
        'DBG _fetchFullDetail: slug=${_site!.slug} gallery_before=${_site!.gallery.length}');
    final hasDescription = _site!.description.isNotEmpty;
    if (!hasDescription) setState(() => _loadingDetail = true);
    final full =
        await context.read<HeritageProvider>().fetchSiteDetail(_site!.slug);
    debugPrint(
        'DBG _fetchFullDetail: full=$full gallery_after=${full is HeritageSiteModel ? full.gallery.length : "null"}');
    if (full is HeritageSiteModel) {
      for (final g in full.gallery) {
        debugPrint(
            '  gallery item id=${g.imageUrl.substring(g.imageUrl.length - 20)} name="${g.name}"');
      }
    }
    if (mounted && full is HeritageSiteModel) {
      setState(() {
        _site = full;
        _loadingDetail = false;
      });
    } else {
      if (mounted) setState(() => _loadingDetail = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Hero carousel: cover image + gallery items with no title (main site photos)
  List<String> get _carouselImages {
    final list = <String>[];
    if (_site!.imageUrl?.isNotEmpty == true) list.add(_site!.imageUrl!);
    for (final g in _site!.gallery) {
      if (g.name.isEmpty &&
          g.imageUrl.isNotEmpty &&
          !list.contains(g.imageUrl)) {
        list.add(g.imageUrl);
      }
    }
    return list;
  }

  // Gallery row: only sub-heritage items (those with a name/title)
  List<SiteImageModel> get _galleryItems =>
      _site!.gallery.where((g) => g.name.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_site == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: _loadingDetail
              ? const CircularProgressIndicator(
                  color: Color(0xFFD4A017), strokeWidth: 2)
              : Text(AppLocalizations.of(context)!.siteNotFound,
                  style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final top = MediaQuery.of(context).padding.top;
    final provider = context.watch<ProfileProvider>();
    final images = _carouselImages;
    final gallery = _galleryItems;
    final cs = Theme.of(context).colorScheme;
    final isDark = cs.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      // The hero and the card are positioned as fractions of the *full* screen
      // height, but the body shrinks when a keyboard opens (e.g. a dialog
      // pushed over this route), which squeezed the card to a fraction of its
      // intended height and overflowed it. Nothing in this body takes text
      // input, so it has no reason to resize for the keyboard.
      resizeToAvoidBottomInset: false,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // ── Hero 48% ──────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height * 0.48,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (images.isEmpty)
                    _placeholder()
                  else if (images.length == 1)
                    _netImg(images[0])
                  else
                    PageView.builder(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _carouselIndex = i),
                      itemCount: images.length,
                      itemBuilder: (_, i) => _netImg(images[i]),
                    ),
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Card at 45% ───────────────────────────────────────────────
            Positioned(
              top: size.height * 0.45,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDimensions.kRadiusXxl)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // fixed header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _site!
                                .localizedName(Localizations.localeOf(context)
                                        .languageCode ==
                                    'ne')
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_site!.isUnesco) ...[
                            _unescoTag(cs, isDark, l10n.unescoHeritage),
                            const SizedBox(height: 8),
                          ],
                          Row(children: [
                            Icon(Icons.location_on,
                                color: cs.onSurface, size: 15),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(
                              _site!.location,
                              style:
                                  TextStyle(color: cs.onSurface, fontSize: 13),
                            )),
                          ]),
                          const SizedBox(height: 12),
                          Divider(color: cs.outline, thickness: 1.5),
                        ],
                      ),
                    ),

                    // scrollable: About + Gallery
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.sectionAboutSite,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface)),
                            const SizedBox(height: 8),
                            if (_loadingDetail)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                    child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color:
                                                AppColors.kColorPrimaryMid))),
                              )
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final bodyColor =
                                      cs.onSurface.withValues(alpha: 0.75);
                                  final style = TextStyle(
                                      color: bodyColor,
                                      fontSize: 14,
                                      height: 1.65);
                                  final np = Localizations.localeOf(context)
                                          .languageCode ==
                                      'ne';
                                  final localizedDesc =
                                      _site!.localizedDescription(np);
                                  final desc = localizedDesc.isNotEmpty
                                      ? localizedDesc
                                      : 'No description available.';
                                  final tp = TextPainter(
                                    text: TextSpan(text: desc, style: style),
                                    maxLines: 10,
                                    textDirection: TextDirection.ltr,
                                  )..layout(maxWidth: constraints.maxWidth);
                                  final exceeds = tp.didExceedMaxLines;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        desc,
                                        maxLines: _descExpanded ? null : 10,
                                        overflow: _descExpanded
                                            ? TextOverflow.visible
                                            : TextOverflow.ellipsis,
                                        style: style,
                                      ),
                                      if (exceeds)
                                        InteractiveSurface(
                                          onTap: () => setState(() =>
                                              _descExpanded = !_descExpanded),
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(
                                              _descExpanded
                                                  ? l10n.btnShowLess
                                                  : l10n.btnLearnMore,
                                              style: const TextStyle(
                                                  color:
                                                      AppColors.kColorPrimary,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            const SizedBox(height: 18),
                            Text(l10n.sectionGallery,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onSurface)),
                            const SizedBox(height: 10),
                            if (gallery.isEmpty)
                              Row(children: [
                                Icon(Icons.photo_library_outlined,
                                    size: 18,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.35)),
                                const SizedBox(width: 8),
                                Text(l10n.noSubHeritage,
                                    style: TextStyle(
                                        color: cs.onSurface
                                            .withValues(alpha: 0.55),
                                        fontSize: 13)),
                              ])
                            else
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: gallery.length,
                                  itemBuilder: (_, i) {
                                    final img = gallery[i];
                                    return InteractiveSurface(
                                      onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => _SubHeritageScreen(
                                                image: img,
                                                siteName: _site!.name),
                                          )),
                                      child: Container(
                                        width: 95,
                                        margin:
                                            const EdgeInsets.only(right: 10),
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                              AppDimensions.kRadiusXl),
                                          color: isDark
                                              ? AppColors.darkBgCard
                                              : const Color(0xFFEEE4D8),
                                        ),
                                        child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              AppNetworkImage(
                                                  url: img.imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorWidget: Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      color: cs.onSurface
                                                          .withValues(
                                                              alpha: 0.4))),
                                              Positioned(
                                                bottom: 0,
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 5,
                                                      vertical: 3),
                                                  color: Colors.black
                                                      .withValues(alpha: 0.55),
                                                  child: Text(
                                                      img.name.isNotEmpty
                                                          ? img.name
                                                          : img.caption,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 9)),
                                                ),
                                              ),
                                            ]),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // fixed footer
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        border: Border(top: BorderSide(color: cs.outline)),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Center(
                              child: SizedBox(
                                width: 240,
                                child: _actionBtn(
                                    Icons.map_outlined, l10n.btnViewOnMap, cs,
                                    () {
                                  Navigator.pushNamed(
                                      context, AppStrings.mapPath,
                                      arguments: _site);
                                }),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green.shade700, size: 14),
                              const SizedBox(width: 5),
                              Text(l10n.labelAvailableOffline,
                                  style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            ]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Carousel dots (above card, below back button) ─────────────
            if (images.length > 1)
              Positioned(
                top: size.height * 0.45 - 24,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                      images.length,
                      (i) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _carouselIndex == i
                                  ? AppColors.goldMain
                                  : Colors.white.withValues(alpha: 0.5),
                            ),
                          )),
                ),
              ),

            // ── Back + Bookmark overlay ────────────────────────────────────
            Positioned(
              top: top + 8,
              left: 12,
              child: _circleBtn(Icons.arrow_back, () => Navigator.pop(context)),
            ),
            Positioned(
              top: top + 8,
              right: 12,
              child: FutureBuilder<bool>(
                future: provider.isBookmarked(_site!.id),
                builder: (_, snap) {
                  final bm = snap.data ?? false;
                  return _circleBtn(
                    bm ? Icons.bookmark : Icons.bookmark_border,
                    () => provider.toggleBookmark(_site!.id),
                    color: bm ? AppColors.goldMain : Colors.white,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _netImg(String url) => AppNetworkImage(
        url: url,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorWidget: _placeholder(),
      );

  Widget _placeholder() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.kColorDeepShade, AppColors.kColorDeep],
          ),
        ),
        child: Center(
            child: Icon(
          _categoryIcon(_site?.category ?? ''),
          size: 110,
          color: const Color(0xFFD4A017).withValues(alpha: 0.35),
        )),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap,
          {Color color = Colors.white}) =>
      Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: Colors.white.withValues(alpha: 0.25),
          highlightColor: Colors.white.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      );

  Widget _unescoTag(ColorScheme cs, bool isDark, String unescoLabel) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgCard : AppColors.goldSurface,
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(color: cs.outline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events,
              color: AppColors.kColorPrimary, size: 13),
          const SizedBox(width: 5),
          Text(unescoLabel,
              style: const TextStyle(
                  color: AppColors.goldDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 11)),
        ]),
      );

  Widget _actionBtn(
          IconData icon, String label, ColorScheme cs, VoidCallback onTap) =>
      InteractiveSurface(
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
            border: Border.all(color: cs.outline),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: cs.onSurface, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
        ),
      );

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'temple':
        return Icons.temple_hindu;
      case 'stupa':
        return Icons.temple_buddhist;
      case 'palace':
        return Icons.castle;
      default:
        return Icons.account_balance;
    }
  }
}

// ─── Sub-Heritage Screen ──────────────────────────────────────────────────────

class _SubHeritageScreen extends StatelessWidget {
  final SiteImageModel image;
  final String siteName;
  const _SubHeritageScreen({required this.image, required this.siteName});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final top = MediaQuery.of(context).padding.top;
    final title = image.name.isNotEmpty
        ? image.name
        : (image.caption.isNotEmpty ? image.caption : siteName);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.kColorDeep,
      body: Column(
        children: [
          SizedBox(
            height: size.height * 0.45,
            child: Stack(fit: StackFit.expand, children: [
              AppNetworkImage(
                url: image.imageUrl,
                fit: BoxFit.cover,
                errorWidget: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.kColorDeepShade,
                          AppColors.kColorDeep
                        ]),
                  ),
                  child: const Center(
                      child: Icon(Icons.image_not_supported,
                          size: 72, color: Colors.white30)),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.2)
                    ],
                  ),
                ),
              ),
              Positioned(
                top: top + 8,
                left: 12,
                child: InteractiveSurface(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ]),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppDimensions.kRadiusXxl)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.toUpperCase(),
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: cs.onSurface,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 12),
                      Divider(color: cs.outline, thickness: 1.5),
                      const SizedBox(height: 12),
                      Text(l10n.sectionAboutSite,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface)),
                      const SizedBox(height: 8),
                      Text(
                        image.description.isNotEmpty
                            ? image.description
                            : (image.caption.isNotEmpty
                                ? image.caption
                                : 'No description available.'),
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.75),
                            fontSize: 14,
                            height: 1.65),
                      ),
                    ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
