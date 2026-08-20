import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/student/practice/domain/entities/daily_challenge.dart';
import 'package:college_level/features/student/practice/domain/entities/practice_attempt.dart';
import 'package:college_level/features/student/practice/domain/entities/practice_question.dart';
import 'package:college_level/features/student/practice/domain/usecases/practice_usecases.dart';
import 'package:college_level/features/student/practice/presentation/bloc/daily_challenge_cubit.dart';
import 'package:college_level/features/student/practice/presentation/bloc/daily_solve_cubit.dart';
import 'package:college_level/features/student/rewards/domain/usecases/rewards_usecases.dart';

class _MockToday extends Mock implements GetDailyChallengeUseCase {}

class _MockCalendar extends Mock implements GetDailyCalendarUseCase {}

class _MockHistory extends Mock implements GetDailyChallengeHistoryUseCase {}

class _MockByDate extends Mock implements GetDailyChallengeByDateUseCase {}

class _MockSubmit extends Mock implements SubmitDailyChallengeUseCase {}

class _MockAttempts extends Mock implements GetPracticeAttemptsUseCase {}

class _MockRun extends Mock implements RunPracticeCodeUseCase {}

class _MockRunCustom extends Mock implements RunPracticeCustomUseCase {}

class _MockTicket extends Mock implements UseTimeTravelTicketUseCase {}

PracticeQuestion _question(String id) => PracticeQuestion(
      id: id,
      title: 'Question $id',
      type: 'mcq',
      difficulty: 'easy',
      points: 5,
      options: const [
        QuestionOption(id: 'a', text: 'A'),
        QuestionOption(id: 'b', text: 'B'),
      ],
    );

DailyChallenge _challenge({
  bool available = true,
  bool isOpen = true,
  bool ticketUnlocked = false,
  int tickets = 0,
  DailyChallengeCompletion? completion,
  int questions = 2,
}) =>
    DailyChallenge(
      available: available,
      isOpen: isOpen,
      streak: const DailyStreak(
        currentStreak: 3,
        totalPoints: 40,
        challengesCompleted: 4,
      ),
      set: const DailyChallengeSet(
        id: 'set-1',
        title: 'Tuesday set',
        date: '2026-08-18',
        totalQuestions: 2,
      ),
      questions: [for (var i = 0; i < questions; i++) _question('q$i')],
      completion: completion,
      availableTickets: tickets,
      timeTravelUnlocked: ticketUnlocked,
    );

DailyChallengeCompletion _completion({
  String status = 'in_progress',
  List<String> solved = const [],
  List<String> attempted = const [],
}) =>
    DailyChallengeCompletion(
      status: status,
      totalQuestions: 2,
      pointsEarned: status == 'completed' ? 10 : 0,
      solvedQuestionIds: solved,
      attemptedQuestionIds: attempted,
    );

/// The daily challenge has two rules the UI can get quietly wrong: the +10 is
/// for finishing the **set**, not a question, and a day outside its window can
/// only be answered if a Time Travel Ticket has re-opened it — a paid item, so
/// the gate has to be right in both directions.
void main() {
  group('completion counters', () {
    test('attempted and solved are different measures', () {
      // The server marks a challenge completed once every question has been
      // *attempted*, and pays the flat +10 only when every one was *solved*.
      // The dashboard card showed a solved-based bar beside the completed
      // badge, so a finished set with two wrong answers read "Done · 1/3".
      final completion = _completion(
        status: 'completed',
        solved: ['q0'],
        attempted: ['q0', 'q1'],
      );

      expect(completion.attemptedCount, 2);
      expect(completion.solvedCount, 1);
      expect(completion.attemptedFraction, 1.0);
      expect(completion.fraction, 0.5);
    });

    test('an empty set never divides by zero', () {
      const completion = DailyChallengeCompletion(
        status: 'in_progress',
        totalQuestions: 0,
        pointsEarned: 0,
      );

      expect(completion.attemptedFraction, 0);
      expect(completion.fraction, 0);
    });
  });

  group('the hub', () {
    late _MockToday today;
    late _MockCalendar calendar;
    late _MockHistory history;
    late DailyChallengeCubit cubit;

    setUpAll(() {
      registerFallbackValue(const MonthParams());
      registerFallbackValue(const NoParams());
    });

    setUp(() {
      today = _MockToday();
      calendar = _MockCalendar();
      history = _MockHistory();

      when(() => today(any())).thenAnswer(
        (_) async => Right<Failure, DailyChallenge>(_challenge()),
      );
      when(() => calendar(any())).thenAnswer(
        (_) async => const Right<Failure, DailyCalendar>(
          DailyCalendar(month: '2026-08'),
        ),
      );
      when(() => history(any())).thenAnswer(
        (_) async => const Right<Failure, List<DailyChallengeDay>>([]),
      );

      cubit = DailyChallengeCubit(
        getToday: today,
        getCalendar: calendar,
        getHistory: history,
      );
    });

    tearDown(() => cubit.close());

    test('asks the server for the current month rather than computing one',
        () async {
      await cubit.load();

      // The server buckets days in IST; a month derived from the device clock
      // would be wrong for part of every evening.
      expect(
        verify(() => calendar(captureAny())).captured.cast<MonthParams>().single.month,
        isNull,
      );
    });

    test('stepping a month wraps the year', () async {
      when(() => calendar(any())).thenAnswer(
        (_) async => const Right<Failure, DailyCalendar>(
          DailyCalendar(month: '2026-01'),
        ),
      );
      await cubit.load();

      await cubit.shiftMonth(-1);

      expect(
        verify(() => calendar(captureAny()))
            .captured
            .cast<MonthParams>()
            .last
            .month,
        '2025-12',
      );
    });

    test('a failed month keeps the one already on screen', () async {
      await cubit.load();
      expect(cubit.state.data!.calendar!.month, '2026-08');

      when(() => calendar(any())).thenAnswer(
        (_) async => const Left<Failure, DailyCalendar>(NetworkFailure()),
      );
      await cubit.shiftMonth(1);

      // Blanking the grid would read as "nothing posted that month", which is
      // a different and wrong statement.
      expect(cubit.state.data!.calendar!.month, '2026-08');
      expect(cubit.state.data!.isMonthLoading, isFalse);
    });

    test('a day with no challenge still loads the hub', () async {
      when(() => today(any())).thenAnswer(
        (_) async => Right<Failure, DailyChallenge>(
          _challenge(available: false, questions: 0),
        ),
      );

      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data!.today.available, isFalse);
    });
  });

  group('solving a day', () {
    late _MockByDate byDate;
    late _MockSubmit submit;
    late _MockTicket ticket;
    late _MockAttempts attempts;
    late DailySolveCubit cubit;

    DailySolveState solve() => cubit.state.data!;

    setUpAll(() {
      registerFallbackValue(const IdParams('2026-08-18'));
      registerFallbackValue(
        const DailySubmitParams(
          setId: 'set-1',
          questionId: 'q0',
          draft: PracticeAnswerDraft(),
        ),
      );
      registerFallbackValue(
        const RunCodeParams(questionId: 'q0', code: '', language: 'python'),
      );
    });

    setUp(() {
      byDate = _MockByDate();
      submit = _MockSubmit();
      ticket = _MockTicket();
      attempts = _MockAttempts();
      when(() => attempts(any())).thenAnswer(
        (_) async => Right<Failure, PracticeAttemptHistory>(
          PracticeAttemptHistory(question: _question('q0')),
        ),
      );

      cubit = DailySolveCubit(
        getByDate: byDate,
        getAttempts: attempts,
        submitAnswer: submit,
        runCode: _MockRun(),
        runCustom: _MockRunCustom(),
        useTicket: ticket,
        date: '2026-08-18',
      );
    });

    tearDown(() => cubit.close());

    Future<void> loadWith(DailyChallenge challenge) async {
      when(() => byDate(any())).thenAnswer(
        (_) async => Right<Failure, DailyChallenge>(challenge),
      );
      await cubit.load();
    }

    test('an open day can be answered; a closed one cannot', () async {
      await loadWith(_challenge());
      cubit.setDraft(const PracticeAnswerDraft(selectedAnswers: ['a']));
      expect(solve().canSubmit, isTrue);

      await loadWith(_challenge(isOpen: false));
      cubit.setDraft(const PracticeAnswerDraft(selectedAnswers: ['a']));
      expect(solve().canAttempt, isFalse);
      expect(solve().canSubmit, isFalse);
    });

    test('a ticket re-opens a closed day', () async {
      await loadWith(_challenge(isOpen: false, ticketUnlocked: true));
      cubit.setDraft(const PracticeAnswerDraft(selectedAnswers: ['a']));

      // The window is still shut — the ticket is the only thing letting this
      // through, and the server enforces exactly the same condition.
      expect(solve().canAttempt, isTrue);
      expect(solve().canSubmit, isTrue);
    });

    test('submitting carries the set and the question', () async {
      when(() => submit(any())).thenAnswer(
        (_) async => Right<Failure, DailyChallengeSubmitResult>(
          DailyChallengeSubmitResult(
            attempt: const PracticeAttempt(
              id: 's1',
              questionId: 'q0',
              questionType: 'mcq',
              attempt: 1,
              status: 'evaluated',
              isCorrect: true,
            ),
            question: _question('q0'),
            completion: _completion(solved: ['q0'], attempted: ['q0']),
          ),
        ),
      );
      await loadWith(_challenge());
      cubit.setDraft(const PracticeAnswerDraft(selectedAnswers: ['a']));

      await cubit.submit();

      final params =
          verify(() => submit(captureAny())).captured.cast<DailySubmitParams>().single;
      expect(params.setId, 'set-1');
      expect(params.questionId, 'q0');
      expect(params.draft.selectedAnswers, ['a']);
    });

    test('the response advances the set without another request', () async {
      when(() => submit(any())).thenAnswer(
        (_) async => Right<Failure, DailyChallengeSubmitResult>(
          DailyChallengeSubmitResult(
            attempt: const PracticeAttempt(
              id: 's2',
              questionId: 'q1',
              questionType: 'mcq',
              attempt: 1,
              status: 'evaluated',
              isCorrect: true,
            ),
            question: _question('q1'),
            // The last of two — the set is now done.
            completion: _completion(
              status: 'completed',
              solved: ['q0', 'q1'],
              attempted: ['q0', 'q1'],
            ),
          ),
        ),
      );
      await loadWith(
        _challenge(completion: _completion(solved: ['q0'], attempted: ['q0'])),
      );
      cubit.select(1);
      cubit.setDraft(const PracticeAnswerDraft(selectedAnswers: ['a']));

      await cubit.submit();

      expect(solve().isComplete, isTrue);
      expect(solve().solvedCount, 2);
      // 10 for the set, not per question.
      expect(solve().completion!.pointsEarned, 10);
      verify(() => byDate(any())).called(1);
    });

    test('changing question clears the last one\'s answer and result', () async {
      await loadWith(_challenge());
      cubit.setDraft(const PracticeAnswerDraft(selectedAnswers: ['a']));

      cubit.select(1);

      expect(solve().index, 1);
      expect(solve().draft.selectedAnswers, isEmpty);
      expect(solve().result, isNull);
    });

    test('a question answered earlier comes back as a review, not a blank form',
        () async {
      when(() => attempts(any())).thenAnswer(
        (_) async => Right<Failure, PracticeAttemptHistory>(
          PracticeAttemptHistory(
            question: PracticeQuestion(
              id: 'q0',
              title: 'Question q0',
              type: 'mcq',
              difficulty: 'easy',
              points: 5,
              options: const [
                QuestionOption(id: 'a', text: 'A'),
                QuestionOption(id: 'b', text: 'B'),
              ],
              // Only the review payload carries the key.
              answers: const ['b'],
            ),
            attempts: const [
              PracticeAttempt(
                id: 's1',
                questionId: 'q0',
                questionType: 'mcq',
                attempt: 1,
                status: 'evaluated',
                isCorrect: false,
                selectedAnswers: ['a'],
              ),
            ],
          ),
        ),
      );

      await loadWith(
        _challenge(completion: _completion(attempted: ['q0'])),
      );
      // The history request is fired without awaiting, so let it land.
      await Future<void>.delayed(Duration.zero);

      // Coming back to an answered question used to show an empty form with a
      // Submit button, as if the work had never happened.
      expect(solve().result, isNotNull);
      expect(solve().result!.selectedAnswers, ['a']);
      // And without the revealed question there is no way to show which option
      // was right.
      expect(solve().revealed!.answers, ['b']);
    });

    test('a question never attempted keeps its form', () async {
      await loadWith(_challenge());
      await Future<void>.delayed(Duration.zero);

      expect(solve().result, isNull);
      verifyNever(() => attempts(any()));
    });

    test('redeeming a ticket reloads the day', () async {
      await loadWith(_challenge(isOpen: false, tickets: 1));
      when(() => ticket(any()))
          .thenAnswer((_) async => const Right<Failure, Unit>(unit));

      await cubit.redeemTicket();

      // The reload is what flips `timeTravelUnlocked` — nothing is assumed
      // locally about a spend that the server owns.
      verify(() => byDate(any())).called(2);
      expect(solve().isRedeeming, isFalse);
    });

    test('a failed redeem leaves the day closed and the flag clear', () async {
      await loadWith(_challenge(isOpen: false, tickets: 1));
      when(() => ticket(any())).thenAnswer(
        (_) async => const Left<Failure, Unit>(NetworkFailure()),
      );

      final failure = await cubit.redeemTicket();

      expect(failure, isNotNull);
      expect(solve().isRedeeming, isFalse);
      expect(solve().canAttempt, isFalse);
    });
  });
}
