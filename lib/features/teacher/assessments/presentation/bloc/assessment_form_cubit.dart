import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../../../shared/files/domain/usecases/file_usecases.dart';
import '../../domain/entities/bank_question.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../../domain/usecases/teacher_assessment_usecases.dart';

/// Everything the create/edit form holds.
///
/// The numeric fields stay as text: they are typed into, and parsing them
/// early would fight the keyboard (an empty box is not zero, and a half-typed
/// "1" is not a decision).
class AssessmentFormState extends Equatable {
  const AssessmentFormState({
    this.isLoading = false,
    this.isSaving = false,
    this.isUploading = false,
    this.loadFailure,
    this.title = '',
    this.description = '',
    this.type = AssessmentType.submission,
    this.status = AssessmentStatus.draft,
    this.startDate,
    this.endDate,
    this.totalMarks = '100',
    this.passingMarks = '',
    this.maxAttempt = '1',
    this.isLateAllowed = false,
    this.latePenalty = '0',
    this.isResubmissionAllowed = false,
    this.isSemesterWide = false,
    this.isProctored = false,
    this.durationMinutes = '30',
    this.maxViolations = '3',
    this.proctoringConfig = const {},
    this.fileIds = const [],
    this.attached = const [],
    this.pending = const [],
  });

  final bool isLoading;
  final bool isSaving;
  final bool isUploading;
  final Failure? loadFailure;

  final String title;
  final String description;
  final String type;
  final String status;

  /// ISO-8601 UTC, as the API stores them.
  final String? startDate;
  final String? endDate;

  final String totalMarks;
  final String passingMarks;
  final String maxAttempt;
  final bool isLateAllowed;
  final String latePenalty;
  final bool isResubmissionAllowed;

  /// Stored with no division, so every section of the course sits the same
  /// paper — the ISE / mid-sem case.
  final bool isSemesterWide;

  final bool isProctored;
  final String durationMinutes;
  final String maxViolations;
  final Map<String, bool> proctoringConfig;
  final List<String> fileIds;

  /// Edit mode: the questions already attached, straight from the server.
  final List<AssessmentQuestionRow> attached;

  /// Create mode: questions picked before the assessment exists, attached in a
  /// follow-up call once it does.
  final List<BankQuestion> pending;

  bool get isQuestionType => type == AssessmentType.questions;

  /// For question-typed assessments the server recomputes this from the
  /// attached questions, so the field is derived rather than typed.
  int get derivedMarks => isQuestionType
      ? (attached.fold(0, (sum, q) => sum + (q.points ?? 0)) +
          pending.fold(0, (sum, q) => sum + q.points))
      : (int.tryParse(totalMarks) ?? 0);

  /// How long the assessment is open for, in minutes. Zero when either end is
  /// unset or the dates are inverted.
  int get windowMinutes {
    final start = DateTime.tryParse(startDate ?? '');
    final end = DateTime.tryParse(endDate ?? '');
    if (start == null || end == null) return 0;
    final minutes = end.difference(start).inMinutes;
    return minutes > 0 ? minutes : 0;
  }

  AssessmentFormState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isUploading,
    Failure? loadFailure,
    bool clearLoadFailure = false,
    String? title,
    String? description,
    String? type,
    String? status,
    String? startDate,
    String? endDate,
    String? totalMarks,
    String? passingMarks,
    String? maxAttempt,
    bool? isLateAllowed,
    String? latePenalty,
    bool? isResubmissionAllowed,
    bool? isSemesterWide,
    bool? isProctored,
    String? durationMinutes,
    String? maxViolations,
    Map<String, bool>? proctoringConfig,
    List<String>? fileIds,
    List<AssessmentQuestionRow>? attached,
    List<BankQuestion>? pending,
  }) =>
      AssessmentFormState(
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        isUploading: isUploading ?? this.isUploading,
        loadFailure: clearLoadFailure ? null : (loadFailure ?? this.loadFailure),
        title: title ?? this.title,
        description: description ?? this.description,
        type: type ?? this.type,
        status: status ?? this.status,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        totalMarks: totalMarks ?? this.totalMarks,
        passingMarks: passingMarks ?? this.passingMarks,
        maxAttempt: maxAttempt ?? this.maxAttempt,
        isLateAllowed: isLateAllowed ?? this.isLateAllowed,
        latePenalty: latePenalty ?? this.latePenalty,
        isResubmissionAllowed:
            isResubmissionAllowed ?? this.isResubmissionAllowed,
        isSemesterWide: isSemesterWide ?? this.isSemesterWide,
        isProctored: isProctored ?? this.isProctored,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        maxViolations: maxViolations ?? this.maxViolations,
        proctoringConfig: proctoringConfig ?? this.proctoringConfig,
        fileIds: fileIds ?? this.fileIds,
        attached: attached ?? this.attached,
        pending: pending ?? this.pending,
      );

  @override
  List<Object?> get props => [
        isLoading,
        isSaving,
        isUploading,
        loadFailure,
        title,
        description,
        type,
        status,
        startDate,
        endDate,
        totalMarks,
        passingMarks,
        maxAttempt,
        isLateAllowed,
        latePenalty,
        isResubmissionAllowed,
        isSemesterWide,
        isProctored,
        durationMinutes,
        maxViolations,
        proctoringConfig,
        fileIds,
        attached,
        pending,
      ];
}

/// The create/edit form behind `create-assessment-dialog.tsx`.
///
/// One cubit serves both the assignment and the quiz variant and both modes;
/// what differs is which sections the sheet renders and which fields go on the
/// wire.
class AssessmentFormCubit extends Cubit<AssessmentFormState> {
  AssessmentFormCubit({
    required TeacherAssessmentUseCases assessments,
    required UploadFilesUseCase uploadFiles,
    required this.courseId,
    required this.quiz,
    this.divisionId,
    this.courseMaterialId,
    this.assessmentId,
  })  : _assessments = assessments,
        _uploadFiles = uploadFiles,
        super(const AssessmentFormState());

  final TeacherAssessmentUseCases _assessments;
  final UploadFilesUseCase _uploadFiles;

  final String courseId;

  /// The quiz variant: category becomes `quiz`, and duration and proctoring
  /// appear. Assignments have neither.
  final bool quiz;

  final String? divisionId;
  final String? courseMaterialId;

  /// Null while creating.
  final String? assessmentId;

  bool get isEdit => assessmentId != null;

  static const maxTitleLength = 500;
  static const maxDurationMinutes = 600;
  static const maxLatePenalty = 5;
  static const maxViolationCount = 100;

  String get noun => quiz ? 'quiz' : 'assignment';

  /// Derived, never picked: a quiz is a quiz, and an assignment tied to a
  /// material is a different category from one tied to the course.
  String get category => quiz
      ? AssessmentCategory.quiz
      : courseMaterialId != null
          ? AssessmentCategory.courseMaterialAssignment
          : AssessmentCategory.courseAssignment;

  /// The server rejects an attempt longer than the window it sits in
  /// (`ASSESSMENT_DURATION_EXCEEDS_WINDOW`); catching it here saves the round
  /// trip and names the actual problem.
  bool get durationExceedsWindow {
    if (!quiz) return false;
    final duration = int.tryParse(state.durationMinutes) ?? 0;
    final window = state.windowMinutes;
    return window > 0 && duration > 0 && duration > window;
  }

  /// Why the form cannot be submitted yet, or null when it can.
  String? get blocker {
    final s = state;
    if (s.title.trim().isEmpty) return 'A title is required.';
    if (s.title.trim().length > maxTitleLength) {
      return 'The title is longer than $maxTitleLength characters.';
    }
    if (s.startDate == null) return 'Set when it opens.';
    if (s.endDate == null) return 'Set when it is due.';
    if (s.windowMinutes <= 0) return 'The due date must be after it opens.';
    if (!s.isSemesterWide && (divisionId ?? '').isEmpty) {
      return 'No section is selected.';
    }
    if (quiz) {
      final duration = int.tryParse(s.durationMinutes) ?? 0;
      if (duration <= 0) return 'Set a time limit.';
      if (duration > maxDurationMinutes) {
        return 'The time limit cannot exceed $maxDurationMinutes minutes.';
      }
      if (durationExceedsWindow) {
        return 'The time limit is longer than the ${s.windowMinutes}-minute window.';
      }
      if (s.isProctored) {
        final violations = int.tryParse(s.maxViolations) ?? 0;
        if (violations <= 0 || violations > maxViolationCount) {
          return 'Allowed violations must be between 1 and $maxViolationCount.';
        }
      }
    }
    if (s.isLateAllowed) {
      final penalty = int.tryParse(s.latePenalty) ?? 0;
      if (penalty < 0 || penalty > maxLatePenalty) {
        return 'The late penalty must be between 0 and $maxLatePenalty.';
      }
    }
    return null;
  }

  bool get canSubmit => blocker == null && !state.isSaving && !state.isLoading;

  /// Edit mode only — seeds the form from the server.
  Future<void> load() async {
    final id = assessmentId;
    if (id == null) {
      // Create mode still needs the proctoring defaults, which are all-on.
      emit(state.copyWith(proctoringConfig: ProctoringSignal.defaults));
      return;
    }

    emit(state.copyWith(isLoading: true, clearLoadFailure: true));
    final result = await _assessments.getDetail(id);
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, loadFailure: failure)),
      (detail) => emit(_seed(detail)),
    );
  }

  AssessmentFormState _seed(TeacherAssessmentDetail detail) {
    final a = detail.assessment;
    return state.copyWith(
      isLoading: false,
      clearLoadFailure: true,
      title: a.title,
      description: a.description ?? '',
      type: a.type,
      status: a.status,
      startDate: a.startDate,
      endDate: a.endDate,
      totalMarks: '${a.totalMarks}',
      passingMarks: a.passingMarks == null ? '' : '${a.passingMarks}',
      maxAttempt: '${detail.maxAttempt}',
      isLateAllowed: detail.isLateSubmissionAllowed,
      latePenalty: '${detail.latePenalty}',
      isResubmissionAllowed: detail.isAllowResubmission,
      isSemesterWide: a.isSemesterWide,
      isProctored: detail.isProctored,
      durationMinutes: '${detail.durationMinutes ?? 30}',
      maxViolations: '${detail.maxViolations ?? 3}',
      proctoringConfig: detail.proctoringConfig ?? ProctoringSignal.defaults,
      fileIds: detail.fileIds,
      attached: detail.questions,
    );
  }

  // ── Field setters ────────────────────────────────────────────────────────

  void setTitle(String value) => emit(state.copyWith(title: value));
  void setDescription(String value) =>
      emit(state.copyWith(description: value));

  /// Immutable once created — the sheet disables the control in edit mode, and
  /// this refuses it too so the two cannot drift apart.
  void setType(String value) {
    if (assessmentId != null) return;
    emit(state.copyWith(type: value));
  }

  void setStatus(String value) => emit(state.copyWith(status: value));
  void setStartDate(String value) => emit(state.copyWith(startDate: value));
  void setEndDate(String value) => emit(state.copyWith(endDate: value));
  void setTotalMarks(String value) => emit(state.copyWith(totalMarks: value));
  void setPassingMarks(String value) =>
      emit(state.copyWith(passingMarks: value));
  void setMaxAttempt(String value) => emit(state.copyWith(maxAttempt: value));
  void setLateAllowed(bool value) => emit(state.copyWith(isLateAllowed: value));
  void setLatePenalty(String value) =>
      emit(state.copyWith(latePenalty: value));
  void setResubmissionAllowed(bool value) =>
      emit(state.copyWith(isResubmissionAllowed: value));
  void setSemesterWide(bool value) =>
      emit(state.copyWith(isSemesterWide: value));
  void setProctored(bool value) => emit(state.copyWith(isProctored: value));
  void setDurationMinutes(String value) =>
      emit(state.copyWith(durationMinutes: value));
  void setMaxViolations(String value) =>
      emit(state.copyWith(maxViolations: value));

  void setProctoringSignal(String signal, bool value) => emit(
        state.copyWith(
          proctoringConfig: {...state.proctoringConfig, signal: value},
        ),
      );

  // ── Attachments ──────────────────────────────────────────────────────────

  Future<Failure?> attachFiles(
    List<({String path, String name})> files,
  ) async {
    if (files.isEmpty) return null;
    emit(state.copyWith(isUploading: true));

    final result = await _uploadFiles(UploadFilesParams(files));
    if (isClosed) return null;

    return result.fold(
      (failure) {
        emit(state.copyWith(isUploading: false));
        return failure;
      },
      (uploaded) {
        emit(state.copyWith(
          isUploading: false,
          fileIds: [...state.fileIds, for (final f in uploaded) f.id],
        ));
        return null;
      },
    );
  }

  void removeFile(String fileId) => emit(
        state.copyWith(
          fileIds: [for (final id in state.fileIds) if (id != fileId) id],
        ),
      );

  // ── Questions ────────────────────────────────────────────────────────────

  /// In edit mode each pick is attached immediately; while creating they wait
  /// in [AssessmentFormState.pending] until the POST returns an id.
  Future<Failure?> addQuestions(List<BankQuestion> picked) async {
    if (picked.isEmpty) return null;

    final id = assessmentId;
    if (id == null) {
      final have = {for (final q in state.pending) q.id};
      emit(state.copyWith(
        pending: [
          ...state.pending,
          for (final q in picked)
            if (!have.contains(q.id)) q,
        ],
      ));
      return null;
    }

    for (final question in picked) {
      final result = await _assessments.addQuestion(
        assessmentId: id,
        questionId: question.id,
      );
      if (isClosed) return null;
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      if (failure != null) return failure;
    }
    await _refreshQuestions();
    return null;
  }

  void removePending(String questionId) => emit(
        state.copyWith(
          pending: [
            for (final q in state.pending)
              if (q.id != questionId) q,
          ],
        ),
      );

  /// [assessmentQuestionId] is the **join-row** id. Passing the question's own
  /// id detaches nothing and reports success.
  Future<Failure?> removeAttached(String assessmentQuestionId) async {
    final id = assessmentId;
    if (id == null) return null;

    final result = await _assessments.removeQuestion(
      assessmentId: id,
      assessmentQuestionId: assessmentQuestionId,
    );
    if (isClosed) return null;

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) return failure;
    await _refreshQuestions();
    return null;
  }

  Future<void> _refreshQuestions() async {
    final id = assessmentId;
    if (id == null) return;
    final result = await _assessments.getDetail(id);
    if (isClosed) return;
    result.fold(
      (_) {},
      (detail) => emit(state.copyWith(attached: detail.questions)),
    );
  }

  // ── Submit ───────────────────────────────────────────────────────────────

  /// Saves, and returns the failure that stopped it — null on success.
  Future<Failure?> submit() async {
    if (blocker != null) return null;
    emit(state.copyWith(isSaving: true));

    final body = buildBody();
    final id = assessmentId;

    if (id != null) {
      final result = await _assessments.update(id: id, body: body);
      if (isClosed) return null;
      final failure = result.fold<Failure?>((f) => f, (_) => null);
      emit(state.copyWith(isSaving: false));
      return failure;
    }

    final created = await _assessments.create(body);
    if (isClosed) return null;

    final failure = created.fold<Failure?>((f) => f, (_) => null);
    if (failure != null) {
      emit(state.copyWith(isSaving: false));
      return failure;
    }

    // Questions can only be attached once the assessment has an id, so the
    // picks made while creating land in a second pass. A pick that fails is
    // not worth discarding the assessment over — the form reports it and the
    // teacher can attach it again from the edit sheet.
    final newId = created.fold((_) => '', (a) => a.id);
    if (state.isQuestionType && state.pending.isNotEmpty && newId.isNotEmpty) {
      for (final question in state.pending) {
        await _assessments.addQuestion(
          assessmentId: newId,
          questionId: question.id,
        );
        if (isClosed) return null;
      }
    }

    emit(state.copyWith(isSaving: false));
    return null;
  }

  /// The request body. Exposed so the shape can be asserted directly.
  Map<String, dynamic> buildBody() {
    final s = state;
    final editing = assessmentId != null;

    return {
      'title': s.title.trim(),
      if (s.description.trim().isNotEmpty) 'description': s.description.trim(),
      'courseId': courseId,
      'type': s.type,
      'status': s.status,
      'startDate': s.startDate,
      'endDate': s.endDate,
      // The server recomputes this for question-typed assessments, but sending
      // the derived value keeps an edit from momentarily zeroing the marks.
      'totalMarks': s.derivedMarks,
      if (s.passingMarks.trim().isNotEmpty)
        'passingMarks': int.tryParse(s.passingMarks.trim()),
      'maxAttempt': int.tryParse(s.maxAttempt) ?? 1,
      'isLateSubmissionAllowed': s.isLateAllowed,
      'latePenalty': s.isLateAllowed ? (int.tryParse(s.latePenalty) ?? 0) : 0,
      'isAllowResubmission': s.isResubmissionAllowed,
      if (s.fileIds.isNotEmpty) 'fileIds': s.fileIds,
      'isSemesterWide': s.isSemesterWide,
      // Semester-wide means no division at all. The web sends the active one
      // anyway on edit, which can re-scope a semester-wide paper to a section.
      if (!s.isSemesterWide && divisionId != null) 'divisionId': divisionId,
      // Both define the assessment's scope and are fixed at creation; the
      // update endpoint applies whatever it is sent, so an edit must omit them.
      if (!editing) 'category': category,
      if (!editing && !quiz && courseMaterialId != null)
        'courseMaterialId': courseMaterialId,
      // Duration and proctoring are quiz-only concepts.
      if (quiz) ...{
        'durationMinutes': int.tryParse(s.durationMinutes) ?? 0,
        'isProctored': s.isProctored,
        if (s.isProctored) ...{
          'maxViolations': int.tryParse(s.maxViolations) ?? 0,
          'proctoringConfig': s.proctoringConfig,
        },
      },
    };
  }
}
