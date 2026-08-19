import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../rewards/domain/usecases/rewards_usecases.dart';
import '../../domain/entities/daily_challenge.dart';
import '../../domain/entities/practice_attempt.dart';
import '../../domain/entities/practice_question.dart';
import '../../domain/usecases/practice_usecases.dart';

/// One day's challenge, mid-solve.
class DailySolveState extends Equatable {
  const DailySolveState({
    required this.challenge,
    this.index = 0,
    this.draft = const PracticeAnswerDraft(),
    this.result,
    this.revealed,
    this.runResult,
    this.customResult,
    this.isRunning = false,
    this.isSubmitting = false,
    this.isRedeeming = false,
  });

  final DailyChallenge challenge;

  /// Which question is showing. The set is small and arrives whole, so
  /// navigation is local.
  final int index;

  final PracticeAnswerDraft draft;

  /// The attempt just submitted for [current], if any.
  final PracticeAttempt? result;

  /// That question with its answer key, as the submit response returned it.
  final PracticeQuestion? revealed;

  final PracticeCodingResult? runResult;
  final PracticeCustomRunResult? customResult;

  final bool isRunning;
  final bool isSubmitting;
  final bool isRedeeming;

  List<PracticeQuestion> get questions => challenge.questions;

  PracticeQuestion? get current =>
      index >= 0 && index < questions.length ? questions[index] : null;

  DailyChallengeCompletion? get completion => challenge.completion;

  /// Whether answers can be sent at all — the window is open, or a ticket has
  /// re-opened it. The same condition the submit endpoint enforces.
  bool get canAttempt => challenge.canSolve;

  Set<String> get solvedIds =>
      (completion?.solvedQuestionIds ?? const <String>[]).toSet();

  Set<String> get attemptedIds =>
      (completion?.attemptedQuestionIds ?? const <String>[]).toSet();

  int get solvedCount => solvedIds.length;

  bool get isComplete => completion?.status == 'completed';

  bool get canSubmit {
    final question = current;
    return question != null &&
        canAttempt &&
        !isSubmitting &&
        draft.canSubmit(question);
  }

  DailySolveState copyWith({
    DailyChallenge? challenge,
    int? index,
    PracticeAnswerDraft? draft,
    PracticeAttempt? result,
    PracticeQuestion? revealed,
    PracticeCodingResult? runResult,
    PracticeCustomRunResult? customResult,
    bool? isRunning,
    bool? isSubmitting,
    bool? isRedeeming,
    bool clearResult = false,
    bool clearRun = false,
  }) =>
      DailySolveState(
        challenge: challenge ?? this.challenge,
        index: index ?? this.index,
        draft: draft ?? this.draft,
        result: clearResult ? null : (result ?? this.result),
        revealed: clearResult ? null : (revealed ?? this.revealed),
        runResult: clearRun ? null : (runResult ?? this.runResult),
        customResult: clearRun ? null : (customResult ?? this.customResult),
        isRunning: isRunning ?? this.isRunning,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isRedeeming: isRedeeming ?? this.isRedeeming,
      );

  @override
  List<Object?> get props => [
        challenge,
        index,
        draft,
        result,
        revealed,
        runResult,
        customResult,
        isRunning,
        isSubmitting,
        isRedeeming,
      ];
}

/// Solving one day of the daily challenge.
///
/// Unlike a quiz, each question is submitted on its own and the set's progress
/// comes back with every answer.
class DailySolveCubit extends Cubit<RemoteState<DailySolveState>> {
  DailySolveCubit({
    required GetDailyChallengeByDateUseCase getByDate,
    required GetPracticeAttemptsUseCase getAttempts,
    required SubmitDailyChallengeUseCase submitAnswer,
    required RunPracticeCodeUseCase runCode,
    required RunPracticeCustomUseCase runCustom,
    required UseTimeTravelTicketUseCase useTicket,
    required this.date,
  })  : _getByDate = getByDate,
        _getAttempts = getAttempts,
        _submitAnswer = submitAnswer,
        _runCode = runCode,
        _runCustom = runCustom,
        _useTicket = useTicket,
        super(const RemoteState());

  final GetDailyChallengeByDateUseCase _getByDate;
  final GetPracticeAttemptsUseCase _getAttempts;
  final SubmitDailyChallengeUseCase _submitAnswer;
  final RunPracticeCodeUseCase _runCode;
  final RunPracticeCustomUseCase _runCustom;
  final UseTimeTravelTicketUseCase _useTicket;

  /// `YYYY-MM-DD`, as the server spells it.
  final String date;

  DateTime _openedAt = DateTime.now();

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _getByDate(IdParams(date));
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (challenge) {
        // Keep the student where they were across a reload — redeeming a
        // ticket should not throw them back to question one.
        final index = state.data?.index ?? 0;
        final safeIndex = index < challenge.questions.length ? index : 0;
        _openedAt = DateTime.now();
        emit(RemoteState(
          status: RemoteStatus.success,
          data: DailySolveState(
            challenge: challenge,
            index: safeIndex,
            draft: _seedDraft(challenge, safeIndex),
          ),
        ));
        unawaited(_loadReview());
      },
    );
  }

  PracticeAnswerDraft _seedDraft(DailyChallenge challenge, int index) {
    final questions = challenge.questions;
    if (index >= questions.length) return const PracticeAnswerDraft();
    final question = questions[index];
    if (!question.isCoding || question.languageTemplates.isEmpty) {
      return const PracticeAnswerDraft();
    }
    final first = question.languageTemplates.first;
    return PracticeAnswerDraft(
      language: first.language,
      code: first.initialCode,
    );
  }

  /// Moves to another question, clearing everything that belonged to the last
  /// one — its draft, its run output and its result.
  void select(int index) {
    final current = state.data;
    if (isClosed || current == null) return;
    if (index < 0 || index >= current.questions.length) return;

    _openedAt = DateTime.now();
    emit(state.copyWith(
      data: current.copyWith(
        index: index,
        draft: _seedDraft(current.challenge, index),
        clearResult: true,
        clearRun: true,
      ),
    ));
    unawaited(_loadReview());
  }

  /// Restores the review for a question that was already answered — on an
  /// earlier visit, or on another device.
  ///
  /// Without this, coming back to a solved question showed an empty form and a
  /// Submit button, as if the work had never happened. The attempts endpoint is
  /// also the only thing that hands over the answer key, so this is what makes
  /// "which option was right" visible at all.
  Future<void> _loadReview() async {
    final current = state.data;
    final question = current?.current;
    if (isClosed || current == null || question == null) return;

    // Nothing to restore for a question never attempted, and nothing to
    // restore over an answer just given.
    if (current.result != null) return;
    if (!current.attemptedIds.contains(question.id)) return;

    final result = await _getAttempts(IdParams(question.id));
    if (isClosed) return;

    result.fold(
      // A history that will not load leaves the form in place; the student can
      // still answer, which is better than a screen that shows nothing.
      (_) {},
      (history) {
        final data = state.data;
        // The student may have moved on while this was in flight.
        if (data == null || data.current?.id != question.id) return;
        if (history.attempts.isEmpty) return;

        emit(state.copyWith(
          data: data.copyWith(
            result: history.attempts.first,
            revealed: history.question,
          ),
        ));
      },
    );
  }

  void setDraft(PracticeAnswerDraft draft) {
    final current = state.data;
    if (isClosed || current == null) return;
    emit(state.copyWith(data: current.copyWith(draft: draft)));
  }

  /// Runs code against the *practice* sample cases — the run endpoints take a
  /// question id, so they work here unchanged.
  Future<Failure?> run() async {
    final current = state.data;
    final question = current?.current;
    if (isClosed || current == null || question == null || current.isRunning) {
      return null;
    }

    emit(state.copyWith(data: current.copyWith(isRunning: true, clearRun: true)));
    final result = await _runCode(
      RunCodeParams(
        questionId: question.id,
        code: current.draft.code ?? '',
        language: current.draft.language ?? '',
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

  Future<Failure?> runCustom(String stdin) async {
    final current = state.data;
    final question = current?.current;
    if (isClosed || current == null || question == null || current.isRunning) {
      return null;
    }

    emit(state.copyWith(data: current.copyWith(isRunning: true, clearRun: true)));
    final result = await _runCustom(
      RunCodeParams(
        questionId: question.id,
        code: current.draft.code ?? '',
        language: current.draft.language ?? '',
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
    final question = current?.current;
    final set = current?.challenge.set;
    if (isClosed || current == null || question == null || set == null) {
      return null;
    }
    if (!current.canSubmit) return null;

    emit(state.copyWith(data: current.copyWith(isSubmitting: true)));

    final result = await _submitAnswer(
      DailySubmitParams(
        setId: set.id,
        questionId: question.id,
        draft: current.draft,
        timeTakenSec: DateTime.now().difference(_openedAt).inSeconds,
      ),
    );
    if (isClosed) return null;

    return result.fold(
      (failure) {
        emit(state.copyWith(data: state.data!.copyWith(isSubmitting: false)));
        return failure;
      },
      (submitted) {
        final data = state.data!;
        emit(state.copyWith(
          data: data.copyWith(
            isSubmitting: false,
            result: submitted.attempt,
            revealed: submitted.question,
            // The response carries the set's new progress, so the palette and
            // the completion state update without another request.
            challenge: submitted.completion == null
                ? data.challenge
                : _withCompletion(data.challenge, submitted.completion!),
          ),
        ));
        return null;
      },
    );
  }

  /// Clears the result so the student can answer again. Only offered while the
  /// window is open.
  void retry() {
    final current = state.data;
    if (isClosed || current == null) return;
    _openedAt = DateTime.now();
    emit(state.copyWith(
      data: current.copyWith(
        draft: _seedDraft(current.challenge, current.index),
        clearResult: true,
        clearRun: true,
      ),
    ));
  }

  /// Spends a Time Travel Ticket to re-open this day, then reloads it.
  Future<Failure?> redeemTicket() async {
    final current = state.data;
    final set = current?.challenge.set;
    if (isClosed || current == null || set == null || current.isRedeeming) {
      return null;
    }

    emit(state.copyWith(data: current.copyWith(isRedeeming: true)));
    final result = await _useTicket(IdParams(set.id));
    if (isClosed) return null;

    return await result.fold(
      (failure) async {
        emit(state.copyWith(data: state.data!.copyWith(isRedeeming: false)));
        return failure;
      },
      (_) async {
        // The reload is what flips `timeTravelUnlocked`, and with it the
        // screen out of review mode.
        await load(refresh: true);
        return null;
      },
    );
  }

  DailyChallenge _withCompletion(
    DailyChallenge challenge,
    DailyChallengeCompletion completion,
  ) =>
      DailyChallenge(
        available: challenge.available,
        isOpen: challenge.isOpen,
        streak: challenge.streak,
        set: challenge.set,
        questions: challenge.questions,
        completion: completion,
        availableTickets: challenge.availableTickets,
        timeTravelUnlocked: challenge.timeTravelUnlocked,
      );
}
