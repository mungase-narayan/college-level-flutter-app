import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/student/practice/domain/entities/practice_attempt.dart';
import 'package:college_level/features/student/practice/domain/entities/practice_question.dart';
import 'package:college_level/features/student/practice/domain/usecases/practice_usecases.dart';
import 'package:college_level/features/student/practice/presentation/bloc/practice_question_cubit.dart';

class _MockGetQuestion extends Mock implements GetPracticeQuestionUseCase {}

class _MockGetAttempts extends Mock implements GetPracticeAttemptsUseCase {}

class _MockSubmit extends Mock implements SubmitPracticeUseCase {}

class _MockRun extends Mock implements RunPracticeCodeUseCase {}

class _MockRunCustom extends Mock implements RunPracticeCustomUseCase {}

class _MockNavigate extends Mock implements NavigatePracticeUseCase {}

class _MockBookmark extends Mock implements SetBookmarkedUseCase {}

PracticeQuestion _question({
  String type = 'mcq',
  List<QuestionLanguageTemplate> templates = const [],
}) =>
    PracticeQuestion(
      id: 'q1',
      title: 'Reverse a linked list',
      type: type,
      difficulty: 'easy',
      points: 10,
      options: const [
        QuestionOption(id: 'a', text: '11'),
        QuestionOption(id: 'b', text: '13'),
      ],
      languageTemplates: templates,
    );

PracticeQuestionDetail _detail({
  String type = 'mcq',
  List<QuestionLanguageTemplate> templates = const [],
  bool bookmarked = false,
}) =>
    PracticeQuestionDetail(
      question: _question(type: type, templates: templates),
      stats: const PracticeQuestionStats(
        attempts: 0,
        correct: 0,
        attemptStatus: 'not_attempted',
      ),
      bookmarked: bookmarked,
    );

PracticeAttempt _attempt({
  int number = 1,
  String status = 'evaluated',
  bool? isCorrect = true,
}) =>
    PracticeAttempt(
      id: 's$number',
      questionId: 'q1',
      questionType: 'mcq',
      attempt: number,
      status: status,
      isCorrect: isCorrect,
      score: isCorrect == true ? 10 : 0,
      maxScore: 10,
      pointsAwarded: isCorrect == true && number == 1 ? 10 : 0,
    );

/// The solve screen renders four things that change as the student works: the
/// draft answer, the run output, the submitted result and the attempt history.
///
/// All four therefore have to live in the *emitted* state. The assessments
/// cubit shipped the opposite once — answers in a field beside the state — and
/// the screen silently stopped repainting, because bloc drops an emission equal
/// to the current state. `assessment_answer_state_test.dart` pins that lesson;
/// these tests pin it for the shape it would recur in here.
void main() {
  late _MockGetQuestion getQuestion;
  late _MockGetAttempts getAttempts;
  late _MockSubmit submit;
  late _MockRun run;
  late _MockRunCustom runCustom;
  late _MockNavigate navigate;
  late PracticeQuestionCubit cubit;

  List<SubmitPracticeParams> submitted() =>
      verify(() => submit(captureAny())).captured.cast<SubmitPracticeParams>();

  PracticeSolveState solve() => cubit.state.data!;

  setUpAll(() {
    registerFallbackValue(const IdParams('q1'));
    registerFallbackValue(
      const SubmitPracticeParams(questionId: 'q1', draft: PracticeAnswerDraft()),
    );
    registerFallbackValue(
      const RunCodeParams(questionId: 'q1', code: '', language: 'python'),
    );
    registerFallbackValue(const PracticeNavigateParams(questionId: 'q1'));
    registerFallbackValue(
      const SetBookmarkedParams(questionId: 'q1', bookmarked: true),
    );
  });

  setUp(() {
    getQuestion = _MockGetQuestion();
    getAttempts = _MockGetAttempts();
    submit = _MockSubmit();
    run = _MockRun();
    runCustom = _MockRunCustom();
    navigate = _MockNavigate();

    when(() => getAttempts(any())).thenAnswer(
      (_) async => Right<Failure, PracticeAttemptHistory>(
        PracticeAttemptHistory(question: _question()),
      ),
    );

    cubit = PracticeQuestionCubit(
      getQuestion: getQuestion,
      getAttempts: getAttempts,
      submitAnswer: submit,
      runCode: run,
      runCustom: runCustom,
      navigate: navigate,
      setBookmarked: _MockBookmark(),
      questionId: 'q1',
    );
  });

  tearDown(() => cubit.close());

  Future<void> loadWith(PracticeQuestionDetail detail) async {
    when(() => getQuestion(any())).thenAnswer(
      (_) async => Right<Failure, PracticeQuestionDetail>(detail),
    );
    await cubit.load();
  }

  group('the draft', () {
    test('a coding question starts from its first language template', () async {
      await loadWith(
        _detail(
          type: 'coding',
          templates: const [
            QuestionLanguageTemplate(
              language: 'python',
              starterCode: 'def solve():\n    pass',
            ),
            QuestionLanguageTemplate(language: 'cpp', starterCode: 'int main(){}'),
          ],
        ),
      );

      expect(solve().draft.language, 'python');
      expect(solve().draft.code, 'def solve():\n    pass');
    });

    test('an objective question starts empty — never pre-answered', () async {
      await loadWith(_detail());

      expect(solve().draft.selectedAnswers, isEmpty);
      expect(solve().canSubmit, isFalse);
    });

    test('changing it produces an unequal state, so the screen repaints',
        () async {
      await loadWith(_detail());
      final before = cubit.state;

      cubit.setDraft(const PracticeAnswerDraft(selectedAnswers: ['a']));

      // If the draft lived beside the state instead of in it, these would be
      // equal and bloc would drop the emission.
      expect(cubit.state, isNot(equals(before)));
      expect(solve().canSubmit, isTrue);
    });
  });

  group('submitting', () {
    setUp(() {
      when(() => submit(any())).thenAnswer(
        (_) async => Right<Failure, PracticeSubmitResult>(
          PracticeSubmitResult(
            attempt: _attempt(),
            question: _question(),
          ),
        ),
      );
    });

    test('sends only what the question type calls for', () async {
      await loadWith(_detail());
      cubit.setDraft(const PracticeAnswerDraft(selectedAnswers: ['a']));

      await cubit.submit();

      final params = submitted().single;
      expect(params.draft.selectedAnswers, ['a']);
      // An empty list would be sent as `[]` and read as an answer; null means
      // the field is simply absent.
      expect(params.draft.code, isNull);
      expect(params.timeTakenSec, isNotNull);
    });

    test('is refused while the draft cannot be submitted', () async {
      await loadWith(_detail());

      await cubit.submit();

      verifyNever(() => submit(any()));
    });

    test('keeps the result and the revealed answer key', () async {
      await loadWith(_detail());
      cubit.setDraft(const PracticeAnswerDraft(selectedAnswers: ['a']));

      await cubit.submit();

      expect(solve().submitted?.verdict, PracticeVerdict.correct);
      // The submit response carries the key, so the Explanation tab unlocks
      // without waiting for the history request.
      expect(solve().revealed, isNotNull);
    });

    test('retry clears the result and the draft; close keeps the draft',
        () async {
      await loadWith(_detail());
      cubit.setDraft(const PracticeAnswerDraft(selectedAnswers: ['a']));
      await cubit.submit();

      cubit.closeResult();
      expect(solve().submitted, isNull);
      expect(solve().draft.selectedAnswers, ['a']);

      cubit.retry();
      expect(solve().draft.selectedAnswers, isEmpty);
    });
  });

  group('the verdict', () {
    test('pending is not the same as wrong', () {
      expect(
        _attempt(status: 'pending_review', isCorrect: null).verdict,
        PracticeVerdict.pending,
      );
      expect(
        _attempt(isCorrect: false).verdict,
        PracticeVerdict.wrong,
      );
      expect(_attempt().verdict, PracticeVerdict.correct);
    });
  });

  group('running code', () {
    test('does not disturb the draft', () async {
      when(() => run(any())).thenAnswer(
        (_) async => const Right<Failure, PracticeCodingResult>(
          PracticeCodingResult(passed: 1, total: 2),
        ),
      );
      await loadWith(
        _detail(
          type: 'coding',
          templates: const [QuestionLanguageTemplate(language: 'python')],
        ),
      );
      cubit.setDraft(solve().draft.copyWith(code: 'print(1)'));

      await cubit.run();

      // A run is a preview, not an attempt: the code the student typed has to
      // survive it untouched.
      expect(solve().draft.code, 'print(1)');
      expect(solve().runResult?.passed, 1);
      expect(solve().isRunning, isFalse);
    });

    test('a failed run clears the busy flag so the button comes back',
        () async {
      when(() => run(any())).thenAnswer(
        (_) async => const Left<Failure, PracticeCodingResult>(NetworkFailure()),
      );
      await loadWith(
        _detail(
          type: 'coding',
          templates: const [QuestionLanguageTemplate(language: 'python')],
        ),
      );

      final failure = await cubit.run();

      expect(failure, isNotNull);
      expect(solve().isRunning, isFalse);
    });
  });

  group('navigation', () {
    test('reports null when the bank has nowhere else to go', () async {
      when(() => navigate(any())).thenAnswer(
        (_) async => const Right<Failure, String?>(null),
      );
      await loadWith(_detail());

      expect(await cubit.nextQuestionId(), isNull);
      expect(solve().isNavigating, isFalse);
    });

    test('passes the mode through', () async {
      when(() => navigate(any())).thenAnswer(
        (_) async => const Right<Failure, String?>('q2'),
      );
      await loadWith(_detail());

      expect(await cubit.nextQuestionId(mode: 'random'), 'q2');
      expect(
        verify(() => navigate(captureAny()))
            .captured
            .cast<PracticeNavigateParams>()
            .single
            .mode,
        'random',
      );
    });
  });

  group('loading', () {
    test('a question that will not load surfaces as a failure', () async {
      when(() => getQuestion(any())).thenAnswer(
        (_) async => const Left<Failure, PracticeQuestionDetail>(
          NetworkFailure(),
        ),
      );

      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
    });

    test('a history that will not load leaves the question usable', () async {
      when(() => getAttempts(any())).thenAnswer(
        (_) async => const Left<Failure, PracticeAttemptHistory>(
          NetworkFailure(),
        ),
      );
      await loadWith(_detail());

      // The student can still answer; only the Submissions tab is empty.
      expect(cubit.state.status, RemoteStatus.success);
      expect(solve().attempts, isEmpty);
      expect(solve().hasAttempted, isFalse);
    });
  });
}
