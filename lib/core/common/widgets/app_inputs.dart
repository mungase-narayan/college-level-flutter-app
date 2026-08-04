import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../../design/extensions/glass_context.dart';
import '../../design/theme/glass_specs.dart';
import '../../design/widgets/liquid_glass_container.dart';
import '../../design/widgets/liquid_glass_input.dart';
import '../../design/widgets/liquid_glass_search_bar.dart';
import 'app_dialogs.dart';

/// Labelled text field matching the React `AppInput` / shadcn `Input`.
class AppInput extends StatelessWidget {
  const AppInput({
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
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    if (context.useGlass) {
      return LiquidGlassInput(
        controller: controller,
        label: label,
        hint: hint,
        errorText: errorText,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        prefixIcon: prefixIcon,
        suffix: suffix,
        maxLines: maxLines,
        minLines: minLines,
        enabled: enabled,
        autofillHints: autofillHints,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        validator: validator,
        focusNode: focusNode,
      );
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: theme.textTheme.labelMedium),
          const SizedBox(height: 7),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLines: obscureText ? 1 : maxLines,
          minLines: minLines,
          enabled: enabled,
          autofillHints: autofillHints,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18),
            suffixIcon: suffix,
            errorMaxLines: 3,
          ),
        ),
      ],
    );
  }
}

/// Password field with a show/hide toggle.
class AppPasswordInput extends StatefulWidget {
  const AppPasswordInput({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  State<AppPasswordInput> createState() => _AppPasswordInputState();
}

class _AppPasswordInputState extends State<AppPasswordInput> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return AppInput(
      controller: widget.controller,
      label: widget.label,
      hint: widget.hint,
      obscureText: _obscured,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      validator: widget.validator,
      autofillHints: widget.autofillHints,
      suffix: IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          size: 18,
        ),
        tooltip: _obscured ? 'Show password' : 'Hide password',
      ),
    );
  }
}

/// Port of the React `SearchInput` — debounced so typing doesn't fire a request
/// per keystroke.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search…',
    this.initialValue,
    this.debounce = const Duration(milliseconds: 350),
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final String? initialValue;
  final Duration debounce;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    _timer = Timer(widget.debounce, () => widget.onChanged(value.trim()));
    setState(() {}); // toggles the clear button
  }

  void _clear() {
    _timer?.cancel();
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Branching here rather than in `AppSearchField` because a StatefulWidget
    // cannot swap itself out before `createState`. The glass bar owns its own
    // controller and debounce timer; this state's `late final` fields are never
    // touched on that path.
    if (context.useGlass) {
      return LiquidGlassSearchBar(
        onChanged: widget.onChanged,
        hint: widget.hint,
        initialValue: widget.initialValue,
        debounce: widget.debounce,
      );
    }

    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: _clear,
                icon: const Icon(Icons.close_rounded, size: 16),
                tooltip: 'Clear',
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

/// Compact labelled dropdown, the mobile stand-in for the shadcn `Select` used
/// in every filter bar.
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
    this.isExpanded = true,
  });

  final T? value;
  final List<AppSelectItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final String? hint;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (context.useGlass) {
      return _GlassSelect<T>(
        value: value,
        items: items,
        onChanged: onChanged,
        label: label,
        hint: hint,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: theme.textTheme.labelMedium),
          const SizedBox(height: 7),
        ],
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: isExpanded,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          style: theme.textTheme.bodyMedium,
          hint: hint == null ? null : Text(hint!, style: theme.textTheme.bodyMedium),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item.value, child: Text(item.label)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class AppSelectItem<T> {
  const AppSelectItem({required this.value, required this.label});

  final T? value;
  final String label;
}

/// The iOS form of [AppSelect].
///
/// A dropdown menu anchored to a field is a Material pattern; iOS presents the
/// same choice as a picker sheet. Reusing [showAppOptionSheet] means the glass
/// sheet, its dismissal behaviour and its selected-row checkmark all come for
/// free — and stay consistent with every other picker in the app.
class _GlassSelect<T> extends StatelessWidget {
  const _GlassSelect({
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
  });

  final T? value;
  final List<AppSelectItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final glass = context.glass;
    final label = this.label;

    final selected = items.where((item) => item.value == value).firstOrNull;
    final display = selected?.label ?? hint ?? 'Select…';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 7),
        ],
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final picked = await showAppOptionSheet<T>(
              context,
              title: label ?? hint ?? 'Select',
              selected: value,
              options: [
                for (final item in items)
                  if (item.value case final itemValue?)
                    AppSheetOption<T>(value: itemValue, label: item.label),
              ],
            );
            // A dismissed sheet returns null, which must not be mistaken for the
            // user choosing to clear the field.
            if (picked != null) onChanged(picked);
          },
          child: LiquidGlassContainer(
            spec: glass.control,
            radius: GlassRadius.md,
            showHighlight: false,
            padding: const EdgeInsets.symmetric(
              horizontal: GlassSpacing.lg - 2,
              vertical: 14,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    display,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected == null
                          ? scheme.mutedForeground
                          : scheme.foreground,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: scheme.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
