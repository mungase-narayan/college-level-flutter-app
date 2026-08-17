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

  /// Files attached to a submission-type assessment.
  ///
  /// A side field like [_note] rather than emitted state, and for the same
  /// reason the class doc gives for *not* doing this with answers: the form
  /// owns the live list and renders from its own copy, so nothing here is read
  /// during a build. What this field exists for is the **auto-submit** path —
  /// when the clock runs out or the violation limit trips, the runner calls
  /// [submit] directly and the student's attachments have to go with it.
  List<String>? _fileIds;

  /// True when this assessment is answered with a note and files rather than
  /// with questions.
  bool get _isSubmissionType => state.data?.questions.isEmpty ?? false;

  /// Pushes the current draft to the server. Safe to call repeatedly.
  Future<Failure?> flushDraft() async {
    if (isClosed) return null;

    // A question-type attempt with nothing answered has genuinely nothing to
    // send. A submission-type one always sends: the server reads an absent
    // `fileIds` as "keep what you had", so a student who removes their last
    // attachment and taps Save draft would otherwise get a success toast for a
    // request that was never made — and the file would still be attached.
    if (!_isSubmissionType && draft.isEmpty) return null;

    final result = await _saveAttempt(_payload());
    return result.fold((failure) => failure, (_) => null);
  }

  /// The body for a save or a submit.
  ///
  /// `note` and `fileIds` are sent **only** for a submission-type assessment,
  /// and then unconditionally — an empty string and an empty list are how a
  /// cleared note and a removed attachment are expressed. A question-type
  /// attempt omits both so it can never clobber them.
  AttemptPayload _payload({bool autoSubmitted = false}) => AttemptPayload(
        assessmentId: assessmentId,
        answers: draft.isEmpty ? null : _answersPayload(),
        note: _isSubmissionType ? (_note ?? '') : null,
        fileIds: _isSubmissionType ? (_fileIds ?? const []) : null,
        autoSubmitted: autoSubmitted,
      );

  /// Records the submission-type body so both save and submit carry it.
  void setNote(String note) => _note = note;

  /// Records the attachment list so both save and submit carry it — including
  /// an auto-submit the student never taps.
  void setFileIds(List<String> fileIds) =>
      _fileIds = List<String>.unmodifiable(fileIds);

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
    final result = await _submitAttempt(_payload(autoSubmitted: autoSubmitted));
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
