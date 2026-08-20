import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/config/injection_modules/service_locator.dart';
import 'package:college_level/core/config/theme/app_theme.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/student/assessments/domain/entities/assessment_detail.dart';
import 'package:college_level/features/student/assessments/domain/entities/student_assessment.dart';
import 'package:college_level/features/student/assessments/domain/usecases/attempt_usecases.dart';
import 'package:college_level/features/student/assessments/presentation/bloc/assessment_detail_cubit.dart';
import 'package:college_level/features/student/assessments/presentation/widgets/attempt_runner.dart';

import 'package:college_level/core/design/glass.dart';

class _MockGetDetail extends Mock implements GetAssessmentDetailUseCase {}

class _MockStart extends Mock implements StartAttemptUseCase {}

class _MockSave extends Mock implements SaveAttemptUseCase {}

class _MockSubmit extends Mock implements SubmitAttemptUseCase {}

class _MockReport extends Mock implements RecordProctorEventUseCase {}

/// Proctoring is the one feature where a bug costs a student their attempt, so
/// each rule is pinned rather than left to the runner's shape.
///
/// The rules, as the web defines them and the server enforces them:
///
/// * A signal is watched **only** when the teacher switched it on. An
///   assessment marked proctored with tab-switch off must not count the student
///   backgrounding the app.
/// * The server owns the tally. The client seeds from the attempt's own
///   `violationCount` so a resumed session continues where it left off, then
///   takes whatever each report answers with — it never increments locally.
/// * `shouldAutoSubmit` submits the attempt exactly once, however many signals
///   land afterwards.
/// * A trusted OS interaction (the file picker) is not a violation.
AssessmentDetail _detail({
  bool isProctored = true,
  ProctoringConfig? config = const ProctoringConfig(tabSwitch: true),
  int? maxViolations = 3,
  int violationCount = 0,
}) =>
    AssessmentDetail(
      assessment: StudentAssessment(
        id: 'a1',
        title: 'Quiz',
        category: 'quiz',
        type: 'questions',
        totalMarks: 10,
        resultsPublished: false,
        isProctored: isProctored,
        maxViolations: maxViolations,
        proctoringConfig: config,
      ),
      resultsPublished: false,
      questions: const [
        AssessmentQuestion(
          assessmentQuestionId: 'aq1',
          questionId: 'q1',
          title: 'Pick one',
          type: 'mcq',
          points: 1,
          options: [AnswerOption(id: 'o1', text: 'A')],
        ),
      ],
      submission: AttemptSubmission(
        id: 's1',
        status: 'in_progress',
        attempt: 1,
        violationCount: violationCount,
      ),
    );

void main() {
  late _MockReport report;
  late _MockSubmit submit;
  late _MockGetDetail getDetail;
  late AssessmentDetailCubit cubit;

  setUpAll(() {
    registerFallbackValue(
      ProctorEventParams(
        assessmentId: 'a',
        eventType: 'x',
        occurredAt: DateTime(2020),
      ),
    );
    registerFallbackValue(const AttemptPayload(assessmentId: 'a'));
    registerFallbackValue(const IdParams('a'));
  });

  setUp(() {
    report = _MockReport();
    submit = _MockSubmit();
    getDetail = _MockGetDetail();

    when(() => submit(any())).thenAnswer((_) async => const Right(unit));

    if (sl.isRegistered<RecordProctorEventUseCase>()) {
      sl.unregister<RecordProctorEventUseCase>();
    }
    sl.registerSingleton<RecordProctorEventUseCase>(report);
  });

  tearDown(() async {
    await cubit.close();
    sl.unregister<RecordProctorEventUseCase>();
  });

  /// Pumps the runner with [detail] already loaded, so the attempt is live.
  ///
  /// Routed through a real [GoRouter], with the quiz list underneath it, so the
  /// attempt has somewhere to go back to. That is not scaffolding for its own
  /// sake: the runner leaves through the router, and pumping it under a bare
  /// `MaterialApp` would let a broken exit pass.
  Future<void> pump(WidgetTester tester, AssessmentDetail detail) async {
    cubit = AssessmentDetailCubit(
      getDetail: getDetail,
      startAttempt: _MockStart(),
      saveAttempt: _MockSave(),
      submitAttempt: submit,
      assessmentId: detail.assessment.id,
    )..emit(RemoteState(status: RemoteStatus.success, data: detail));

    // Submitting reloads the attempt, so the fetch has to answer.
    when(() => getDetail(any())).thenAnswer((_) async => Right(detail));

    final router = GoRouter(
      initialLocation: '/student/quiz',
      routes: [
        GoRoute(
          path: '/student/quiz',
          builder: (_, _) => const Scaffold(body: Text('quiz list')),
        ),
        GoRoute(
          path: '/student/quiz/attempt',
          builder: (_, _) => Scaffold(
            body: BlocProvider.value(
              value: cubit,
              child: AttemptRunner(detail: detail, kind: 'Quiz'),
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (_, child) => GlassScope(child: child ?? const SizedBox()),
      ),
    );
    // Not awaited: the push's future completes only when the route is popped,
    // which is exactly what some of these tests are waiting to observe.
    unawaited(router.push('/student/quiz/attempt'));
    await tester.pumpAndSettle();
  }

  /// Leaves the app and comes back.
  ///
  /// The return leg is not decoration. Flutter stops producing frames while the
  /// app is paused, so a violation recorded on the way out cannot repaint until
  /// the student is looking at the screen again — which is exactly when the
  /// warning and the new tally need to be there.
  Future<void> leaveAndReturn(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  void answerWith(int count, {bool autoSubmit = false}) {
    when(() => report(any())).thenAnswer(
      (_) async => Right(
        ProctorEventResult(
          violationCount: count,
          shouldAutoSubmit: autoSubmit,
        ),
      ),
    );
  }

  group('which signals are watched', () {
    testWidgets('backgrounding reports a tab switch when the signal is on',
        (tester) async {
      answerWith(1);
      await pump(tester, _detail());

      await leaveAndReturn(tester);

      final captured = verify(() => report(captureAny())).captured
          .cast<ProctorEventParams>();
      expect(captured, hasLength(1));
      expect(captured.single.eventType, ProctorEventType.tabSwitch);
      expect(captured.single.assessmentId, 'a1');
    });

    testWidgets('backgrounding is ignored when tab-switch is off',
        (tester) async {
      answerWith(1);
      await pump(
        tester,
        _detail(config: const ProctoringConfig(copyPaste: true)),
      );

      await leaveAndReturn(tester);

      verifyNever(() => report(any()));
    });

    testWidgets('a proctored attempt with no config watches nothing',
        (tester) async {
      answerWith(1);
      await pump(tester, _detail(config: null));

      await leaveAndReturn(tester);

      verifyNever(() => report(any()));
    });

    testWidgets('an unproctored attempt watches nothing', (tester) async {
      answerWith(1);
      await pump(tester, _detail(isProctored: false));

      await leaveAndReturn(tester);

      verifyNever(() => report(any()));
    });

    testWidgets('inactive alone is not a violation', (tester) async {
      // A notification banner or a peek at the app switcher raises `inactive`
      // without the student ever leaving; only `paused` means they did.
      answerWith(1);
      await pump(tester, _detail());

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      verifyNever(() => report(any()));
    });
  });

  group('the server owns the tally', () {
    testWidgets('the count shown is the one the server answers with',
        (tester) async {
      // Deliberately not 1: a client counting for itself would show 1 here.
      answerWith(7);
      await pump(tester, _detail(maxViolations: 10));

      await leaveAndReturn(tester);
      await tester.pumpAndSettle();
      expect(find.text('7 of 10 violations used'), findsOneWidget);
    });

    testWidgets('the allowance is visible before any is spent',
        (tester) async {
      // It used to appear only on the first violation, so a student starting a
      // proctored quiz had no idea how much rope they had.
      await pump(tester, _detail(violationCount: 0, maxViolations: 3));
      await tester.pumpAndSettle();

      expect(find.text('0 of 3 violations used'), findsOneWidget);
    });

    testWidgets('an unproctored attempt shows no allowance', (tester) async {
      await pump(tester, _detail(isProctored: false));
      await tester.pumpAndSettle();

      expect(find.textContaining('violations used'), findsNothing);
    });

    testWidgets('the tally never reads past the limit', (tester) async {
      // A burst queued while the app was backgrounded can push the server's
      // count past the limit; "4 of 3" is not a thing to show a student.
      await pump(tester, _detail(violationCount: 4, maxViolations: 3));
      await tester.pumpAndSettle();

      expect(find.text('3 of 3 violations used'), findsOneWidget);
      expect(find.text('4 of 3 violations used'), findsNothing);
    });

    testWidgets('a resumed attempt seeds from its existing count',
        (tester) async {
      await pump(tester, _detail(violationCount: 2, maxViolations: 3));
      await tester.pumpAndSettle();

      expect(find.text('2 of 3 violations used'), findsOneWidget);
    });

    testWidgets('each report carries when it happened', (tester) async {
      answerWith(1);
      final before = DateTime.now();
      await pump(tester, _detail());

      await leaveAndReturn(tester);

      final captured = verify(() => report(captureAny())).captured
          .cast<ProctorEventParams>();
      expect(
        captured.single.occurredAt.isBefore(before.subtract(
          const Duration(seconds: 1),
        )),
        isFalse,
      );
    });
  });

  group('the threshold', () {
    testWidgets('auto-submits once when the server says so', (tester) async {
      answerWith(3, autoSubmit: true);
      await pump(tester, _detail());

      await leaveAndReturn(tester);

      final payload =
          verify(() => submit(captureAny())).captured.single as AttemptPayload;
      expect(payload.autoSubmitted, isTrue);
    });

    testWidgets('later signals do not submit a second time', (tester) async {
      answerWith(3, autoSubmit: true);
      await pump(tester, _detail());

      for (var i = 0; i < 3; i++) {
        await leaveAndReturn(tester);
      }

      // One submit, and no reports after the threshold fired — the attempt is
      // already on its way out.
      verify(() => submit(any())).called(1);
      verify(() => report(any())).called(1);
    });

    testWidgets('no auto-submit while under the limit', (tester) async {
      answerWith(1);
      await pump(tester, _detail());

      await leaveAndReturn(tester);

      verifyNever(() => submit(any()));
    });

    testWidgets('the limit is enforced even without the server flag',
        (tester) async {
      // The regression this exists for: the tally reached "4 of 3" and the
      // attempt carried on, because the client acted only on the server's
      // `shouldAutoSubmit`. The client is shown `maxViolations` and must hold
      // the student to it whatever that flag says.
      answerWith(3, autoSubmit: false);
      await pump(tester, _detail(maxViolations: 3));

      await leaveAndReturn(tester);

      final payload =
          verify(() => submit(captureAny())).captured.single as AttemptPayload;
      expect(payload.autoSubmitted, isTrue);
    });

    testWidgets('a count past the limit still ends the attempt exactly once',
        (tester) async {
      answerWith(5, autoSubmit: false);
      await pump(tester, _detail(maxViolations: 3));

      for (var i = 0; i < 3; i++) {
        await leaveAndReturn(tester);
      }

      verify(() => submit(any())).called(1);
      verify(() => report(any())).called(1);
    });

    testWidgets('reaching the limit leaves the attempt', (tester) async {
      // The regression: the limit tripped and the attempt was submitted, but
      // the student was left sitting on the quiz. It exited through
      // `Navigator.maybePop`, which does nothing inside the router's shell.
      answerWith(3, autoSubmit: true);
      await pump(tester, _detail(maxViolations: 3));

      expect(find.text('quiz list'), findsNothing);

      await leaveAndReturn(tester);

      expect(find.text('quiz list'), findsOneWidget);
      expect(find.text('Question 1 of 1'), findsNothing);
    });

    testWidgets('it leaves even when the submit fails', (tester) async {
      // The server finalizes the attempt itself when the threshold trips, so a
      // failed submit here usually means it is already over. Stranding the
      // student on a quiz they can no longer submit is the worst outcome.
      answerWith(3, autoSubmit: true);
      when(() => submit(any())).thenAnswer(
        (_) async => const Left(ServerFailure('already submitted')),
      );
      await pump(tester, _detail(maxViolations: 3));

      await leaveAndReturn(tester);

      expect(find.text('quiz list'), findsOneWidget);
    });

    testWidgets('staying under the limit does not leave', (tester) async {
      answerWith(1);
      await pump(tester, _detail(maxViolations: 3));

      await leaveAndReturn(tester);

      expect(find.text('quiz list'), findsNothing);
      expect(find.text('Question 1 of 1'), findsOneWidget);
    });

    testWidgets('with no limit set, the attempt is never cut short',
        (tester) async {
      answerWith(9, autoSubmit: false);
      await pump(tester, _detail(maxViolations: null));

      await leaveAndReturn(tester);

      verifyNever(() => submit(any()));
    });
  });

  group('failures', () {
    testWidgets('a failed report leaves the attempt running', (tester) async {
      when(() => report(any())).thenAnswer(
        (_) async => const Left(ServerFailure('offline')),
      );
      await pump(tester, _detail(violationCount: 1, maxViolations: 3));

      await leaveAndReturn(tester);

      // Neither submitted nor advanced past what the server last confirmed.
      verifyNever(() => submit(any()));
      expect(find.text('1 of 3 violations used'), findsOneWidget);
    });
  });
}
