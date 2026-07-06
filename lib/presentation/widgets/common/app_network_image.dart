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
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;

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

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (url == null || url!.trim().isEmpty) {
      child = _fallback(context);
    } else {
      child = CachedNetworkImage(
        imageUrl: url!,
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
