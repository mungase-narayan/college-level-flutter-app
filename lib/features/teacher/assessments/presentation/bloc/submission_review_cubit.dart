import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/error/failures.dart';
import '../../domain/entities/submission.dart';
import '../../domain/entities/teacher_assessment.dart';
import '../../domain/usecases/teacher_grading_usecases.dart';

/// Where one answer sits for the navigator palette.
enum GradeState { correct, partial, wrong, ungraded }

/// The teacher's in-progress marks for one answer.
class AnswerMark extends Equatable {
  const AnswerMark({this.score = '', this.feedback = '', this.isCorrect});

  /// Kept as text: an empty box is not a zero.
  final String score;
  final String feedback;
  final bool? isCorrect;

  AnswerMark copyWith({
    String? score,
    String? feedback,
    bool? isCorrect,
    bool clearCorrect = false,
  }) =>
      AnswerMark(
        score: score ?? this.score,
        feedback: feedback ?? this.feedback,
        isCorrect: clearCorrect ? null : (isCorrect ?? this.isCorrect),
      );

  @override
  List<Object?> get props => [score, feedback, isCorrect];
}

class SubmissionReviewState extends Equatable {
  const SubmissionReviewState({
    this.isLoading = false,
    this.isSaving = false,
    this.isReattempting = false,
    this.failure,
    this.detail,
    this.note,
    this.answers = const [],
    this.marks = const {},
    this.current = 0,
    this.overallScore = '',
    this.overallFeedback = '',
  });

  final bool isLoading;
  final bool isSaving;
  final bool isReattempting;
  final Failure? failure;

  final SubmissionDetail? detail;
  final SubmissionNote? note;

  /// The answers in the assessment's question order, which the raw payload is
  /// not in.
  final List<SubmissionAnswer> answers;

  /// Keyed by **answer** id.
  final Map<String, AnswerMark> marks;

  final int current;
  final String overallScore;
  final String overallFeedback;

  SubmissionRow? get submission => detail?.submission;

  /// An attempt still in progress is view-only: the student can still change
  /// it, so there is nothing stable to grade.
  bool get readOnly => submission?.inProgress ?? false;

  int get awarded => answers.fold(
        0,
        (sum, a) => sum + (int.tryParse(marks[a.id]?.score ?? '') ?? 0),
      );

  int get maxMarks => answers.fold(0, (sum, a) => sum + a.questionPoints);

  SubmissionReviewState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isReattempting,
    Failure? failure,
    bool clearFailure = false,
    SubmissionDetail? detail,
    SubmissionNote? note,
    List<SubmissionAnswer>? answers,
    Map<String, AnswerMark>? marks,
    int? current,
    String? overallScore,
    String? overallFeedback,
  }) =>
      SubmissionReviewState(
        isLoading: isLoading ?? this.isLoading,
        isSaving: isSaving ?? this.isSaving,
        isReattempting: isReattempting ?? this.isReattempting,
        failure: clearFailure ? null : (failure ?? this.failure),
        detail: detail ?? this.detail,
        note: note ?? this.note,
        answers: answers ?? this.answers,
        marks: marks ?? this.marks,
        current: current ?? this.current,
        overallScore: overallScore ?? this.overallScore,
        overallFeedback: overallFeedback ?? this.overallFeedback,
      );

  @override
  List<Object?> get props => [
        isLoading,
        isSaving,
        isReattempting,
        failure,
        detail,
        note,
        answers,
        marks,
        current,
        overallScore,
        overallFeedback,
      ];
}

/// Reviewing and grading one attempt.
class SubmissionReviewCubit extends Cubit<SubmissionReviewState> {
  SubmissionReviewCubit({
    required TeacherGradingUseCases grading,
    required this.assessmentId,
    required this.submissionId,
    required this.assessment,
  })  : _grading = grading,
        super(const SubmissionReviewState());

  final TeacherGradingUseCases _grading;
  final String assessmentId;
  final String submissionId;

  /// Needed for the question order, the total marks, and whether the attempt
  /// can still be reopened.
  final TeacherAssessmentDetail assessment;

  bool get isSubmissionType => !assessment.assessment.isQuestionType;

  /// Reopening only helps while the student could still resume — a closed
  /// window makes it pointless.
  bool get windowOpen {
    if (assessment.isLateSubmissionAllowed) return true;
    final end = DateTime.tryParse(assessment.assessment.endDate);
    return end != null && !end.isBefore(DateTime.now());
  }

  bool get canReattempt => !state.readOnly && windowOpen;

  Future<void> load() async {
    if (isClosed) return;
    emit(state.copyWith(isLoading: true, clearFailure: true));

    final result = await _grading.submission(
      assessmentId: assessmentId,
      submissionId: submissionId,
    );
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(isLoading: false, failure: failure)),
      (payload) => emit(_seed(payload.detail, payload.note)),
    );
  }

  SubmissionReviewState _seed(SubmissionDetail detail, SubmissionNote note) {
    final ordered = _order(detail.answers);

    return state.copyWith(
      isLoading: false,
      clearFailure: true,
      detail: detail,
      note: note,
      answers: ordered,
      marks: {
        for (final a in detail.answers)
          a.id: AnswerMark(
            // Backfilled from the test-case ratio when nothing is stored, so
            // a partially-passing coding answer does not read as ungraded.
            score: a.seededScore?.toString() ?? '',
            feedback: a.feedback ?? '',
            isCorrect: a.seededMark,
          ),
      },
      current: 0,
      overallScore: detail.submission.totalScore?.toString() ?? '',
      overallFeedback: note.feedback ?? '',
    );
  }

  /// The payload's answers are unordered; the assessment's question list is
  /// the authority. Anything with no matching question is appended rather than
  /// dropped.
  List<SubmissionAnswer> _order(List<SubmissionAnswer> answers) {
    final byQuestion = {
      for (final a in answers) a.assessmentQuestionId: a,
    };
    final ordered = <SubmissionAnswer>[];
    for (final q in assessment.questions) {
      final answer = byQuestion[q.id];
      if (answer != null) ordered.add(answer);
    }
    final seen = {for (final a in ordered) a.assessmentQuestionId};
    for (final a in answers) {
      if (!seen.contains(a.assessmentQuestionId)) ordered.add(a);
    }
    return ordered;
  }

  /// The palette bucket. A coding answer with test cases is bucketed by its
  /// pass ratio, which overrides the teacher's mark for the colour only — the
  /// score they typed is still what gets saved.
  GradeState gradeOf(SubmissionAnswer answer) {
    if (answer.hasTestCases) {
      final passed = answer.testCasesPassed ?? 0;
      final total = answer.testCasesTotal!;
      if (passed >= total) return GradeState.correct;
      return passed > 0 ? GradeState.partial : GradeState.wrong;
    }
    return switch (state.marks[answer.id]?.isCorrect) {
      true => GradeState.correct,
      false => GradeState.wrong,
      null => GradeState.ungraded,
    };
  }

  /// Graded so far while reviewing, answered so far while view-only.
  int get progressCount => state.readOnly
      ? state.answers.where((a) => a.hasContent).length
      : state.answers.where((a) => gradeOf(a) != GradeState.ungraded).length;

  void setCurrent(int index) => emit(state.copyWith(current: index));

  void setScore(String answerId, String value) => _mark(
        answerId,
        (mark) => mark.copyWith(score: value),
      );

  void setFeedback(String answerId, String value) => _mark(
        answerId,
        (mark) => mark.copyWith(feedback: value),
      );

  /// The two shortcut buttons, which set the mark and the score together.
  void markCorrect(SubmissionAnswer answer) => _mark(
        answer.id,
        (mark) => mark.copyWith(
          isCorrect: true,
          score: '${answer.questionPoints}',
        ),
      );

  void markWrong(SubmissionAnswer answer) => _mark(
        answer.id,
        (mark) => mark.copyWith(isCorrect: false, score: '0'),
      );

  void _mark(String answerId, AnswerMark Function(AnswerMark) update) {
    final current = state.marks[answerId] ?? const AnswerMark();
    emit(state.copyWith(marks: {...state.marks, answerId: update(current)}));
  }

  void setOverallScore(String value) =>
      emit(state.copyWith(overallScore: value));

  void setOverallFeedback(String value) =>
      emit(state.copyWith(overallFeedback: value));

  /// The body the evaluate endpoint gets. Exposed so its shape can be asserted
  /// without going through the widget.
  EvaluationInput buildInput() {
    if (isSubmissionType) {
      final total = assessment.assessment.totalMarks;
      return EvaluationInput(
        feedback: state.overallFeedback,
        overallScore:
            (int.tryParse(state.overallScore) ?? 0).clamp(0, total).toInt(),
      );
    }

    return EvaluationInput(
      feedback: state.overallFeedback,
      questions: [
        for (final answer in state.answers)
          QuestionEvaluation(
            questionSubmissionId: answer.id,
            // The web clamps only at zero, so a typo can award 500 on a
            // 5-point question and the server takes it.
            score: (int.tryParse(state.marks[answer.id]?.score ?? '') ?? 0)
                .clamp(0, answer.questionPoints)
                .toInt(),
            feedback: state.marks[answer.id]?.feedback,
            isCorrect: state.marks[answer.id]?.isCorrect,
          ),
      ],
    );
  }

  Future<Failure?> save() async {
    if (state.readOnly) return null;
    emit(state.copyWith(isSaving: true));

    final result = await _grading.evaluate(
      assessmentId: assessmentId,
      submissionId: submissionId,
      input: buildInput(),
    );
    if (isClosed) return null;

    emit(state.copyWith(isSaving: false));
    return result.fold<Failure?>((f) => f, (_) => null);
  }

  Future<Failure?> allowReattempt() async {
    emit(state.copyWith(isReattempting: true));

    final result = await _grading.allowReattempt(
      assessmentId: assessmentId,
      submissionId: submissionId,
    );
    if (isClosed) return null;

    emit(state.copyWith(isReattempting: false));
    return result.fold<Failure?>((f) => f, (_) => null);
  }
}
