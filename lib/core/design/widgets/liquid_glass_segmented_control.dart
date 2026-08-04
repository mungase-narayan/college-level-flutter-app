import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import '../utils/glass_haptics.dart';
import 'liquid_glass_container.dart';

/// One segment of a [LiquidGlassSegmentedControl].
class GlassSegment<T> {
  const GlassSegment({required this.value, required this.label, this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// An iOS segmented control: a recessed glass trough with a raised glass thumb
/// that slides between segments.
///
/// The thumb is positioned with a [LayoutBuilder]-derived offset rather than an
/// [AnimatedAlign] because the segments are equal-width and the thumb must land
/// exactly on their boundaries — alignment-based positioning drifts by a
/// half-pixel at fractional widths, which is visible against the hairline.
class LiquidGlassSegmentedControl<T> extends StatelessWidget {
  const LiquidGlassSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.height = 36,
  });

  final List<GlassSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final double height;

  static const _troughPadding = 3.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;

    if (segments.isEmpty) return const SizedBox.shrink();

    var index = segments.indexWhere((segment) => segment.value == value);
    // An unmatched value would otherwise place the thumb off-screen at -1.
    if (index < 0) index = 0;

    return LiquidGlassContainer(
      // The trough is recessed, so it gets no highlight of its own — the raised
      // thumb inside it is what catches the light.
      spec: glass.control,
      showHighlight: false,
      showShadow: false,
      radius: GlassRadius.capsule,
      padding: const EdgeInsets.all(_troughPadding),
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / segments.length;

            return Stack(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: index.toDouble()),
                  duration: glass.duration(GlassDurations.base),
                  curve: GlassCurves.spring,
                  builder: (context, position, _) => Positioned(
                    left: position * segmentWidth,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
                    child: LiquidGlassContainer(
                      spec: glass.card.copyWith(
                        tint: glass.pillTint,
                        borderColor: glass.pillBorder,
                      ),
                      radius: GlassRadius.capsule,
                      // A real shadow here is what makes the thumb read as
                      // sitting *on* the trough rather than inside it.
                      showShadow: true,
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final (i, segment) in segments.indexed)
                      Expanded(
                        child: Semantics(
                          selected: i == index,
                          button: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (segment.value == value) return;
                              GlassHaptics.selection();
                              onChanged(segment.value);
                            },
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: glass.duration(GlassDurations.fast),
                                style: (theme.textTheme.labelMedium ??
                                        const TextStyle())
                                    .copyWith(
                                  color: i == index
                                      ? scheme.foreground
                                      : scheme.mutedForeground,
                                  fontWeight: i == index
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (segment.icon != null) ...[
                                      Icon(
                                        segment.icon,
                                        size: 15,
                                        color: i == index
                                            ? scheme.foreground
                                            : scheme.mutedForeground,
                                      ),
                                      const SizedBox(width: GlassSpacing.xs + 2),
                                    ],
                                    Flexible(
                                      child: Text(
                                        segment.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
