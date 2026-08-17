import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../shell/presentation/pages/student_shell.dart';
import '../../domain/entities/academic_calendar.dart';
import '../bloc/academic_calendar_cubit.dart';
import '../widgets/academic_calendar_header.dart';
import '../widgets/academic_calendar_month_section.dart';
import '../widgets/academic_calendar_pdf.dart';

/// Port of `src/pages/student/academic-calendar/index.tsx`.
///
/// One fetch, no filters, no search, no pagination and no detail view — the web
/// page is deliberately this small. The whole published calendar for the
/// student's current semester arrives at once and is rendered as a header card
/// followed by month-grouped entries.
///
/// It does **not** use [RemoteView], which can carry only one empty state. This
/// screen has two with different meanings — "your school has published nothing"
/// and "the calendar exists but is empty" — and the second must keep the header
/// and its Download button on screen.
class AcademicCalendarPage extends StatefulWidget {
  const AcademicCalendarPage({super.key});

  @override
  State<AcademicCalendarPage> createState() => _AcademicCalendarPageState();
}

class _AcademicCalendarPageState extends State<AcademicCalendarPage> {
  @override
  void initState() {
    super.initState();
    context.read<AcademicCalendarCubit>().load();
  }

  Future<void> _download(AcademicCalendar calendar) async {
    final auth = context.read<AuthBloc>().state;

    final built = await shareAcademicCalendarPdf(
      calendar: calendar,
      schoolName: auth.school?.name ?? 'Academic Calendar',
    );
    if (!mounted || built) return;
    AppToast.error(context, 'This calendar has no entries yet.');
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AcademicCalendarCubit>();

    return StudentScaffold(
      child: RefreshIndicator(
        onRefresh: () => cubit.load(refresh: true),
        child: BlocBuilder<AcademicCalendarCubit, RemoteState<AcademicCalendar?>>(
          builder: (context, state) {
            // `isInitialLoading` is `loading && no data`, and data is null on
            // this screen even *after* a successful load — so without the
            // refresh guard, pulling to refresh over the empty state would
            // flash the skeleton.
            if (state.isInitialLoading && !state.isRefreshing) {
              return const _Skeleton();
            }

            if (state.status == RemoteStatus.failure &&
                state.failure != null) {
              return AppErrorView(failure: state.failure!, onRetry: cubit.load);
            }

            final calendar = state.data;
            if (calendar == null) {
              return const AppEmptyState(
                icon: Icons.date_range_outlined,
                title: 'No academic calendar published',
                description: "Your school hasn't published an academic "
                    'calendar for your current semester yet. Check back later.',
              );
            }

            return _Body(
              calendar: calendar,
              onDownload: () => _download(calendar),
            );
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.calendar, required this.onDownload});

  final AcademicCalendar calendar;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    // RefreshableScroll already folds in the iOS glass insets.
    return RefreshableScroll(
      onRefresh: () =>
          context.read<AcademicCalendarCubit>().load(refresh: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AcademicCalendarHeader(calendar: calendar, onDownload: onDownload),
          const SizedBox(height: 20),
          if (!calendar.hasEntries)
            const AppEmptyState(
              icon: Icons.event_note_outlined,
              title: 'No entries yet',
              description:
                  'This calendar has no events, holidays, exams or PL added.',
            )
          else
            // Grouping already happened in the entity, so this is a direct
            // rendering of it. A term calendar is tens of rows, so building
            // them all is cheaper than the machinery to avoid it.
            for (final month in calendar.months)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AcademicCalendarMonthSection(month: month),
              ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSkeleton(height: 150, radius: AppTheme.radiusLg),
            SizedBox(height: 20),
            AppSkeleton(height: 14, width: 120),
            SizedBox(height: 12),
            AppSkeleton(height: 118, radius: AppTheme.radiusLg),
            SizedBox(height: 10),
            AppSkeleton(height: 118, radius: AppTheme.radiusLg),
          ],
        ),
      );
}
