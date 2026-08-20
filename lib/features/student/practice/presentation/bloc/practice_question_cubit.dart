import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/practice_attempt.dart';
import '../../domain/entities/practice_question.dart';
import '../../domain/usecases/practice_usecases.dart';

/// Everything the solve screen renders.
///
/// One state object rather than a cubit with fields beside it, because **every
/// part of this is drawn**: the draft answer, the run output, the submitted
/// result and the attempt list. The assessments cubit learned this the hard way
/// — answers held in a field next to the state changed what the UI read without
/// changing state equality, bloc dropped the emission, and the screen kept
/// showing the old选择 until something else rebuilt it. `test/features/
/// assessment_answer_state_test.dart` exists to pin that. The same trap is
/// waiting here, so nothing lives outside the state.
class PracticeSolveState extends Equatable {
  const PracticeSolveState({
    required this.detail,
    this.draft = const PracticeAnswerDraft(),
    this.attempts = const [],
    this.revealed,
    this.runResult,
    this.customResult,
    this.submitted,
    this.isRunning = false,
    this.isSubmitting = false,
    this.isNavigating = false,
  });

  final PracticeQuestionDetail detail;

  /// What the student has entered but not sent.
  final PracticeAnswerDraft draft;

  /// Newest first, as the server orders them.
  final List<PracticeAttempt> attempts;

  /// The question with its answer key — supplied by `/attempts` or `/submit`,
  /// never by the plain detail fetch. Null until one of those has run.
  final PracticeQuestion? revealed;

  final PracticeCodingResult? runResult;
  final PracticeCustomRunResult? customResult;

  /// The attempt just submitted, which is what the result panel shows.
  final PracticeAttempt? submitted;

  final bool isRunning;
  final bool isSubmitting;
  final bool isNavigating;

  PracticeQuestion get question => detail.question;

  /// The explanation is unlocked by having tried, not by having succeeded —
  /// matching the web. The server is more generous than that (it hands the key
  /// over to anyone who calls `/attempts`), so this gate lives here.
  bool get hasAttempted => attempts.isNotEmpty;

  /// The question to read the answer key off, once there is one.
  PracticeQuestion get solutionSource => revealed ?? question;

  bool get canSubmit => draft.canSubmit(question) && !isSubmitting;

  PracticeSolveState copyWith({
    PracticeQuestionDetail? detail,
    PracticeAnswerDraft? draft,
    List<PracticeAttempt>? attempts,
    PracticeQuestion? revealed,
    PracticeCodingResult? runResult,
    PracticeCustomRunResult? customResult,
    PracticeAttempt? submitted,
    bool? isRunning,
    bool? isSubmitting,
    bool? isNavigating,
    bool clearRun = false,
    bool clearSubmitted = false,
  }) =>
      PracticeSolveState(
        detail: detail ?? this.detail,
        draft: draft ?? this.draft,
        attempts: attempts ?? this.attempts,
        revealed: revealed ?? this.revealed,
        runResult: clearRun ? null : (runResult ?? this.runResult),
        customResult: clearRun ? null : (customResult ?? this.customResult),
        submitted: clearSubmitted ? null : (submitted ?? this.submitted),
        isRunning: isRunning ?? this.isRunning,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isNavigating: isNavigating ?? this.isNavigating,
      );

  @override
  List<Object?> get props => [
        detail,
        draft,
        attempts,
        revealed,
        runResult,
        customResult,
        submitted,
        isRunning,
        isSubmitting,
        isNavigating,
      ];
}

/// The solve screen for one practice question.
class PracticeQuestionCubit extends Cubit<RemoteState<PracticeSolveState>> {
  PracticeQuestionCubit({
    required GetPracticeQuestionUseCase getQuestion,
    required GetPracticeAttemptsUseCase getAttempts,
    required SubmitPracticeUseCase submitAnswer,
    required RunPracticeCodeUseCase runCode,
    required RunPracticeCustomUseCase runCustom,
    required NavigatePracticeUseCase navigate,
    required SetBookmarkedUseCase setBookmarked,
    required this.questionId,
  })  : _getQuestion = getQuestion,
        _getAttempts = getAttempts,
        _submitAnswer = submitAnswer,
        _runCode = runCode,
        _runCustom = runCustom,
        _navigate = navigate,
        _setBookmarked = setBookmarked,
        super(const RemoteState());

  final GetPracticeQuestionUseCase _getQuestion;
  final GetPracticeAttemptsUseCase _getAttempts;
  final SubmitPracticeUseCase _submitAnswer;
  final RunPracticeCodeUseCase _runCode;
  final RunPracticeCustomUseCase _runCustom;
  final NavigatePracticeUseCase _navigate;
  final SetBookmarkedUseCase _setBookmarked;

  final String questionId;

  /// When the student opened the question — the server stores the difference as
  /// their time on task.
  DateTime _openedAt = DateTime.now();

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _getQuestion(IdParams(questionId));
    if (isClosed) return;

    await result.fold(
      (failure) async => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (detail) async {
        _openedAt = DateTime.now();
        emit(RemoteState(
          status: RemoteStatus.success,
          data: PracticeSolveState(
            detail: detail,
            draft: _seedDraft(detail.question),
          ),
        ));
        // History is a second request, and the screen is usable without it —
        // so it lands separately rather than holding up the question.
        await loadAttempts();
      },
    );
  }

  /// Seeds the editor with the question's starter code for its first language.
  ///
  /// Objective and subjective questions start empty on purpose: pre-filling a
  /// choice would answer for the student.
  PracticeAnswerDraft _seedDraft(PracticeQuestion question) {
    if (!question.isCoding || question.languageTemplates.isEmpty) {
      return const PracticeAnswerDraft();
    }
    final first = question.languageTemplates.first;
    return PracticeAnswerDraft(
      language: first.language,
      code: first.initialCode,
    );
  }

  Future<void> loadAttempts() async {
    final current = state.data;
    if (isClosed || current == null) return;

    final result = await _getAttempts(IdParams(questionId));
    if (isClosed) return;

    result.fold(
      // A history that will not load is not worth breaking the screen over —
      // the student can still answer the question.
      (_) {},
      (history) => emit(state.copyWith(
        data: state.data!.copyWith(
          attempts: history.attempts,
          revealed: history.question,
        ),
      )),
    );
  }

  void setDraft(PracticeAnswerDraft draft) {
    final current = state.data;
    if (isClosed || current == null) return;
    emit(state.copyWith(data: current.copyWith(draft: draft)));
  }

  /// Switches language, keeping what was typed in the old one.
  ///
  /// [previousBuffers] is the caller's per-language store; the cubit only needs
  /// to know what to show now.
  void setLanguage(String language, {String? restoredCode}) {
    final current = state.data;
    if (isClosed || current == null) return;

    final template = current.question.languageTemplates
        .where((t) => t.language == language)
        .firstOrNull;
    emit(state.copyWith(
      data: current.copyWith(
        draft: current.draft.copyWith(
          language: language,
          code: restoredCode ?? template?.initialCode ?? '',
        ),
        // The old run output described the old language's code.
        clearRun: true,
      ),
    ));
  }

  /// Runs against the sample cases. Nothing is stored and no attempt is used.
  Future<Failure?> run() async {
    final current = state.data;
    if (isClosed || current == null || current.isRunning) return null;

    final draft = current.draft;
    emit(state.copyWith(
      data: current.copyWith(isRunning: true, clearRun: true),
    ));

    final result = await _runCode(
      RunCodeParams(
        questionId: questionId,
        code: draft.code ?? '',
        language: draft.language ?? '',
      ),
    );
    if (isClosed) return null;

    return result.fold(
      (failure) {
        emit(state.copyWith(data: state.data!.copyWith(isRunning: false)));
        return failure;
      },
      (run) {
        emit(state.copyWith(
          data: state.data!.copyWith(isRunning: false, runResult: run),
        ));
        return null;
      },
    );
  }

  /// Runs once against the student's own input, with no judging.
  Future<Failure?> runCustom(String stdin) async {
    final current = state.data;
    if (isClosed || current == null || current.isRunning) return null;

    final draft = current.draft;
    emit(state.copyWith(
      data: current.copyWith(isRunning: true, clearRun: true),
    ));

    final result = await _runCustom(
      RunCodeParams(
        questionId: questionId,
        code: draft.code ?? '',
        language: draft.language ?? '',
        stdin: stdin,
      ),
    );
    if (isClosed) return null;

    return result.fold(
      (failure) {
        emit(state.copyWith(data: state.data!.copyWith(isRunning: false)));
        return failure;
      },
      (run) {
        emit(state.copyWith(
          data: state.data!.copyWith(isRunning: false, customResult: run),
        ));
        return null;
      },
    );
  }

  Future<Failure?> submit() async {
    final current = state.data;
    if (isClosed || current == null || !current.canSubmit) return null;

    emit(state.copyWith(data: current.copyWith(isSubmitting: true)));

    final result = await _submitAnswer(
      SubmitPracticeParams(
        questionId: questionId,
        draft: current.draft,
        timeTakenSec: DateTime.now().difference(_openedAt).inSeconds,
      ),
    );
    if (isClosed) return null;

    return await result.fold(
      (failure) async {
        emit(state.copyWith(data: state.data!.copyWith(isSubmitting: false)));
        return failure;
      },
      (submitted) async {
        emit(state.copyWith(
          data: state.data!.copyWith(
            isSubmitting: false,
            submitted: submitted.attempt,
            // The submit response carries the answer key, so the explanation
            // unlocks without waiting for the history to come back.
            revealed: submitted.question,
          ),
        ));
        await loadAttempts();
        return null;
      },
    );
  }

  /// Clears the result panel and the draft for another go. Attempts are
  /// unlimited, and only the first solve ever earns points.
  void retry() {
    final current = state.data;
    if (isClosed || current == null) return;
    _openedAt = DateTime.now();
    emit(state.copyWith(
      data: current.copyWith(
        draft: _seedDraft(current.question),
        clearRun: true,
        clearSubmitted: true,
      ),
    ));
  }

  /// Dismisses the result but keeps what was typed.
  void closeResult() {
    final current = state.data;
    if (isClosed || current == null) return;
    emit(state.copyWith(data: current.copyWith(clearSubmitted: true)));
  }

  /// The id to move to, or null when the bank has nowhere else to go.
  Future<String?> nextQuestionId({String mode = 'next'}) async {
    final current = state.data;
    if (isClosed || current == null || current.isNavigating) return null;

    emit(state.copyWith(data: current.copyWith(isNavigating: true)));
    final result = await _navigate(
      PracticeNavigateParams(questionId: questionId, mode: mode),
    );
    if (isClosed) return null;
    emit(state.copyWith(data: state.data!.copyWith(isNavigating: false)));

    return result.fold((_) => null, (id) => id);
  }

  /// Optimistic, like the list's: the star flips at once and reverts if the
  /// request fails.
  Future<Failure?> toggleBookmark() async {
    final current = state.data;
    if (isClosed || current == null) return null;

    final next = !current.detail.bookmarked;
    emit(state.copyWith(
      data: current.copyWith(detail: current.detail.withBookmark(next)),
    ));

    final result = await _setBookmarked(
      SetBookmarkedParams(questionId: questionId, bookmarked: next),
    );
    if (isClosed) return null;

    return result.fold(
      (failure) {
        emit(state.copyWith(
          data: state.data!.copyWith(
            detail: state.data!.detail.withBookmark(!next),
          ),
        ));
        return failure;
      },
      (_) => null,
    );
  }
}
