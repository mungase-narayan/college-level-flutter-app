import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/course_enrollment.dart';
import '../bloc/enrollments_cubit.dart';

/// Picks students and enrols them.
///
/// Port of `EnrollStudentDialog`: a searchable, paged list of students not yet
/// on the course, multi-select, with the selection **kept across pages** so a
/// teacher can gather people from several searches before committing.
Future<void> showEnrollStudentsSheet(
  BuildContext context, {
  required EnrollmentsCubit cubit,
}) =>
    showAppSheet<void>(
      context,
      title: 'Enrol students',
      builder: (_) => _EnrollForm(cubit: cubit),
    );

class _EnrollForm extends StatefulWidget {
  const _EnrollForm({required this.cubit});

  final EnrollmentsCubit cubit;

  @override
  State<_EnrollForm> createState() => _EnrollFormState();
}

class _EnrollFormState extends State<_EnrollForm> {
  /// Keyed by student id so a re-search cannot duplicate a pick, and so the
  /// selection survives paging away and back.
  final Map<String, UnenrolledStudent> _selected = {};

  Paginated<UnenrolledStudent>? _page;
  String _search = '';
  int _pageNumber = 1;
  bool _loading = true;
  bool _submitting = false;
  Failure? _failure;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final result = await widget.cubit.searchUnenrolled(
      search: _search,
      page: _pageNumber,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold(
        (failure) => _failure = failure,
        (page) {
          _failure = null;
          _page = page;
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = _page?.items ?? const <UnenrolledStudent>[];
    final totalPages = _page?.pagination.totalPages ?? 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSearchField(
          hint: 'Search by name, roll number, or email',
          onChanged: (value) {
            _search = value.trim();
            // A new search always restarts at page 1.
            _pageNumber = 1;
            _fetch();
          },
        ),
        const SizedBox(height: 12),
        if (_loading)
          const AppListSkeleton(rows: 3, lines: 2)
        else if (_failure != null)
          AppErrorView(failure: _failure!, onRetry: _fetch)
        else if (rows.isEmpty)
          const AppEmptyState(
            icon: Icons.person_search_outlined,
            title: 'No students to enrol',
            description: 'Everyone matching is already on this course.',
          )
        else
          Column(
            children: [
              for (final student in rows)
                _StudentTile(
                  student: student,
                  isSelected: _selected.containsKey(student.id),
                  onToggle: () => setState(() {
                    _selected.containsKey(student.id)
                        ? _selected.remove(student.id)
                        : _selected[student.id] = student;
                  }),
                ),
            ],
          ),
        if (totalPages > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _pageNumber > 1
                    ? () {
                        _pageNumber--;
                        _fetch();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                'Page $_pageNumber of $totalPages',
                style: theme.textTheme.labelSmall,
              ),
              IconButton(
                onPressed: _pageNumber < totalPages
                    ? () {
                        _pageNumber++;
                        _fetch();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        AppButton(
          label: _selected.isEmpty
              ? 'Select students'
              : 'Enrol ${_selected.length} student${_selected.length == 1 ? '' : 's'}',
          expand: true,
          isLoading: _submitting,
          onPressed: _selected.isEmpty ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final result = await widget.cubit.enrollAll(_selected.values.toList());
    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.enrolled == 0) {
      AppToast.error(context, 'Could not enrol the selected students.');
      return;
    }

    Navigator.of(context).pop();
    AppToast.success(
      context,
      // Partial success is reported as such rather than claiming all of them.
      result.failed == 0
          ? '${result.enrolled} student${result.enrolled == 1 ? '' : 's'} enrolled'
          : 'Enrolled ${result.enrolled} of '
              '${result.enrolled + result.failed}',
    );
  }
}

class _StudentTile extends StatelessWidget {
  const _StudentTile({
    required this.student,
    required this.isSelected,
    required this.onToggle,
  });

  final UnenrolledStudent student;
  final bool isSelected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final subtitle = student.subtitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? scheme.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: isSelected ? scheme.primary : scheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: isSelected ? scheme.primary : scheme.mutedForeground,
              ),
              const SizedBox(width: 10),
              AppAvatar(
                imageUrl: student.avatar,
                name: student.fullName,
                size: 32,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
