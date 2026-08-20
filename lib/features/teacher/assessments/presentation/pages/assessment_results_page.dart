import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/injection_modules/service_locator.dart';
import '../../../../../core/error/failures.dart';
import '../../domain/entities/submission.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../../domain/usecases/teacher_assessment_usecases.dart';
import '../../domain/usecases/teacher_grading_usecases.dart';
import '../bloc/overview_cubit.dart';
import '../bloc/statistics_cubit.dart';
import '../widgets/overview_tab.dart';
import '../widgets/results_export.dart';
import '../widgets/statistics_tab.dart';
import 'submission_review_page.dart';

/// Port of `.../assignments/results/index.tsx`, as a pushed screen.
///
/// The assessment detail is fetched here rather than passed in: the review
/// screen needs the question order and the window, and the header needs the
/// published state, all of which only the detail carries.
class AssessmentResultsPage extends StatefulWidget {
  const AssessmentResultsPage({
    super.key,
    required this.assessmentId,
    required this.quiz,
  });

  final String assessmentId;

  /// Only changes the wording — the endpoints are the same for both.
  final bool quiz;

  @override
  State<AssessmentResultsPage> createState() => _AssessmentResultsPageState();
}

class _AssessmentResultsPageState extends State<AssessmentResultsPage> {
  final _assessments = sl<TeacherAssessmentUseCases>();
  final _grading = sl<TeacherGradingUseCases>();

  TeacherAssessmentDetail? _detail;
  Failure? _failure;
  bool _loading = true;
  bool _publishing = false;
  bool _exporting = false;

  String get _noun => widget.quiz ? 'quiz' : 'assignment';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });

    final result = await _assessments.getDetail(widget.assessmentId);
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _loading = false;
        _failure = failure;
      }),
      (detail) => setState(() {
        _loading = false;
        _detail = detail;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final failure = _failure;

    // Submission-type assessments have no questions, so there is nothing for
    // a Questions tab to analyse — the web hides it too.
    final showQuestions = detail?.assessment.isQuestionType ?? false;

    return DefaultTabController(
      length: showQuestions ? 2 : 1,
      child: Scaffold(
        appBar: AdaptiveAppBar(
          title: detail?.assessment.title ?? 'Results',
          // The badge states something about the assessment itself, so it
          // belongs beside its name rather than in a band below the tabs.
          titleTrailing: (detail?.assessment.resultsPublished ?? false)
              ? const AppBadge(
                  'Published',
                  icon: Icons.check_circle_outline_rounded,
                  dense: true,
                )
              : null,
          actions: [
            if (detail != null) ...[
              IconButton(
                tooltip: 'Export CSV',
                onPressed: _exporting ? null : () => _export(detail),
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded, size: 20),
              ),
              IconButton(
                tooltip: detail.assessment.resultsPublished
                    ? 'Withdraw results'
                    : 'Publish results',
                onPressed: _publishing ? null : () => _togglePublish(detail),
                icon: Icon(
                  detail.assessment.resultsPublished
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                ),
              ),
            ],
          ],
          bottom: detail == null
              ? null
              : TabBar(
                  tabs: [
                    const Tab(text: 'Overview'),
                    if (showQuestions) const Tab(text: 'Questions'),
                  ],
                ),
        ),
        body: SafeArea(
          top: false,
          child: Builder(
            builder: (context) {
              if (_loading) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: AppListSkeleton(rows: 4, lines: 3),
                );
              }
              if (failure != null) {
                return AppErrorView(failure: failure, onRetry: _load);
              }
              if (detail == null) {
                return AppEmptyState(
                  icon: Icons.insights_outlined,
                  title: 'Nothing to show',
                  description: 'This $_noun could not be loaded.',
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      children: [
                        BlocProvider(
                          create: (_) => OverviewCubit(
                            grading: _grading,
                            assessmentId: widget.assessmentId,
                          ),
                          child: Builder(
                            builder: (context) => OverviewTab(
                              onOpenSubmission: (row) =>
                                  _openSubmission(context, detail, row),
                            ),
                          ),
                        ),
                        if (showQuestions)
                          BlocProvider(
                            create: (_) => StatisticsCubit(
                              grading: _grading,
                              assessmentId: widget.assessmentId,
                            ),
                            child: const StatisticsTab(),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Pushed with the overview's cubit in scope, so a saved grade can refetch
  /// the list behind it.
  Future<void> _openSubmission(
    BuildContext context,
    TeacherAssessmentDetail detail,
    SubmissionRow row,
  ) async {
    final overview = context.read<OverviewCubit>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SubmissionReviewPage(
          assessmentId: widget.assessmentId,
          submissionId: row.id,
          assessment: detail,
        ),
      ),
    );
    if (saved == true) await overview.load(refresh: true);
  }

  Future<void> _togglePublish(TeacherAssessmentDetail detail) async {
    final published = detail.assessment.resultsPublished;
    final confirmed = await showAppConfirmDialog(
      context,
      title: published ? 'Withdraw results?' : 'Publish results?',
      message: published
          ? 'Students will no longer see their score, the correct answers or '
              'the ranking for this $_noun.'
          : 'Every student who submitted will see their score, the correct '
              'answers and the class ranking, and will be notified.',
      confirmLabel: published ? 'Withdraw' : 'Publish',
      destructive: published,
    );
    if (!confirmed || !mounted) return;

    setState(() => _publishing = true);
    final result = await _assessments.publishResults(
      id: widget.assessmentId,
      publish: !published,
    );
    if (!mounted) return;
    setState(() => _publishing = false);

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(
      context,
      published ? 'Results withdrawn.' : 'Results published.',
    );
    // The header badge reads off the detail, so it has to come back.
    await _load();
  }

  /// The web downloads the CSV; a phone hands it to the share sheet instead.
  Future<void> _export(TeacherAssessmentDetail detail) async {
    setState(() => _exporting = true);
    final result = await _grading.resultSheet(widget.assessmentId);
    if (!mounted) return;
    setState(() => _exporting = false);

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }

    final sheet = result.getOrElse(
      () => const ResultSheet(title: '', totalMarks: 0, rows: []),
    );
    if (sheet.rows.isEmpty) {
      AppToast.warning(context, 'No students are enrolled in this course yet.');
      return;
    }
    await shareResultsCsv(sheet);
  }
}

