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
  Widget? leading,
  Widget? trailing,
}) {
  if (context.useGlass) {
    return showLiquidGlassSheet<T>(
      context,
      title: title,
      subtitle: subtitle,
      builder: builder,
      isScrollControlled: isScrollControlled,
      leading: leading,
      trailing: trailing,
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    builder: (context) {
      final theme = Theme.of(context);
      final hasActions = leading != null || trailing != null;
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
              if (hasActions)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      // Both ends are held even when only one action was given,
                      // so the title sits in the middle either way.
                      SizedBox(width: 96, child: leading),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle,
                                style: theme.textTheme.bodySmall,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: trailing,
                        ),
                      ),
                    ],
                  ),
                )
              else
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

/// A text action for a sheet's header — the `Cancel` / `Apply` pair that sits on
/// either side of the title.
///
/// Build it under a [Builder] so its `onPressed` can pop the sheet's own route:
/// the sheet is pushed on the root navigator, so a callback closing over the
/// *calling* screen's context would pop that screen instead.
class AppSheetAction extends StatelessWidget {
  const AppSheetAction({
    super.key,
    required this.label,
    this.onPressed,
    this.prominent = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// The confirming action of the pair — emphasised, as `Done` is on iOS.
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    if (context.useGlass) {
      return LiquidGlassSheetAction(
        label: label,
        onPressed: onPressed,
        prominent: prominent,
      );
    }

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: TextStyle(
          fontSize: 15,
          fontWeight: prominent ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      child: Text(label),
    );
  }
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
            destructive: option.destructive,
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
                      leading: option.icon == null
                          ? null
                          : Icon(
                              option.icon,
                              color: option.destructive ? scheme.destructive : null,
                            ),
                      title: Text(
                        option.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: option.destructive ? scheme.destructive : null,
                        ),
                      ),
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
    this.destructive = false,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;

  /// Renders the row in the destructive colour — a delete in an action list.
  final bool destructive;
}
