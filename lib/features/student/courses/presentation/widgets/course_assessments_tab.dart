import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../assessments/domain/entities/student_assessment.dart';
import '../../../assessments/presentation/widgets/assessment_board.dart';
import '../../../../shared/shell/presentation/widgets/student_nav.dart';
import '../bloc/course_tabs_cubit.dart';

/// Port of `courses/detail/assignments/index.tsx` and its quiz twin.
///
/// Both tabs are the same screen: a client-side search plus a status filter
/// above an [AssessmentBoard]. Only the noun and the fetched category differ.
class CourseAssessmentsTab extends StatefulWidget {
  const CourseAssessmentsTab({super.key, required this.kind});

  /// `Assignment` or `Quiz` — drives the copy.
  final String kind;

  @override
  State<CourseAssessmentsTab> createState() => _CourseAssessmentsTabState();
}

class _CourseAssessmentsTabState extends State<CourseAssessmentsTab> {
  String _search = '';
  String? _status;

  @override
  void initState() {
    super.initState();
    context.read<CourseAssessmentsCubit>().load();
  }

  String get _plural => '${widget.kind.toLowerCase()}s';

  /// Client-side, exactly as the React page filters: title match plus status.
  List<StudentAssessment> _filter(List<StudentAssessment> items) {
    final query = _search.trim().toLowerCase();
    return items.where((item) {
      if (_status != null && item.statusKey != _status) return false;
      if (query.isEmpty) return true;
      return item.title.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CourseAssessmentsCubit>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: AppSearchField(
            hint: 'Search $_plural',
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 10),
          child: AppFilterChips<String?>(
            selected: _status,
            onSelected: (value) => setState(() => _status = value),
            options: [
              const AppFilterChipOption(value: null, label: 'All'),
              for (final status in AssessmentStatus.order)
                AppFilterChipOption(
                  value: status,
                  label: AssessmentStatus.label(status),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => cubit.load(refresh: true),
            child: RemoteView<CourseAssessmentsCubit, List<StudentAssessment>>(
              onRetry: cubit.load,
              loading: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppListSkeleton(rows: 3),
              ),
              isEmpty: (items) => items.isEmpty,
              emptyTitle: 'No $_plural yet',
              emptyDescription:
                  '${widget.kind}s published for your division will appear here.',
              emptyIcon: Icons.assignment_outlined,
              builder: (context, items) {
                final filtered = _filter(items);

                if (filtered.isEmpty) {
                  return AppEmptyState(
                    title: 'No $_plural match your filters',
                    description: 'Try clearing the search or the status filter.',
                    icon: Icons.filter_alt_off_outlined,
                  );
                }

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    AssessmentBoard(
                      items: filtered,
                      kind: widget.kind,
                      onOpen: (item) async {
                        await context.push(
                          widget.kind == 'Quiz'
                              ? StudentRoutes.quizDetail(item.id)
                              : StudentRoutes.assignmentDetail(item.id),
                        );
                        // Coming back from an attempt, the row's status may have
                        // changed — reload so the board re-groups it.
                        if (context.mounted) await cubit.load(refresh: true);
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
