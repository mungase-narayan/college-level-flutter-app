import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme/app_theme.dart';
import '../animations/glass_curves.dart';
import '../extensions/glass_context.dart';
import '../theme/glass_specs.dart';
import 'liquid_glass_container.dart';

/// The iOS counterpart to `AppInput`.
///
/// Mirrors that widget's API exactly, so the adaptive branch in `app_inputs.dart`
/// is a straight hand-off and no form has to change.
///
/// The glass container owns the fill and the hairline; the [TextFormField] inside
/// is stripped of its Material decoration and contributes only text layout,
/// validation and the error line. Focus is expressed the iOS way — the hairline
/// takes the brand colour and a soft glow gathers at the edge — rather than by
/// thickening a border.
class LiquidGlassInput extends StatefulWidget {
  const LiquidGlassInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.minLines,
    this.enabled = true,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.focusNode,
    this.inputFormatters,
    this.dense = false,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final int? minLines;
  final bool enabled;

  /// Shrinks a single-line field to [AppTheme.controlHeightSm] so it lines up
  /// with a small button in a filter bar. Ignored when multiline.
  final bool dense;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<LiquidGlassInput> createState() => _LiquidGlassInputState();
}

class _LiquidGlassInputState extends State<LiquidGlassInput> {
  FocusNode? _internalNode;
  bool _focused = false;

  /// The caller's node when given, otherwise one owned here — and only the owned
  /// one is disposed, since disposing a caller's node would break their form.
  FocusNode get _node =>
      widget.focusNode ?? (_internalNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _node.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(LiquidGlassInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      _node.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _node.removeListener(_onFocusChanged);
    _internalNode?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted || _node.hasFocus == _focused) return;
    setState(() => _focused = _node.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;

    final label = widget.label;
    final errorText = widget.errorText;
    final hasError = errorText != null;
    final multiline = widget.maxLines > 1 && !widget.obscureText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 7),
        ],
        TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _focused ? 1.0 : 0.0),
          duration: glass.duration(GlassDurations.fast),
          curve: GlassCurves.easeOutSmooth,
          builder: (context, t, _) {
            // An error state outranks focus: the field must read as wrong even
            // while the user is in it fixing the problem.
            final accent = hasError ? scheme.destructive : scheme.ring;
            final spec = glass.control.copyWith(
              borderColor: hasError
                  ? accent.withValues(alpha: 0.8)
                  : Color.lerp(
                      glass.control.borderColor,
                      accent.withValues(alpha: 0.85),
                      t,
                    ),
              shadow: t == 0 && !hasError
                  ? const []
                  : [
                      BoxShadow(
                        color: accent.withValues(
                          alpha: 0.20 * (hasError ? 1.0 : t),
                        ),
                        blurRadius: 14 * (hasError ? 1.0 : t),
                        spreadRadius: 1.5 * (hasError ? 1.0 : t),
                      ),
                    ],
            );

            return LiquidGlassContainer(
              spec: spec,
              radius: GlassRadius.md,
              showHighlight: false,
              padding: const EdgeInsets.symmetric(
                horizontal: GlassSpacing.lg - 2,
              ),
              child: Row(
                // A multiline field grows downward, so its icons must stay at the
                // first line rather than drifting to the vertical centre.
                crossAxisAlignment: multiline
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  if (widget.prefixIcon != null) ...[
                    Padding(
                      padding: EdgeInsets.only(top: multiline ? 14 : 0),
                      child: Icon(
                        widget.prefixIcon,
                        size: 18,
                        color: scheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: GlassSpacing.sm + 2),
                  ],
                  Expanded(
                    child: TextFormField(
                      controller: widget.controller,
                      focusNode: _node,
                      obscureText: widget.obscureText,
                      keyboardType: widget.keyboardType,
                      textInputAction: widget.textInputAction,
                      maxLines: widget.obscureText ? 1 : widget.maxLines,
                      minLines: widget.minLines,
                      enabled: widget.enabled,
                      autofillHints: widget.autofillHints,
                      onChanged: widget.onChanged,
                      onFieldSubmitted: widget.onSubmitted,
                      validator: widget.validator,
                      inputFormatters: widget.inputFormatters,
                      style: theme.textTheme.bodyMedium,
                      cursorColor: scheme.primary,
                      cursorRadius: const Radius.circular(2),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: theme.textTheme.bodyMedium
                            ?.copyWith(color: scheme.mutedForeground),
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        // The error is rendered below the capsule instead, so the
                        // glass surface keeps a constant height as it appears.
                        errorStyle: const TextStyle(height: 0, fontSize: 0),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: widget.dense && !multiline ? 8 : 14,
                        ),
                      ),
                    ),
                  ),
                  if (widget.suffix != null) ...[
                    const SizedBox(width: GlassSpacing.xs),
                    widget.suffix!,
                  ],
                ],
              ),
            );
          },
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: GlassSpacing.xs),
            child: Text(
              errorText,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.destructive),
              maxLines: 3,
            ),
          ),
        ],
      ],
    );
  }
}
