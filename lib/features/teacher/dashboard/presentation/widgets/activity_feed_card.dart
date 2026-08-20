import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/notifications/domain/entities/app_notification.dart';
import '../../../../shared/notifications/presentation/bloc/notifications_cubit.dart';

/// Port of `src/pages/teacher/dashboard/components/activity-feed.tsx`.
///
/// The one panel on the dashboard with its own request, so it owns its own
/// loading, empty, and error states — a notification failure must leave the
/// rest of the dashboard standing.
class ActivityFeedCard extends StatelessWidget {
  const ActivityFeedCard({super.key});

  /// The web card shows the first six rows of page one.
  static const maxItems = 6;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: 'Recent Activity',
      subtitle: 'Your latest notifications',
      icon: Icons.notifications_none_rounded,
      child: BlocBuilder<NotificationsCubit, RemoteState<NotificationFeed>>(
        builder: (context, state) {
          if (state.isInitialLoading) {
            return const AppListSkeleton(rows: 3, lines: 2);
          }

          final failure = state.failure;
          if (failure != null && !state.hasData) {
            // Compact and inline: the dashboard around it is fine, so this must
            // not take over the screen the way a full AppErrorView would.
            return _FeedError(
              onRetry: () => context.read<NotificationsCubit>().load(),
            );
          }

          final items = state.data?.items ?? const <AppNotification>[];
          if (items.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: AppEmptyState(
                title: 'No activity yet',
                description:
                    'Recent updates across your courses will show up here.',
              ),
            );
          }

          final visible = items.take(maxItems).toList(growable: false);
          return Column(
            children: [
              for (var i = 0; i < visible.length; i++)
                StaggeredEntrance(
                  index: i,
                  child: _ActivityRow(notification: visible[i]),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 18, color: scheme.mutedForeground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Couldn't load recent activity.",
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.mutedForeground),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final meta = NotificationMeta.of(notification.type);
    final tone = context.tokens.tone(meta.shade);
    final isUnread = !notification.isRead;

    return Material(
      color: isUnread
          ? scheme.primary.withValues(alpha: 0.05)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: tone.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(meta.icon, size: 17, color: tone.foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (notification.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        notification.description,
                        style: theme.textTheme.labelSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      Fmt.relative(notification.createdAt),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.mutedForeground),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, left: 6),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    if (!notification.isRead) {
      context.read<NotificationsCubit>().markRead(notification.id);
    }
    // The server sends web paths; a few notification types have no destination
    // at all, in which case marking it read is the whole interaction.
    final target = notification.redirectUrl;
    if (target.isEmpty || !target.startsWith('/')) return;
    context.go(target);
  }
}
