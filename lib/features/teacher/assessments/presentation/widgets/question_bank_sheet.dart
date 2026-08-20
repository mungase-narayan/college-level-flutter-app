import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/injection_modules/service_locator.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/network/api_response.dart';
import '../../domain/entities/bank_question.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../../domain/usecases/teacher_assessment_usecases.dart';
import '../bloc/question_bank_cubit.dart';

/// Port of `question-bank-picker.tsx`.
///
/// Returns the picked questions, or null when dismissed. [assessmentId] is
/// null while creating, which switches the source and makes [alreadyPicked]
/// meaningful — see [QuestionBankCubit].
Future<List<BankQuestion>?> showQuestionBankSheet(
  BuildContext context, {
  String? assessmentId,
  Set<String> alreadyPicked = const {},
}) =>
    showAppSheet<List<BankQuestion>>(
      context,
      title: 'Pick from question bank',
      subtitle: 'Select active questions to add to this assessment.',
      builder: (_) => BlocProvider(
        create: (_) => QuestionBankCubit(
          assessments: sl<TeacherAssessmentUseCases>(),
          assessmentId: assessmentId,
          excludedIds: alreadyPicked,
        ),
        child: const _QuestionBankBody(),
      ),
    );

class _QuestionBankBody extends StatefulWidget {
  const _QuestionBankBody();

  @override
  State<_QuestionBankBody> createState() => _QuestionBankBodyState();
}

class _QuestionBankBodyState extends State<_QuestionBankBody> {
  /// Kept by id so a pick survives paging away and back.
  final _selected = <String, BankQuestion>{};

  bool _filtersOpen = false;

  @override
  void initState() {
    super.initState();
    context.read<QuestionBankCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<QuestionBankCubit>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppSearchField(
                dense: true,
                hint: 'Search questions',
                onChanged: cubit.setSearch,
              ),
            ),
            const SizedBox(width: 8),
            // The web spreads three dropdowns across the dialog; on a phone
            // they go behind one toggle, matching the courses list.
            _FilterToggle(
              open: _filtersOpen,
              active: cubit.type != QuestionBankCubit.anyValue ||
                  cubit.difficulty != QuestionBankCubit.anyValue ||
                  cubit.category != QuestionBankCubit.anyValue,
              onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
            ),
          ],
        ),
        if (_filtersOpen) ...[
          const SizedBox(height: 10),
          _Filters(cubit: cubit, onChanged: () => setState(() {})),
        ],
        const SizedBox(height: 12),
        // The sheet body already scrolls, so the list must size to its content
        // rather than claim the viewport.
        BlocBuilder<QuestionBankCubit, RemoteState<Paginated<BankQuestion>>>(
          builder: (context, state) {
            if (state.isInitialLoading) {
              return const AppListSkeleton(rows: 4, lines: 2);
            }
            final failure = state.failure;
            if (state.status == RemoteStatus.failure && failure != null) {
              return AppErrorView(failure: failure, onRetry: cubit.load);
            }

            final rows = cubit.visible;
            if (rows.isEmpty) {
              return const AppEmptyState(
                icon: Icons.help_outline_rounded,
                title: 'No questions found',
                description: 'Try a different search or clear the filters.',
              );
            }

            return Column(
              children: [
                for (final question in rows) ...[
                  _QuestionRow(
                    question: question,
                    selected: _selected.containsKey(question.id),
                    onTap: () => setState(() {
                      if (_selected.remove(question.id) == null) {
                        _selected[question.id] = question;
                      }
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                if (state.data != null)
                  AppPaginator(
                    pagination: state.data!.pagination,
                    onPageChanged: cubit.setPage,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Text(
          _selected.isEmpty
              ? 'Select questions to add'
              : '${_selected.length} question${_selected.length == 1 ? '' : 's'} selected',
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        AppButton(
          label: 'Add questions',
          expand: true,
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context)
                  .pop(_selected.values.toList(growable: false)),
        ),
      ],
    );
  }
}

class _FilterToggle extends StatelessWidget {
  const _FilterToggle({
    required this.open,
    required this.active,
    required this.onPressed,
  });

  final bool open;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return IconButton(
      tooltip: 'Filters',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: active || open ? scheme.accent : null,
        side: BorderSide(color: scheme.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      icon: Icon(
        Icons.tune_rounded,
        size: 18,
        color: active ? scheme.primary : scheme.mutedForeground,
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.cubit, required this.onChanged});

  final QuestionBankCubit cubit;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppSelect<String>(
          dense: true,
          label: 'Type',
          value: cubit.type,
          items: [
            const AppSelectItem(
              value: QuestionBankCubit.anyValue,
              label: 'All types',
            ),
            for (final type in QuestionType.options)
              AppSelectItem(value: type, label: QuestionType.label(type)),
          ],
          onChanged: (value) {
            cubit.setType(value ?? QuestionBankCubit.anyValue);
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        AppSelect<String>(
          dense: true,
          label: 'Difficulty',
          value: cubit.difficulty,
          items: [
            const AppSelectItem(
              value: QuestionBankCubit.anyValue,
              label: 'All levels',
            ),
            for (final level in QuestionDifficulty.options)
              AppSelectItem(
                value: level,
                label: QuestionDifficulty.label(level),
              ),
          ],
          onChanged: (value) {
            cubit.setDifficulty(value ?? QuestionBankCubit.anyValue);
            onChanged();
          },
        ),
        const SizedBox(height: 10),
        AppSelect<String>(
          dense: true,
          label: 'Category',
          value: cubit.category,
          items: [
            const AppSelectItem(
              value: QuestionBankCubit.anyValue,
              label: 'All categories',
            ),
            for (final category in QuestionCategory.options)
              AppSelectItem(
                value: category,
                label: QuestionCategory.label(category),
              ),
          ],
          onChanged: (value) {
            cubit.setCategory(value ?? QuestionBankCubit.anyValue);
            onChanged();
          },
        ),
      ],
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.question,
    required this.selected,
    required this.onTap,
  });

  final BankQuestion question;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final placement = question.placement;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      borderColor: selected ? scheme.primary : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 20,
            color: selected ? scheme.primary : scheme.mutedForeground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question.title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (placement != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    placement,
                    style: theme.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppBadge(QuestionType.label(question.type), dense: true),
                    AppBadge(
                      QuestionDifficulty.label(question.difficulty),
                      shade: QuestionDifficulty.shade(question.difficulty),
                      dense: true,
                    ),
                    AppBadge('${question.points} pts', dense: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
