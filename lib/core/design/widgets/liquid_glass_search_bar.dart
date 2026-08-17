import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import '../utils/glass_haptics.dart';
import 'glass_surface.dart';

/// The iOS counterpart to `AppSearchField`.
///
/// Keeps that widget's debounce contract exactly — typing must not fire a request
/// per keystroke — and adds the iOS presentation: a glass capsule tinted against
/// the page, carrying a specular bevel and a focus ring that glows in, with a
/// round Cancel button that slides in beside it while the field is in use.
class LiquidGlassSearchBar extends StatefulWidget {
  const LiquidGlassSearchBar({
    super.key,
    required this.onChanged,
    this.hint = 'Search…',
    this.initialValue,
    this.debounce = const Duration(milliseconds: 350),
    this.autofocus = false,
    this.showCancel = true,
    this.onCancel,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final String? initialValue;
  final Duration debounce;
  final bool autofocus;

  /// Whether the round Cancel button slides in beside the field while it is
  /// focused or holds a query.
  ///
  /// On by default, and deliberately not gated on [onCancel]: the button's own
  /// job — drop the query and dismiss the keyboard — needs nothing from the
  /// caller, so requiring a callback just to get iOS's standard affordance meant
  /// no screen ever had it.
  final bool showCancel;

  /// Called *after* the field has cleared itself and given up focus, for a screen
  /// that has its own search mode to leave. Optional; the button appears without
  /// it.
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
        // Focus is carried entirely by the hairline — the brand colour bleeding
        // into the rim. There is deliberately no outer glow: a coloured shadow
        // around a capsule that is supposed to read as clear glass turns it into
        // a lit object, which is the opposite of the effect.
        final spec = glass.field.copyWith(
          borderColor: Color.lerp(
            glass.field.borderColor,
            scheme.ring.withValues(alpha: 0.85),
            t,
          ),
        );

        return GlassSurface(
          spec: spec,
          radius: GlassRadius.capsule,
          // Stated here as well as in the token: a search field must never grow
          // a drop shadow, whatever the tier does later.
          showShadow: false,
          // A whisper of frost. Nothing scrolls under this field, so there is
          // nothing to refract — hence the fake renderer — but the ambient
          // backdrop is not flat, and blurring it is what stops the capsule
          // reading as a flat grey pill painted on the page.
          blur: 8,
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

    if (!widget.showCancel) return field;

    final showing = _focused || hasText;

    return Row(
      children: [
        Expanded(child: field),
        // Animating the width keeps the field's own resize smooth instead of
        // making it jump when Cancel appears.
        //
        // Deliberately not `AnimatedSize`: in a Row the main axis is unbounded,
        // where it measures itself at zero and lets the button paint outside its
        // own box — which looks correct and cannot be tapped. An explicit width
        // factor keeps the laid-out box and the visible button the same thing.
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: showing ? 1.0 : 0.0),
          duration: glass.duration(GlassDurations.base),
          curve: GlassCurves.easeOutExpo,
          builder: (context, t, child) => t == 0
              ? const SizedBox.shrink()
              : ClipRect(
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: t,
                    // Without a height factor `Align` fills the cross axis, and
                    // in a Row that means the whole viewport — the search row
                    // would grow to the height of the page on focus.
                    heightFactor: 1,
                    // No fade to go with the slide: `Opacity` composites into
                    // its own layer, and the button's backdrop filter has no
                    // backdrop to sample inside one — it would blank out for
                    // the length of the animation. The reveal is the slide.
                    child: child,
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.only(left: GlassSpacing.sm),
            child: _CancelButton(onTap: _cancel),
          ),
        ),
      ],
    );
  }
}

/// The round Cancel beside a focused search field.
///
/// A glyph in a circle rather than the word "Cancel": the label would be one more
/// string to keep clear of every `find.text` in the suite, and the reference draws
/// a glass circle here too. It borrows the field's own material so the pair reads
/// as one control split in two.
///
/// Its 38pt is load-bearing. The field's natural height is around 40, so a button
/// this size is centred by the [Row] and can never grow it — which is what keeps
/// the page's content from shifting the moment the field takes focus.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});

  final VoidCallback onTap;

  static const _size = 38.0;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final glass = context.glass;

    return GestureDetector(
      onTap: () {
        GlassHaptics.light();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        button: true,
        label: 'Cancel search',
        child: GlassSurface(
          spec: glass.field,
          radius: GlassRadius.capsule,
          blur: 8,
          showShadow: false,
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(
              Icons.close_rounded,
              size: 18,
              color: scheme.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
