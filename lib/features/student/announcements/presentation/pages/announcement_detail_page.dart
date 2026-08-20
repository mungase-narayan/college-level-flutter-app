import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_colors.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/shell/presentation/widgets/student_nav.dart';
import '../../domain/entities/announcement.dart';
import '../bloc/announcement_detail_cubit.dart';
import '../widgets/announcement_attachments.dart';
import '../widgets/announcement_cover.dart';
import '../widgets/announcement_event_card.dart';

/// Port of `src/pages/student/announcements/detail.tsx`.
///
/// A drill-down above the shell, so it covers the nav bar. The app bar names the
/// *kind* rather than the announcement — titles run to 250 characters and stay
/// in the body, where the web puts them too.
class AnnouncementDetailPage extends StatefulWidget {
  const AnnouncementDetailPage({super.key});

  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

/// Which mutation is in flight, if any.
enum _Busy { registering, cancelling }

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  _Busy? _busy;

  @override
  void initState() {
    super.initState();
    context.read<AnnouncementDetailCubit>().load();
  }

  /// Pending, not optimistic.
  ///
  /// The button changes identity rather than appearance — `Register now` becomes
  /// `Cancel registration` — and the registered count moves with it, so an
  /// optimistic flip that rolled back would swap the control under the user's
  /// finger twice. `PracticeListCubit.toggleBookmark` *is* optimistic, because a
  /// bookmark is a reversible icon toggle; this is not that.
  Future<void> _run(_Busy which) async {
    if (_busy != null) return;
    setState(() => _busy = which);

    final cubit = context.read<AnnouncementDetailCubit>();
    final failure = which == _Busy.registering
        ? await cubit.register()
        : await cubit.cancelRegistration();

    if (!mounted) return;
    setState(() => _busy = null);

    if (failure == null) {
      AppToast.success(
        context,
        which == _Busy.registering
            ? 'You are registered.'
            : 'Registration cancelled.',
      );
      return;
    }

    AppToast.failure(context, failure);
    // A cancel 404s when the row is already gone — cancelled in another session,
    // say — and without a re-sync the screen keeps offering a button that will
    // keep failing.
    await cubit.load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AdaptiveAppBar(title: 'Announcement'),
      body: BlocBuilder<AnnouncementDetailCubit, RemoteState<AnnouncementDetail>>(
        builder: (context, state) {
          final announcement = state.data;

          if (announcement == null) {
            if (state.isInitialLoading) return const _DetailSkeleton();

            // The web collapses every failure into this one message; keeping
            // that means an offline student is told the announcement does not
            // exist. Faithful, and a deliberate choice.
            return AppEmptyState(
              icon: Icons.campaign_outlined,
              title: 'This announcement is not available.',
              action: AppButton(
                label: 'Back to announcements',
                variant: AppButtonVariant.outline,
                // `go`, not `pop`: this route is deep-linkable, so there may be
                // nothing behind it.
                onPressed: () => context.go(StudentRoutes.announcements),
              ),
            );
          }

          return _Body(
            announcement: announcement,
            busy: _busy,
            onRegister: () => _run(_Busy.registering),
            onCancel: () => _run(_Busy.cancelling),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.announcement,
    required this.busy,
    required this.onRegister,
    required this.onCancel,
  });

  final AnnouncementDetail announcement;
  final _Busy? busy;
  final VoidCallback onRegister;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final description = announcement.description ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppBadge(
              AnnouncementMeta.typeLabel(announcement.type),
              shade: AnnouncementMeta.typeShade(announcement.type),
              dense: true,
            ),
            AppBadge(
              // The web prints the raw enum plus the word: "HIGH priority".
              '${announcement.priority} priority',
              shade: AnnouncementMeta.priorityShade(announcement.priority),
              dense: true,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(announcement.title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: AnnouncementCover(
            url: announcement.coverImageUrl,
            aspectRatio: 16 / 7,
            iconSize: 52,
          ),
        ),
        const SizedBox(height: 16),
        if (announcement.isEvent)
          AnnouncementEventCard(
            announcement: announcement,
            action: _RegistrationBar(
              announcement: announcement,
              busy: busy,
              onRegister: onRegister,
              onCancel: onCancel,
            ),
          )
        else if (announcement.startDate != null)
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 14,
                color: theme.textTheme.labelSmall?.color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  announcement.dateRange,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('About', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          // Plain text, as on the web — announcements are not authored as
          // markdown, so rendering them as such would mangle stray asterisks.
          Text(description, style: theme.textTheme.bodyMedium),
        ],
        if (announcement.attachmentFiles.isNotEmpty) ...[
          const SizedBox(height: 20),
          AnnouncementAttachments(files: announcement.attachmentFiles),
        ],
        if (announcement.author case final author?) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              AppAvatar(
                imageUrl: author.avatar,
                name: author.fullName,
                size: 28,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Posted by ${author.fullName}'
                  '${announcement.publishedAt == null ? '' : ' · ${Fmt.dateTime(announcement.publishedAt)}'}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RegistrationBar extends StatelessWidget {
  const _RegistrationBar({
    required this.announcement,
    required this.busy,
    required this.onRegister,
    required this.onCancel,
  });

  final AnnouncementDetail announcement;
  final _Busy? busy;
  final VoidCallback onRegister;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    // Wrap, not Row: "You attended this event" beside a button overflows a
    // phone's content width.
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (announcement.isRegistered)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: context.tokens.tone(TwColors.emerald).foreground,
              ),
              const SizedBox(width: 6),
              // Flexible so the longer "You attended this event" can shrink
              // rather than overflow the row it shares with the icon.
              Flexible(
                child: Text(
                  announcement.hasAttended
                      ? 'You attended this event'
                      : "You're registered",
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          )
        else
          Text(
            'Secure your spot for this event.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: scheme.mutedForeground),
          ),
        // Attended is terminal: the web renders no button at all, not a
        // disabled one.
        if (announcement.canCancel)
          AppButton(
            label: busy == _Busy.cancelling ? 'Cancelling…' : 'Cancel registration',
            variant: AppButtonVariant.outline,
            size: AppButtonSize.sm,
            isLoading: busy == _Busy.cancelling,
            onPressed: onCancel,
          )
        else if (announcement.canRegister)
          AppButton(
            label: busy == _Busy.registering ? 'Registering…' : 'Register now',
            size: AppButtonSize.sm,
            isLoading: busy == _Busy.registering,
            onPressed: onRegister,
          ),
      ],
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeleton(height: 22, width: 160),
            SizedBox(height: 12),
            AppSkeleton(height: 26),
            SizedBox(height: 14),
            AppSkeleton(height: 170, radius: AppTheme.radiusLg),
            SizedBox(height: 16),
            AppSkeleton(height: 220, radius: AppTheme.radiusLg),
          ],
        ),
      );
}
