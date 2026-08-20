import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/injection_modules/service_locator.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/design/extensions/glass_context.dart';
import '../../../../../core/design/widgets/liquid_glass_switch.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../shared/files/domain/usecases/file_usecases.dart';
import '../../../../shared/files/presentation/widgets/attachment_tile.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../../domain/usecases/teacher_assessment_usecases.dart';
import '../bloc/assessment_form_cubit.dart';
import 'question_bank_sheet.dart';

/// Port of `create-assessment-dialog.tsx`.
///
/// The web puts all seven sections in one 1,254-line dialog; on a phone they
/// become labelled sections down a single sheet, which keeps the same order
/// without a wizard the teacher has to step through.
///
/// Returns true when something was saved.
Future<bool> showAssessmentFormSheet(
  BuildContext context, {
  required String courseId,
  required bool quiz,
  String? divisionId,
  String? courseMaterialId,
  String? assessmentId,
}) async {
  final noun = quiz ? 'quiz' : 'assignment';
  final saved = await showAppSheet<bool>(
    context,
    title: assessmentId == null ? 'Create $noun' : 'Edit $noun',
    subtitle: assessmentId == null
        ? courseMaterialId != null
            ? 'Add a new assignment to this material.'
            : 'Add a new $noun to this course.'
        : 'Update the details of this $noun.',
    builder: (_) => BlocProvider(
      create: (_) => AssessmentFormCubit(
        assessments: sl<TeacherAssessmentUseCases>(),
        uploadFiles: sl<UploadFilesUseCase>(),
        courseId: courseId,
        quiz: quiz,
        divisionId: divisionId,
        courseMaterialId: courseMaterialId,
        assessmentId: assessmentId,
      )..load(),
      child: const AssessmentFormBody(),
    ),
  );
  return saved ?? false;
}

/// The sheet's body, split out from [showAssessmentFormSheet] so it can be
/// pumped directly on both platform branches.
class AssessmentFormBody extends StatefulWidget {
  const AssessmentFormBody({super.key});

  @override
  State<AssessmentFormBody> createState() => _AssessmentFormBodyState();
}

class _AssessmentFormBodyState extends State<AssessmentFormBody> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _totalMarks = TextEditingController();
  final _passingMarks = TextEditingController();
  final _maxAttempt = TextEditingController();
  final _latePenalty = TextEditingController();
  final _duration = TextEditingController();
  final _maxViolations = TextEditingController();

  /// The controllers are seeded once, when the detail lands. Rewriting them on
  /// every emit would fight the cursor as the teacher types.
  bool _seeded = false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _totalMarks,
      _passingMarks,
      _maxAttempt,
      _latePenalty,
      _duration,
      _maxViolations,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(AssessmentFormState state) {
    if (_seeded) return;
    _seeded = true;
    _title.text = state.title;
    _description.text = state.description;
    _totalMarks.text = state.totalMarks;
    _passingMarks.text = state.passingMarks;
    _maxAttempt.text = state.maxAttempt;
    _latePenalty.text = state.latePenalty;
    _duration.text = state.durationMinutes;
    _maxViolations.text = state.maxViolations;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AssessmentFormCubit>();

    return BlocBuilder<AssessmentFormCubit, AssessmentFormState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final loadFailure = state.loadFailure;
        if (loadFailure != null) {
          return AppErrorView(failure: loadFailure, onRetry: cubit.load);
        }

        _seed(state);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SectionLabel('Basics'),
            AppInput(
              controller: _title,
              label: 'Title',
              hint: 'What the ${cubit.noun} is called',
              onChanged: cubit.setTitle,
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: _description,
              label: 'Description',
              hint: 'Optional — instructions for the class',
              minLines: 3,
              maxLines: 6,
              onChanged: cubit.setDescription,
            ),

            const _SectionLabel('Configuration'),
            AppSelect<String>(
              label: 'Type',
              value: state.type,
              items: [
                for (final type in AssessmentType.options)
                  AppSelectItem(value: type, label: AssessmentType.label(type)),
              ],
              // Fixed at creation: switching a submission to a question paper
              // would orphan every submission already made against it.
              onChanged:
                  cubit.isEdit ? (_) {} : (v) => cubit.setType(v ?? state.type),
            ),
            if (cubit.isEdit)
              const _Hint('The type cannot be changed after creation.'),
            const SizedBox(height: 12),
            AppSelect<String>(
              label: 'Status',
              value: state.status,
              items: [
                for (final status in AssessmentStatus.options)
                  AppSelectItem(
                    value: status,
                    label: AssessmentStatus.label(status),
                  ),
              ],
              onChanged: (v) => cubit.setStatus(v ?? state.status),
            ),
            // Without a section there is nothing to scope to, so the choice
            // does not arise — a material assignment is one such case.
            if (cubit.divisionId != null) ...[
              const SizedBox(height: 12),
              _SwitchRow(
                title: 'Semester-wide',
                subtitle: 'Every section of the course sits the same paper',
                value: state.isSemesterWide,
                onChanged: cubit.setSemesterWide,
              ),
            ],
            const SizedBox(height: 12),
            _DateTimeRow(
              label: 'Opens',
              value: state.startDate,
              onChanged: cubit.setStartDate,
            ),
            const SizedBox(height: 10),
            _DateTimeRow(
              label: 'Due',
              value: state.endDate,
              onChanged: cubit.setEndDate,
            ),

            if (state.isQuestionType) ...[
              const _SectionLabel('Questions'),
              _QuestionsSection(cubit: cubit, state: state),
            ],

            const _SectionLabel('Scoring'),
            if (state.isQuestionType)
              _ReadOnlyField(
                label: 'Total marks',
                value: '${state.derivedMarks}',
                hint: 'Summed from the attached questions.',
              )
            else
              AppInput(
                controller: _totalMarks,
                label: 'Total marks',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: cubit.setTotalMarks,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    controller: _passingMarks,
                    label: 'Pass mark',
                    hint: 'Optional',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: cubit.setPassingMarks,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppInput(
                    controller: _maxAttempt,
                    label: 'Attempts',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: cubit.setMaxAttempt,
                  ),
                ),
              ],
            ),
            if (cubit.quiz) ...[
              const SizedBox(height: 12),
              AppInput(
                controller: _duration,
                label: 'Time limit (minutes)',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: cubit.setDurationMinutes,
                errorText: cubit.durationExceedsWindow
                    ? 'Longer than the ${state.windowMinutes}-minute window.'
                    : null,
              ),
              if (state.windowMinutes > 0 && !cubit.durationExceedsWindow)
                _Hint('The window is ${state.windowMinutes} minutes long.'),
            ],

            const _SectionLabel('Attachments'),
            for (final fileId in state.fileIds)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AttachmentTile(
                  fileId: fileId,
                  onRemove: () => cubit.removeFile(fileId),
                ),
              ),
            AppButton(
              label: state.isUploading ? 'Uploading…' : 'Attach files',
              icon: Icons.attach_file_rounded,
              variant: AppButtonVariant.outline,
              expand: true,
              isLoading: state.isUploading,
              onPressed: () => _pickFiles(cubit),
            ),

            const _SectionLabel('Advanced'),
            _SwitchRow(
              title: 'Allow late submission',
              subtitle: 'Students can submit after the due date',
              value: state.isLateAllowed,
              onChanged: cubit.setLateAllowed,
            ),
            if (state.isLateAllowed) ...[
              const SizedBox(height: 10),
              AppInput(
                controller: _latePenalty,
                label: 'Late penalty (0–5%)',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: cubit.setLatePenalty,
              ),
            ],
            const SizedBox(height: 10),
            _SwitchRow(
              title: 'Allow resubmission',
              subtitle: 'Students can submit more than once',
              value: state.isResubmissionAllowed,
              onChanged: cubit.setResubmissionAllowed,
            ),

            if (cubit.quiz) ...[
              const _SectionLabel('Proctoring'),
              _SwitchRow(
                title: 'Proctor this quiz',
                subtitle: 'Watch for the signals below during the attempt',
                value: state.isProctored,
                onChanged: cubit.setProctored,
              ),
              if (state.isProctored) ...[
                const SizedBox(height: 10),
                AppInput(
                  controller: _maxViolations,
                  label: 'Allowed violations (1–100)',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: cubit.setMaxViolations,
                ),
                const SizedBox(height: 10),
                for (final signal in ProctoringSignal.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SwitchRow(
                      title: ProctoringSignal.label(signal),
                      value: state.proctoringConfig[signal] ?? false,
                      onChanged: (v) => cubit.setProctoringSignal(signal, v),
                    ),
                  ),
              ],
            ],

            const SizedBox(height: 20),
            if (cubit.blocker != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  cubit.blocker!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.scheme.destructive,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            AppButton(
              label: cubit.isEdit ? 'Save changes' : 'Create ${cubit.noun}',
              expand: true,
              isLoading: state.isSaving,
              onPressed: cubit.canSubmit ? () => _submit(cubit) : null,
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickFiles(AssessmentFormCubit cubit) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || !mounted) return;

    final files = [
      for (final f in result.files)
        if (f.path != null) (path: f.path!, name: f.name),
    ];
    final failure = await cubit.attachFiles(files);
    if (!mounted || failure == null) return;
    AppToast.failure(context, failure);
  }

  Future<void> _submit(AssessmentFormCubit cubit) async {
    final failure = await cubit.submit();
    if (!mounted) return;
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    Navigator.of(context).pop(true);
  }
}

/// The questions attached to a question-typed assessment.
///
/// While creating, the picks wait here until the POST returns an id; in edit
/// mode each one is already on the server, and detaching uses the join-row id.
class _QuestionsSection extends StatelessWidget {
  const _QuestionsSection({required this.cubit, required this.state});

  final AssessmentFormCubit cubit;
  final AssessmentFormState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = state.attached.isEmpty && state.pending.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (empty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'No questions attached yet.',
              style: theme.textTheme.labelSmall,
            ),
          ),
        for (final q in state.attached)
          _QuestionChip(
            title: q.title ?? 'Question',
            points: q.points,
            type: q.type,
            // The join-row id, not q.questionId — the other one detaches
            // nothing and still reports success.
            onRemove: () => _detach(context, q.id),
          ),
        for (final q in state.pending)
          _QuestionChip(
            title: q.title,
            points: q.points,
            type: q.type,
            pending: true,
            onRemove: () => cubit.removePending(q.id),
          ),
        const SizedBox(height: 4),
        AppButton(
          label: 'Pick from question bank',
          icon: Icons.library_books_outlined,
          variant: AppButtonVariant.outline,
          expand: true,
          onPressed: () => _pick(context),
        ),
      ],
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await showQuestionBankSheet(
      context,
      assessmentId: cubit.assessmentId,
      // Only the create flow needs this: the bank endpoint already excludes
      // what is attached, the active-questions fallback does not.
      alreadyPicked: {for (final q in state.pending) q.id},
    );
    if (picked == null || !context.mounted) return;

    final failure = await cubit.addQuestions(picked);
    if (!context.mounted || failure == null) return;
    AppToast.failure(context, failure);
  }

  Future<void> _detach(BuildContext context, String assessmentQuestionId) async {
    final failure = await cubit.removeAttached(assessmentQuestionId);
    if (!context.mounted || failure == null) return;
    AppToast.failure(context, failure);
  }
}

class _QuestionChip extends StatelessWidget {
  const _QuestionChip({
    required this.title,
    required this.onRemove,
    this.points,
    this.type,
    this.pending = false,
  });

  final String title;
  final VoidCallback onRemove;
  final int? points;
  final String? type;

  /// Picked but not yet on the server — only possible while creating.
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.foreground,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (type != null)
                        AppBadge(QuestionType.label(type!), dense: true),
                      if (points != null) AppBadge('$points pts', dense: true),
                      if (pending) const AppBadge('Pending', dense: true),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: scheme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A date and a time, kept as one ISO value.
class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = DateTime.tryParse(value ?? '')?.toLocal();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _PickerButton(
                icon: Icons.calendar_today_rounded,
                label: parsed == null
                    ? 'Pick a date'
                    : Fmt.dmy(parsed.toIso8601String()),
                onTap: () => _pickDate(context, parsed),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _PickerButton(
                icon: Icons.schedule_rounded,
                label: parsed == null
                    ? '--:--'
                    : TimeOfDay.fromDateTime(parsed).format(context),
                onTap: parsed == null ? null : () => _pickTime(context, parsed),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context, DateTime? current) async {
    final now = DateTime.now();
    final base = current ?? DateTime(now.year, now.month, now.day, 9);
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked == null) return;

    onChanged(
      DateTime(picked.year, picked.month, picked.day, base.hour, base.minute)
          .toUtc()
          .toIso8601String(),
    );
  }

  Future<void> _pickTime(BuildContext context, DateTime current) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return;

    onChanged(
      DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      ).toUtc().toIso8601String(),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: scheme.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: onTap == null
                      ? scheme.mutedForeground
                      : scheme.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: theme.textTheme.labelSmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (context.useGlass)
            LiquidGlassSwitch(
              value: value,
              onChanged: onChanged,
              semanticLabel: title,
            )
          else
            Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.hint,
  });

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 7),
        Container(
          height: 46,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: scheme.muted.withValues(alpha: 0.4),
            border: Border.all(color: scheme.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (hint != null) _Hint(hint!),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 12),
      child: Row(
        children: [
          Text(
            text.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: scheme.border, height: 1)),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(text, style: Theme.of(context).textTheme.labelSmall),
      );
}
