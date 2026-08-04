import 'package:flutter/material.dart';

import '../../config/theme/app_theme.dart';
import '../../design/extensions/glass_context.dart';
import '../../design/widgets/liquid_glass_bottom_sheet.dart';
import '../../design/widgets/liquid_glass_dialog.dart';

/// Port of the React `ConfirmDialog` — the destructive-action confirmation used
/// before deletes, submissions, and disqualifications.
///
/// Returns `true` when confirmed, `false`/`null` otherwise.
///
/// On iOS this hands off to [showLiquidGlassConfirm], which presents the same
/// decision as a glass alert over a blurred backdrop. The signature and return
/// semantics are identical either way, so no call site changes.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  if (context.useGlass) {
    return showLiquidGlassConfirm(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    );
  }

  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = context.scheme;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.destructive,
                    foregroundColor: Colors.white,
                  )
                : null,
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Mobile stand-in for the React `CustomDialog` shell that every create/edit
/// form is mounted in. On a phone a bottom sheet reads better than a centred
/// modal, and it keeps the keyboard from covering the form.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  String? subtitle,
  bool isScrollControlled = true,
}) {
  if (context.useGlass) {
    return showLiquidGlassSheet<T>(
      context,
      title: title,
      subtitle: subtitle,
      builder: builder,
      isScrollControlled: isScrollControlled,
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        // Lift the sheet above the keyboard.
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Builder(builder: builder),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A sheet whose body is a plain list of options — the mobile form of the
/// filter dropdowns and role pickers.
Future<T?> showAppOptionSheet<T>(
  BuildContext context, {
  required String title,
  required List<AppSheetOption<T>> options,
  T? selected,
}) {
  if (context.useGlass) {
    return showLiquidGlassOptionSheet<T>(
      context,
      title: title,
      selected: selected,
      options: [
        for (final option in options)
          LiquidGlassSheetOption<T>(
            value: option.value,
            label: option.label,
            description: option.description,
            icon: option.icon,
          ),
      ],
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      final scheme = context.scheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(title, style: theme.textTheme.titleMedium),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                children: [
                  for (final option in options)
                    ListTile(
                      leading: option.icon == null ? null : Icon(option.icon),
                      title: Text(option.label, style: theme.textTheme.bodyMedium),
                      subtitle: option.description == null
                          ? null
                          : Text(option.description!, style: theme.textTheme.bodySmall),
                      trailing: option.value == selected
                          ? Icon(Icons.check_rounded, size: 18, color: scheme.primary)
                          : null,
                      onTap: () => Navigator.of(context).pop(option.value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class AppSheetOption<T> {
  const AppSheetOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
}
