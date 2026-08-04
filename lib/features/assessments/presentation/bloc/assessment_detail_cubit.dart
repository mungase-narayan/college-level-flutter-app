import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/assessment_detail.dart';
import '../../domain/usecases/attempt_usecases.dart';

/// Drives the assignment/quiz detail screen: intro → attempt → review.
///
/// Live edits live in [draft], which is what the palette and the answered count
/// read. It is flushed to the server on a debounce (the React page autosaves
/// via `PATCH .../submission`) and again on submit, so a dropped connection
/// costs at most the debounce window.
class AssessmentDetailCubit extends Cubit<RemoteState<AssessmentDetail>> {
  AssessmentDetailCubit({
    required GetAssessmentDetailUseCase getDetail,
    required StartAttemptUseCase startAttempt,
    required SaveAttemptUseCase saveAttempt,
    required SubmitAttemptUseCase submitAttempt,
    required this.assessmentId,
  })  : _getDetail = getDetail,
        _startAttempt = startAttempt,
        _saveAttempt = saveAttempt,
        _submitAttempt = submitAttempt,
        super(const RemoteState());

  final GetAssessmentDetailUseCase _getDetail;
  final StartAttemptUseCase _startAttempt;
  final SaveAttemptUseCase _saveAttempt;
  final SubmitAttemptUseCase _submitAttempt;
  final String assessmentId;

  Timer? _autosave;
  bool _isBusy = false;

  bool get isBusy => _isBusy;

  /// Live answers by `assessmentQuestionId`.
  ///
  /// Derived from the emitted state rather than held in a field beside it — a
  /// field would let an edit change what the UI reads without changing state
  /// equality, and bloc drops emissions equal to the current state, so the
  /// screen would not repaint until something else rebuilt it.
  Map<String, QuestionAnswer> get draft =>
      state.data?.answersByQuestion ?? const {};

  int get answeredCount => draft.values.where((a) => a.isAnswered).length;

  @override
  Future<void> close() {
    _autosave?.cancel();
    return super.close();
  }

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _getDetail(IdParams(assessmentId));
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      // `detail.answers` already carries whatever the server had saved, so a
      // resumed attempt shows the student's earlier answers with no seeding.
      (detail) => emit(RemoteState(status: RemoteStatus.success, data: detail)),
    );
  }

  /// Records an answer and schedules an autosave.
  ///
  /// The answer goes into the emitted [AssessmentDetail], so the option list,
  /// the palette, and the answered count all repaint on the same frame.
  void setAnswer(AssessmentQuestion question, QuestionAnswer answer) {
    final detail = state.data;
    if (detail == null || isClosed) return;

    emit(
      RemoteState(
        status: RemoteStatus.success,
        data: detail.withAnswer(answer),
      ),
    );

    _autosave?.cancel();
    _autosave = Timer(const Duration(seconds: 2), flushDraft);
  }

  /// The note body for a submission-type assessment (one with no questions).
  String? _note;

  /// Pushes the current draft to the server. Safe to call repeatedly.
  Future<Failure?> flushDraft() async {
    if (isClosed || (draft.isEmpty && (_note ?? '').isEmpty)) return null;
    final result = await _saveAttempt(
      AttemptPayload(
        assessmentId: assessmentId,
        answers: draft.isEmpty ? null : _answersPayload(),
        note: _note,
      ),
    );
    return result.fold((failure) => failure, (_) => null);
  }

  /// Records the submission-type body so both save and submit carry it.
  void setNote(String note) => _note = note;

  /// Saves a submission-type draft — a free-text body rather than answers.
  Future<Failure?> flushDraftWithNote(String note) {
    setNote(note);
    return flushDraft();
  }

  /// `POST .../submissions` then reload, which flips the screen to the runner.
  Future<Failure?> start() async {
    if (_isBusy) return null;
    _isBusy = true;
    final result = await _startAttempt(IdParams(assessmentId));
    _isBusy = false;

    final failure = result.fold((f) => f, (_) => null);
    if (failure == null) await load(refresh: true);
    return failure;
  }

  /// Flushes the draft, submits, then reloads into the review screen.
  Future<Failure?> submit({bool autoSubmitted = false}) async {
    if (_isBusy) return null;
    _isBusy = true;

    _autosave?.cancel();
    final result = await _submitAttempt(
      AttemptPayload(
        assessmentId: assessmentId,
        answers: draft.isEmpty ? null : _answersPayload(),
        note: _note,
        autoSubmitted: autoSubmitted,
      ),
    );
    _isBusy = false;

    final failure = result.fold((f) => f, (_) => null);
    if (failure == null) await load(refresh: true);
    return failure;
  }

  /// The wire shape the save/submit endpoints expect — one entry per answered
  /// question, keyed by `assessmentQuestionId`.
  List<Map<String, dynamic>> _answersPayload() => [
        for (final entry in draft.entries)
          {
            'assessmentQuestionId': entry.key,
            'questionId': entry.value.questionId,
            'selectedAnswers': entry.value.selectedAnswers,
            'answerText': entry.value.answerText,
            'code': entry.value.code,
            'language': entry.value.language,
          },
      ];
}
