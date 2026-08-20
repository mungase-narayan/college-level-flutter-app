import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/injection_modules/service_locator.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/utils/formatters.dart';
import '../../domain/entities/attendance_session.dart';
import '../../domain/usecases/attendance_usecases.dart';
import '../bloc/roster_cubit.dart';
import '../widgets/roster_marker.dart';

/// Port of `TeacherAttendanceSessionPage` — the marking screen.
///
/// A drill-down rather than a tab: marking a roster is a focused task, and it
/// is reached from a session row that the shell chrome would only get in the
/// way of.
class RosterPage extends StatefulWidget {
  const RosterPage({super.key, required this.sessionId});

  final String sessionId;

  static Future<void> push(
    BuildContext context, {
    required String sessionId,
  }) =>
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider(
            create: (_) => RosterCubit(
              attendance: sl<AttendanceUseCases>(),
              sessionId: sessionId,
            ),
            child: RosterPage(sessionId: sessionId),
          ),
        ),
      );

  @override
  State<RosterPage> createState() => _RosterPageState();
}

class _RosterPageState extends State<RosterPage> {
  /// The roster paginates client-side — the whole thing arrives in one payload.
  static const _pageSize = 10;

  int _page = 1;

  @override
  void initState() {
    super.initState();
    context.read<RosterCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RosterCubit>();

    return Scaffold(
      appBar: const AdaptiveAppBar(title: 'Attendance'),
      body: SafeArea(
        top: false,
        child: RemoteView<RosterCubit, RosterData>(
          onRetry: cubit.load,
          loading: const Padding(
            padding: EdgeInsets.all(16),
            child: AppListSkeleton(rows: 5, lines: 2),
          ),
          builder: (context, data) {
            if (data.records.isEmpty) {
              return const AppEmptyState(
                icon: Icons.group_outlined,
                title: 'No students in this division',
                description: 'Enroll students and assign them to this '
                    'division to mark attendance.',
              );
            }

            final totalPages = (data.records.length / _pageSize).ceil();
            final page = _page.clamp(1, totalPages);
            final start = (page - 1) * _pageSize;
            final visible = data.records.skip(start).take(_pageSize).toList();

            return Column(
              children: [
                _Header(data: data),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      RosterMarker(
                        records: visible,
                        marks: data.marks,
                        readOnly: data.isReadOnly,
                        startIndex: start,
                        onMark: cubit.setMark,
                      ),
                      if (totalPages > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _RosterPaginator(
                            page: page,
                            totalPages: totalPages,
                            onChanged: (value) => setState(() => _page = value),
                          ),
                        ),
                    ],
                  ),
                ),
                // Every control disappears once finalized — the API refuses
                // further marks, so offering them would only produce a 409.
                if (!data.isReadOnly) _Actions(data: data),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Session identity, then the live counts.
class _Header extends StatelessWidget {
  const _Header({required this.data});

  final RosterData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final session = data.session;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  session.title,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AppBadge(
                AttendanceStatus.label(session.status),
                shade: AttendanceStatus.shade(session.status),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              AttendanceType.label(session.type),
              Fmt.dmy(session.sessionDate),
              if (session.startTime != null) Fmt.time(session.startTime),
            ].join(' · '),
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          // Recomputed from the local marks, so they move as the teacher taps
          // rather than after a save.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final status in MarkStatus.options)
                AppBadge(
                  '${MarkStatus.label(status)} ${data.countOf(status)}',
                  shade: MarkStatus.shade(status),
                  dense: true,
                ),
              AppBadge('Total ${data.records.length}', dense: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.data});

  final RosterData data;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<RosterCubit>();
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: scheme.card,
        border: Border(top: BorderSide(color: scheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Mark all present',
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  onPressed: data.isBusy ? null : cubit.markAllPresent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Finalize',
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  onPressed: data.isBusy ? null : () => _finalize(context, cubit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Save attendance',
            expand: true,
            isLoading: data.isBusy,
            onPressed: () => _save(context, cubit),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, RosterCubit cubit) async {
    final failure = await cubit.save();
    if (!context.mounted) return;
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, 'Attendance saved.');
  }

  Future<void> _finalize(BuildContext context, RosterCubit cubit) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Finalize this session?',
      message: 'Once finalized, the attendance can no longer be edited. '
          'Any unsaved changes will be saved first.',
      confirmLabel: 'Finalize',
    );
    if (!confirmed || !context.mounted) return;

    final failure = await cubit.saveAndFinalize();
    if (!context.mounted) return;
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, 'Attendance finalized.');
  }
}

class _RosterPaginator extends StatelessWidget {
  const _RosterPaginator({
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          'Page $page of $totalPages',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        IconButton(
          onPressed: page < totalPages ? () => onChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}
