import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import '../utils/glass_haptics.dart';
import 'liquid_glass_container.dart';

/// The iOS counterpart to `AppSearchField`.
///
/// Keeps that widget's debounce contract exactly — typing must not fire a request
/// per keystroke — and adds the iOS presentation: a recessed glass capsule whose
/// focus ring glows in, with the leading magnifier sliding from centre to the
/// leading edge as the field takes focus, the way the iOS search bar does.
class LiquidGlassSearchBar extends StatefulWidget {
  const LiquidGlassSearchBar({
    super.key,
    required this.onChanged,
    this.hint = 'Search…',
    this.initialValue,
    this.debounce = const Duration(milliseconds: 350),
    this.autofocus = false,
    this.onCancel,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final String? initialValue;
  final Duration debounce;
  final bool autofocus;

  /// When set, a "Cancel" action slides in beside the field while it has focus.
  final VoidCallback? onCancel;

  @override
  State<LiquidGlassSearchBar> createState() => _LiquidGlassSearchBarState();
}

class _LiquidGlassSearchBarState extends State<LiquidGlassSearchBar> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChanged);
  Timer? _timer;
  bool _focused = false;

  @override
  void dispose() {
    _timer?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus == _focused) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value.trim()));
    setState(() {}); // toggles the clear button
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    GlassHaptics.light();
    widget.onChanged('');
    setState(() {});
  }

  void _cancel() {
    _timer?.cancel();
    _controller.clear();
    _focusNode.unfocus();
    widget.onChanged('');
    widget.onCancel?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;
    final hasText = _controller.text.isNotEmpty;

    final field = TweenAnimationBuilder<double>(
      tween: Tween<double>(end: _focused ? 1.0 : 0.0),
      duration: glass.duration(GlassDurations.fast),
      curve: GlassCurves.easeOutSmooth,
      builder: (context, t, _) {
        // The focus ring is the brand colour bleeding into the hairline plus a
        // soft outer glow — light gathering at the edge of the glass.
        final spec = glass.control.copyWith(
          borderColor: Color.lerp(
            glass.control.borderColor,
            scheme.ring.withValues(alpha: 0.85),
            t,
          ),
          shadow: t == 0
              ? const []
              : [
                  BoxShadow(
                    color: scheme.ring.withValues(alpha: 0.22 * t),
                    blurRadius: 14 * t,
                    spreadRadius: 1.5 * t,
                  ),
                ],
        );

        return LiquidGlassContainer(
          spec: spec,
          radius: GlassRadius.capsule,
          showHighlight: false,
          padding: const EdgeInsets.symmetric(horizontal: GlassSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 18,
                color: Color.lerp(
                  scheme.mutedForeground,
                  scheme.foreground,
                  t,
                ),
              ),
              const SizedBox(width: GlassSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  style: theme.textTheme.bodyMedium,
                  cursorColor: scheme.primary,
                  cursorRadius: const Radius.circular(2),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.mutedForeground),
                    // The glass container draws the fill and the hairline, so the
                    // Material decoration must contribute nothing but layout.
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              // Sized rather than conditional so the field's height never
              // changes as the button appears, which would jitter the row.
              SizedBox(
                width: 22,
                height: 22,
                child: AnimatedOpacity(
                  opacity: hasText ? 1 : 0,
                  duration: glass.duration(GlassDurations.fast),
                  child: IgnorePointer(
                    ignoring: !hasText,
                    child: GestureDetector(
                      onTap: _clear,
                      behavior: HitTestBehavior.opaque,
                      child: Semantics(
                        button: true,
                        label: 'Clear search',
                        child: Icon(
                          Icons.cancel_rounded,
                          size: 18,
                          color: scheme.mutedForeground.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.onCancel == null) return field;

    return Row(
      children: [
        Expanded(child: field),
        // Animating the width keeps the field's own resize smooth instead of
        // making it jump when Cancel appears.
        AnimatedSize(
          duration: glass.duration(GlassDurations.base),
          curve: GlassCurves.easeOutExpo,
          child: _focused || hasText
              ? Padding(
                  padding: const EdgeInsets.only(left: GlassSpacing.sm),
                  child: GestureDetector(
                    onTap: _cancel,
                    child: Semantics(
                      button: true,
                      child: Text(
                        'Cancel',
                        style: theme.textTheme.labelLarge
                            ?.copyWith(color: scheme.primary),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
