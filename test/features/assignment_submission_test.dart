import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/student/assessments/domain/entities/assessment_detail.dart';
import 'package:college_level/features/student/assessments/domain/entities/student_assessment.dart';
import 'package:college_level/features/student/assessments/domain/usecases/attempt_usecases.dart';
import 'package:college_level/features/student/assessments/presentation/bloc/assessment_detail_cubit.dart';

class _MockGetDetail extends Mock implements GetAssessmentDetailUseCase {}

class _MockStart extends Mock implements StartAttemptUseCase {}

class _MockSave extends Mock implements SaveAttemptUseCase {}

class _MockSubmit extends Mock implements SubmitAttemptUseCase {}

/// A submission-type assessment: no questions, a note and files instead.
AssessmentDetail _submissionDetail({
  String? note,
  List<String> fileIds = const [],
}) =>
    AssessmentDetail(
      assessment: const StudentAssessment(
        id: 'a1',
        title: 'Essay on sorting',
        category: 'course_assignment',
        type: 'submission',
        totalMarks: 20,
        resultsPublished: false,
      ),
      resultsPublished: false,
      submission: AttemptSubmission(
        id: 's1',
        status: 'in_progress',
        attempt: 1,
        note: note,
        fileIds: fileIds,
      ),
    );

/// A question-type assessment, for the contrast cases.
AssessmentDetail _questionDetail() => const AssessmentDetail(
      assessment: StudentAssessment(
        id: 'a2',
        title: 'Quiz',
        category: 'quiz',
        type: 'questions',
        totalMarks: 10,
        resultsPublished: false,
      ),
      resultsPublished: false,
      questions: [
        AssessmentQuestion(
          assessmentQuestionId: 'aq1',
          questionId: 'q1',
          title: 'Pick one',
          type: 'mcq',
          points: 1,
        ),
      ],
      submission: AttemptSubmission(id: 's2', status: 'in_progress', attempt: 1),
    );

/// Handing in an assignment from a phone means files, and the file half of that
/// contract has two traps the server sets:
///
/// 1. `PATCH .../submission` reads an **absent** `fileIds` as "keep what you
///    had", so removing the last attachment can only be expressed as `[]` — a
///    request that is skipped, or one that omits the key, silently keeps it.
/// 2. The auto-submit path (time expiry, violation limit) submits without the
///    form's involvement, so whatever the student attached has to be reachable
///    from the cubit or it is lost.
void main() {
  late _MockGetDetail getDetail;
  late _MockSave save;
  late _MockSubmit submit;
  late AssessmentDetailCubit cubit;

  List<AttemptPayload> savedPayloads() =>
      verify(() => save(captureAny())).captured.cast<AttemptPayload>();

  List<AttemptPayload> submittedPayloads() =>
      verify(() => submit(captureAny())).captured.cast<AttemptPayload>();

  /// Loads [detail] into the cubit, as `load()` would.
  Future<void> loadWith(AssessmentDetail detail) async {
    when(() => getDetail(any())).thenAnswer(
      (_) async => Right<Failure, AssessmentDetail>(detail),
    );
    await cubit.load();
  }

  setUpAll(() {
    registerFallbackValue(const AttemptPayload(assessmentId: 'a1'));
    registerFallbackValue(const IdParams('a1'));
  });

  setUp(() {
    getDetail = _MockGetDetail();
    save = _MockSave();
    submit = _MockSubmit();
    when(() => save(any())).thenAnswer((_) async => const Right<Failure, Unit>(unit));
    when(() => submit(any())).thenAnswer((_) async => const Right<Failure, Unit>(unit));
    cubit = AssessmentDetailCubit(
      getDetail: getDetail,
      startAttempt: _MockStart(),
      saveAttempt: save,
      submitAttempt: submit,
      assessmentId: 'a1',
    );
  });

  tearDown(() => cubit.close());

  group('saving a submission-type draft', () {
    test('a files-only draft is actually sent', () async {
      await loadWith(_submissionDetail());
      cubit.setFileIds(['f1']);

      await cubit.flushDraft();

      // The old guard returned early when the answers and the note were both
      // empty — the student got "Draft saved" for a request never made.
      final payloads = savedPayloads();
      expect(payloads, hasLength(1));
      expect(payloads.single.fileIds, ['f1']);
    });

    test('removing the last file sends an empty list, not nothing', () async {
      await loadWith(_submissionDetail(fileIds: const ['f1']));
      cubit.setFileIds(const []);

      await cubit.flushDraft();

      final payloads = savedPayloads();
      expect(payloads, hasLength(1));
      // Null would be dropped from the body, and the server reads an absent
      // key as "keep what you had" — the file would still be attached.
      expect(payloads.single.fileIds, isEmpty);
      expect(payloads.single.fileIds, isNotNull);
    });

    test('a cleared note is sent as an empty string', () async {
      await loadWith(_submissionDetail(note: 'draft text'));
      cubit.setNote('');

      await cubit.flushDraft();

      expect(savedPayloads().single.note, '');
    });
  });

  group('submitting', () {
    test('carries the files the student attached', () async {
      await loadWith(_submissionDetail());
      cubit.setNote('My answer');
      cubit.setFileIds(['f1', 'f2']);

      await cubit.submit();

      final payload = submittedPayloads().single;
      expect(payload.fileIds, ['f1', 'f2']);
      expect(payload.note, 'My answer');
    });

    test('an auto-submit carries them too', () async {
      await loadWith(_submissionDetail());
      cubit.setFileIds(['f1']);

      // Time expiry and the violation limit submit without the form asking —
      // this is why the list is mirrored onto the cubit at all.
      await cubit.submit(autoSubmitted: true);

      final payload = submittedPayloads().single;
      expect(payload.autoSubmitted, isTrue);
      expect(payload.fileIds, ['f1']);
    });

    test('keeps the attachments after a failed submit, so a retry has them',
        () async {
      await loadWith(_submissionDetail());
      cubit.setFileIds(['f1']);
      when(() => submit(any())).thenAnswer(
        (_) async => const Left<Failure, Unit>(NetworkFailure()),
      );

      final failure = await cubit.submit();
      expect(failure, isNotNull);

      when(() => submit(any())).thenAnswer(
        (_) async => const Right<Failure, Unit>(unit),
      );
      await cubit.submit();

      expect(submittedPayloads().last.fileIds, ['f1']);
    });
  });

  group('a question-type attempt', () {
    test('never sends note or fileIds, so it cannot clobber them', () async {
      await loadWith(_questionDetail());
      cubit.setAnswer(
        const AssessmentQuestion(
          assessmentQuestionId: 'aq1',
          questionId: 'q1',
          title: 'Pick one',
          type: 'mcq',
          points: 1,
        ),
        const QuestionAnswer(
          assessmentQuestionId: 'aq1',
          questionId: 'q1',
          questionType: 'mcq',
          selectedAnswers: ['a'],
        ),
      );

      await cubit.flushDraft();

      final payload = savedPayloads().single;
      expect(payload.fileIds, isNull);
      expect(payload.note, isNull);
    });

    test('with nothing answered still short-circuits', () async {
      await loadWith(_questionDetail());

      await cubit.flushDraft();

      verifyNever(() => save(any()));
    });
  });
}
