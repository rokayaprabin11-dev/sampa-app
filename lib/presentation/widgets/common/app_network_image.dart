import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// App-wide network image with on-disk caching.
///
/// Wraps [CachedNetworkImage] so every remote image (Cloudinary covers, event
/// galleries, avatars) is persisted to disk and reused across rebuilds and app
/// restarts instead of being re-downloaded like raw `Image.network`. Provides a
/// shimmer placeholder while loading and a neutral fallback on error.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorWidget,
    this.borderRadius,
    this.cloudinaryWidth,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Target render width in px for Cloudinary delivery. When the URL is a
  /// Cloudinary asset, requests `w_<n>` so a 72px thumbnail doesn't download a
  /// 2000px original. Defaults from [width] when not given.
  final double? cloudinaryWidth;

  /// Optional custom fallback shown when the URL is empty or fails to load.
  final Widget? errorWidget;

  /// When set, clips the image (and its placeholder/fallback) to these radii.
  final BorderRadius? borderRadius;

  Widget _fallback(BuildContext context) {
    if (errorWidget != null) return errorWidget!;
    return Container(
      width: width,
      height: height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: base.withValues(alpha: 0.5),
      child: Container(width: width, height: height, color: base),
    );
  }

  /// Inject `f_auto,q_auto[,w_<n>]` into a Cloudinary delivery URL so the CDN
  /// serves a modern format at the right size. Non-Cloudinary URLs pass through
  /// untouched. Idempotent — skips URLs that already carry a transform.
  String _optimized(String raw, double devicePixelRatio) {
    const marker = '/image/upload/';
    final i = raw.indexOf(marker);
    if (i == -1) return raw; // not a Cloudinary delivery URL
    final after = i + marker.length;
    final rest = raw.substring(after);
    // Already transformed (next segment contains transform tokens)?
    if (rest.startsWith('f_') || rest.startsWith('q_') || rest.startsWith('w_')) {
      return raw;
    }
    final w = cloudinaryWidth ?? width;
    final parts = ['f_auto', 'q_auto'];
    if (w != null && w > 0) {
      parts.add('w_${(w * devicePixelRatio).round()}');
    }
    return '${raw.substring(0, after)}${parts.join(',')}/$rest';
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (url == null || url!.trim().isEmpty) {
      child = _fallback(context);
    } else {
      final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
      child = CachedNetworkImage(
        imageUrl: _optimized(url!, dpr),
        fit: fit,
        width: width,
        height: height,
        placeholder: (context, _) => _placeholder(context),
        errorWidget: (context, _, __) => _fallback(context),
      );
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}
