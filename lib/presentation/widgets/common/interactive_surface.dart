import 'package:flutter/material.dart';

/// A consistent Material interaction treatment for custom cards, tiles and
/// image surfaces. It deliberately only owns visual state: callers keep their
/// existing callbacks, navigation and state management.
class InteractiveSurface extends StatefulWidget {
  const InteractiveSurface({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.enabled = true,
    this.behavior = HitTestBehavior.deferToChild,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadius borderRadius;
  final bool enabled;

  /// Retained for easy migration from [GestureDetector]. InkWell provides the
  /// actual hit testing so custom tap surfaces gain Material feedback.
  final HitTestBehavior behavior;
  final String? semanticLabel;

  @override
  State<InteractiveSurface> createState() => _InteractiveSurfaceState();
}

class _InteractiveSurfaceState extends State<InteractiveSurface> {
  static const _duration = Duration(milliseconds: 220);
  bool _hovered = false;
  bool _pressed = false;

  bool get _interactive =>
      widget.enabled && (widget.onTap != null || widget.onLongPress != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _hovered || _pressed;
    return Semantics(
      button: _interactive,
      label: widget.semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _interactive ? widget.onTap : null,
          onLongPress: _interactive ? widget.onLongPress : null,
          onHover: (value) => setState(() => _hovered = value),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          borderRadius: widget.borderRadius,
          mouseCursor: _interactive
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              Positioned.fill(
                // This tint is visual only. Keeping it out of hit testing
                // lets nested buttons, chips and menus keep their actions.
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: _duration,
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: active
                          ? theme.colorScheme.primary.withValues(alpha: 0.05)
                          : Colors.transparent,
                      borderRadius: widget.borderRadius,
                    ),
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
