import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../config/theme/app_theme.dart';
import '../../design/extensions/glass_context.dart';
import '../../error/failures.dart';
import 'app_card.dart';

/// Centred spinner — the default "still loading" surface.
class AppLoader extends StatelessWidget {
  const AppLoader({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Material's sweeping arc is unmistakably Android; iOS uses the
          // spoked activity indicator, and a Material spinner on an iPhone is one
          // of the loudest tells that an app was not built for the platform.
          SizedBox(
            width: 28,
            height: 28,
            child: context.useGlass
                ? const CupertinoActivityIndicator(radius: 12)
                : const CircularProgressIndicator(strokeWidth: 2.5),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(message!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// Port of the React `TableEmptyState` — a title, a description, and an
/// optional call to action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? description;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.muted,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              ),
              child: Icon(icon, size: 26, color: scheme.mutedForeground),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleSmall, textAlign: TextAlign.center),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// Renders a [Failure] with a retry affordance.
///
/// [ValidationFailure] is expanded into its per-field lines, matching the
/// `• field: message` formatting of the React error toast.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final message = failure is ValidationFailure
        ? (failure as ValidationFailure).detailedMessage
        : failure.message;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failure is NetworkFailure ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
              size: 34,
              color: scheme.destructive,
            ),
            const SizedBox(height: 14),
            Text(message, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmering placeholder block — the building block of every skeleton.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AppTheme.radiusSm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Shimmer.fromColors(
      baseColor: scheme.muted,
      highlightColor: Color.alphaBlend(
        scheme.foreground.withValues(alpha: 0.06),
        scheme.muted,
      ),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: scheme.muted,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Port of the React `TableSkeleton` (`rows` × card placeholders), re-flowed as
/// a stack of cards for mobile.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.rows = 5, this.lines = 2});

  final int rows;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        rows,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i == rows - 1 ? 0 : 12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton(width: 140, height: 16),
                for (var line = 0; line < lines; line++) ...[
                  const SizedBox(height: 10),
                  AppSkeleton(width: line.isEven ? double.infinity : 200),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
