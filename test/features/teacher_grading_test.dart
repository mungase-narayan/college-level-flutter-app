import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/features/teacher/assessments/data/models/submission_model.dart';
import 'package:college_level/features/teacher/assessments/data/models/teacher_assessment_model.dart';
import 'package:college_level/features/teacher/assessments/domain/entities/submission.dart';
import 'package:college_level/features/teacher/assessments/domain/entities/teacher_assessment.dart';
import 'package:college_level/features/teacher/assessments/domain/usecases/teacher_grading_usecases.dart';
import 'package:college_level/features/teacher/assessments/presentation/bloc/overview_cubit.dart';
import 'package:college_level/features/teacher/assessments/presentation/bloc/statistics_cubit.dart';
import 'package:college_level/features/teacher/assessments/presentation/bloc/submission_review_cubit.dart';
import 'package:college_level/features/teacher/assessments/presentation/widgets/overview_tab.dart';
import 'package:college_level/features/teacher/assessments/presentation/widgets/results_export.dart';
import 'package:college_level/features/teacher/assessments/presentation/widgets/statistics_tab.dart';

import '../support/platform_parity.dart';

class _MockGrading extends Mock implements TeacherGradingUseCases {}

/// A learner row. `totalScore` arrives as a string, which is how Postgres
/// `numeric` columns come back.
Map<String, dynamic> _learner(
  String id, {
  String name = 'Asha Rao',
  String status = SubmissionStatus.submitted,
  Object? totalScore = '8',
  Object? maxScore = 10,
  int timeSpentSeconds = 300,
}) =>
    {
      'id': id,
      'studentId': 'st-$id',
      'status': status,
      'userFullName': name,
      'attempt': 1,
      'totalScore': totalScore,
      'maxScore': maxScore,
      'timeSpentSeconds': timeSpentSeconds,
      'studentRollNumber': 'R-$id',
      'userEmail': '$id@example.edu',
    };

Map<String, dynamic> _overviewJson({
  List<Map<String, dynamic>>? learners,
  int total = 1,
  int evaluated = 0,
  Object? avgPercent = 80,
  int page = 1,
  int totalPages = 1,
}) =>
    {
      'learners': learners ?? [_learner('s1')],
      'summary': {
        'total': total,
        'evaluated': evaluated,
        'avgPercent': avgPercent,
      },
      'pagination': {'page': page, 'totalPages': totalPages},
    };

/// An assessment detail, which the review cubit needs for the question order,
/// the total marks and the window.
TeacherAssessmentDetail _assessment({
  String type = AssessmentType.questions,
  List<Map<String, dynamic>> questions = const [],
  String endDate = '2099-01-01T00:00:00.000Z',
  bool lateAllowed = false,
  int totalMarks = 20,
}) =>
    TeacherAssessmentDetailModel.fromJson({
      'id': 'a1',
      'title': 'Graph traversal',
      'category': AssessmentCategory.quiz,
      'type': type,
      'status': AssessmentStatus.active,
      'totalMarks': totalMarks,
      'startDate': '2026-01-01T00:00:00.000Z',
      'endDate': endDate,
      'isLateSubmissionAllowed': lateAllowed,
      'questions': questions,
    });

Map<String, dynamic> _answer(
  String id, {
  required String assessmentQuestionId,
  String type = QuestionType.mcq,
  int points = 10,
  Object? score,
  Object? isCorrect,
  Object? testCasesPassed,
  Object? testCasesTotal,
}) =>
    {
      'id': id,
      'assessmentQuestionId': assessmentQuestionId,
      'questionId': 'q-$id',
      'questionType': type,
      'questionTitle': 'Question $id',
      'questionPoints': points,
      'score': score,
      'isCorrect': isCorrect,
      'testCasesPassed': testCasesPassed,
      'testCasesTotal': testCasesTotal,
    };

({SubmissionDetail detail, SubmissionNote note}) _submission({
  String status = SubmissionStatus.submitted,
  List<Map<String, dynamic>> answers = const [],
  List<Map<String, dynamic>> proctorEvents = const [],
  Object? totalScore,
  String? note,
  bool autoSubmitted = false,
  int violationResetCount = 0,
}) {
  final json = {
    'submission': {
      ..._learner('s1', status: status, totalScore: totalScore),
      'note': note,
      'feedback': null,
      'autoSubmitted': autoSubmitted,
      'violationResetCount': violationResetCount,
    },
    'answers': answers,
    'proctorEvents': proctorEvents,
  };
  return (
    detail: SubmissionDetailModel.fromJson(json),
    note: submissionNoteFromJson(json),
  );
}

ResultRow _resultRow({
  required String id,
  bool attempted = true,
  int totalScore = 8,
  int? maxScore = 10,
  int timeSpentSeconds = 300,
  String outcome = AssignmentOutcome.pass,
}) =>
    ResultRow(
      studentId: id,
      fullName: 'Student $id',
      rollNumber: 'R-$id',
      attempted: attempted,
      outcome: outcome,
      totalScore: totalScore,
      maxScore: maxScore,
      timeSpentSeconds: timeSpentSeconds,
    );

void main() {
  setUpAll(() {
    // `any(named: 'input')` needs a dummy of every custom type it matches.
    registerFallbackValue(const EvaluationInput());
  });

  group('SubmissionRowModel', () {
    test('coerces the score fields and maps the wire names', () {
      final row = SubmissionRowModel.fromJson(_learner('s1'));

      expect(row.totalScore, 8);
      expect(row.maxScore, 10);
      expect(row.fullName, 'Asha Rao');
      expect(row.identifier, 'R-s1');
    });

    test('falls back to the email when there is no roll number', () {
      final row = SubmissionRowModel.fromJson({
        ..._learner('s1'),
        'studentRollNumber': null,
      });

      expect(row.identifier, 's1@example.edu');
    });

    test('keeps an unscored attempt null rather than zero', () {
      final row = SubmissionRowModel.fromJson(
        _learner('s1', totalScore: null, maxScore: null),
      );

      // A dash, not "0/0" — nothing has been scored yet.
      expect(row.totalScore, isNull);
      expect(row.fraction, isNull);
    });

    test('reports the pass fraction for the score pill', () {
      expect(SubmissionRowModel.fromJson(_learner('s1')).fraction, 0.8);
    });
  });

  group('AssignmentOverviewModel', () {
    test('flattens the summary and the pagination', () {
      final overview = AssignmentOverviewModel.fromJson(
        _overviewJson(total: 12, evaluated: 5, page: 2, totalPages: 3),
      );

      expect(overview.total, 12);
      expect(overview.evaluated, 5);
      expect(overview.avgPercent, 80);
      expect(overview.page, 2);
      expect(overview.totalPages, 3);
      expect(overview.learners, hasLength(1));
    });

    test('leaves the average null until something is scored', () {
      final overview = AssignmentOverviewModel.fromJson(
        _overviewJson(avgPercent: null),
      );

      expect(overview.avgPercent, isNull);
    });
  });

  group('QuestionStatModel', () {
    test('parses a choice question with its option distribution', () {
      final stat = QuestionStatModel.fromJson({
        'assessmentQuestionId': 'aq-1',
        'questionId': 'q-1',
        'order': 1,
        'title': 'Pick the traversal',
        'type': QuestionType.mcq,
        'points': 5,
        'totalResponses': 10,
        'correct': 7,
        'incorrect': 3,
        'accuracy': 70,
        'options': [
          {
            'id': 'o1',
            'label': 'BFS',
            'count': 7,
            'percent': 70,
            'isCorrect': true,
          },
          {
            'id': 'o2',
            'label': 'DFS',
            'count': 3,
            'percent': 30,
            'isCorrect': false,
          },
        ],
      });

      expect(stat.isChoice, isTrue);
      expect(stat.isAutoGraded, isTrue);
      expect(stat.hasResults, isTrue);
      expect(stat.options.first.isCorrect, isTrue);
    });

    test('marks a manually-graded question as such', () {
      final stat = QuestionStatModel.fromJson({
        'assessmentQuestionId': 'aq-2',
        'questionId': 'q-2',
        'order': 2,
        'title': 'Implement it',
        'type': QuestionType.coding,
        'points': 10,
        'totalResponses': 4,
        'correct': 0,
        'incorrect': 0,
        'accuracy': null,
      });

      // Null accuracy is "the server could not score this", not zero.
      expect(stat.isAutoGraded, isFalse);
      expect(stat.isChoice, isFalse);
      expect(stat.hasResults, isFalse);
    });
  });

  group('SubmissionAnswer seeding', () {
    test('uses the stored score when there is one', () {
      final answer = SubmissionAnswerModel.fromJson(
        _answer('a1', assessmentQuestionId: 'aq-1', score: 7, isCorrect: true),
      );

      expect(answer.seededScore, 7);
      expect(answer.seededMark, isTrue);
    });

    test('backfills a coding score from the test-case ratio', () {
      final answer = SubmissionAnswerModel.fromJson(_answer(
        'a1',
        assessmentQuestionId: 'aq-1',
        type: QuestionType.coding,
        points: 10,
        testCasesPassed: 3,
        testCasesTotal: 4,
      ));

      // round(3/4 × 10) — so partial credit shows rather than reading as
      // ungraded.
      expect(answer.seededScore, 8);
      expect(answer.seededMark, isFalse);
      expect(answer.testCaseScore, 8);
    });

    test('treats a fully-passing coding answer as correct', () {
      final answer = SubmissionAnswerModel.fromJson(_answer(
        'a1',
        assessmentQuestionId: 'aq-1',
        type: QuestionType.coding,
        points: 10,
        testCasesPassed: 4,
        testCasesTotal: 4,
      ));

      expect(answer.seededMark, isTrue);
      expect(answer.seededScore, 10);
    });

    test('leaves an unrun coding answer entirely ungraded', () {
      final answer = SubmissionAnswerModel.fromJson(_answer(
        'a1',
        assessmentQuestionId: 'aq-1',
        type: QuestionType.coding,
        testCasesTotal: 0,
      ));

      expect(answer.hasTestCases, isFalse);
      expect(answer.seededScore, isNull);
      expect(answer.seededMark, isNull);
    });

    test('prefers the stored score over the coding ratio', () {
      final answer = SubmissionAnswerModel.fromJson(_answer(
        'a1',
        assessmentQuestionId: 'aq-1',
        type: QuestionType.coding,
        points: 10,
        score: 2,
        testCasesPassed: 4,
        testCasesTotal: 4,
      ));

      // The teacher's own mark wins over the auto-grade.
      expect(answer.seededScore, 2);
    });
  });

  group('SubmissionDetail', () {
    test('groups the proctor events by kind', () {
      final payload = _submission(proctorEvents: [
        {'id': 'e1', 'eventType': 'tab_switch'},
        {'id': 'e2', 'eventType': 'tab_switch'},
        {'id': 'e3', 'eventType': 'copy'},
      ]);

      expect(payload.detail.violationsByType, {'tab_switch': 2, 'copy': 1});
    });
  });

  group('OverviewCubit', () {
    late TeacherGradingUseCases grading;

    setUp(() {
      grading = _MockGrading();
      when(() => grading.overview(
            assessmentId: any(named: 'assessmentId'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            search: any(named: 'search'),
            sortBy: any(named: 'sortBy'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer(
        (_) async => Right(AssignmentOverviewModel.fromJson(_overviewJson())),
      );
    });

    test('splits the sort value into the two params the API wants', () async {
      final cubit = OverviewCubit(grading: grading, assessmentId: 'a1');
      cubit.setSort(OverviewCubit.sortNameAsc);
      await Future<void>.delayed(Duration.zero);

      verify(() => grading.overview(
            assessmentId: 'a1',
            page: 1,
            limit: OverviewCubit.pageSize,
            search: null,
            sortBy: 'name',
            sortOrder: 'asc',
          )).called(1);
    });

    test('defaults to best score first', () async {
      final cubit = OverviewCubit(grading: grading, assessmentId: 'a1');
      await cubit.load();

      verify(() => grading.overview(
            assessmentId: 'a1',
            page: 1,
            limit: OverviewCubit.pageSize,
            search: null,
            sortBy: 'score',
            sortOrder: 'desc',
          )).called(1);
    });

    test('resets to page one when the sort changes', () async {
      final cubit = OverviewCubit(grading: grading, assessmentId: 'a1');
      cubit.setPage(4);
      cubit.setSort(OverviewCubit.sortScoreAsc);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.page, 1);
    });

    test('surfaces a failure', () async {
      when(() => grading.overview(
            assessmentId: any(named: 'assessmentId'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            search: any(named: 'search'),
            sortBy: any(named: 'sortBy'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer((_) async => const Left(ServerFailure('boom')));

      final cubit = OverviewCubit(grading: grading, assessmentId: 'a1');
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
    });
  });

  group('StatisticsCubit', () {
    late TeacherGradingUseCases grading;

    List<QuestionStat> stats(List<int?> accuracies) => [
          for (var i = 0; i < accuracies.length; i++)
            QuestionStatModel.fromJson({
              'assessmentQuestionId': 'aq-$i',
              'questionId': 'q-$i',
              'order': i,
              'title': 'Q$i',
              'type': QuestionType.mcq,
              'points': 5,
              'totalResponses': 4,
              'correct': 2,
              'incorrect': 2,
              'accuracy': accuracies[i],
            }),
        ];

    setUp(() => grading = _MockGrading());

    test('averages only the auto-graded questions', () async {
      when(() => grading.statistics(any()))
          .thenAnswer((_) async => Right(stats([90, 50, null])));

      final cubit = StatisticsCubit(grading: grading, assessmentId: 'a1');
      await cubit.load();

      // The ungraded one is excluded, not counted as zero.
      expect(cubit.averageAccuracy, 70);
      expect(cubit.highestAccuracy, 90);
      expect(cubit.needsGrading, 1);
      expect(cubit.questionCount, 3);
    });

    test('reports no average when nothing is auto-graded', () async {
      when(() => grading.statistics(any()))
          .thenAnswer((_) async => Right(stats([null, null])));

      final cubit = StatisticsCubit(grading: grading, assessmentId: 'a1');
      await cubit.load();

      expect(cubit.averageAccuracy, isNull);
      expect(cubit.highestAccuracy, isNull);
      expect(cubit.needsGrading, 2);
    });
  });

  group('SubmissionReviewCubit', () {
    late TeacherGradingUseCases grading;

    setUp(() => grading = _MockGrading());

    SubmissionReviewCubit review({
      required TeacherAssessmentDetail assessment,
      required ({SubmissionDetail detail, SubmissionNote note}) payload,
    }) {
      when(() => grading.submission(
            assessmentId: any(named: 'assessmentId'),
            submissionId: any(named: 'submissionId'),
          )).thenAnswer((_) async => Right(payload));
      when(() => grading.evaluate(
            assessmentId: any(named: 'assessmentId'),
            submissionId: any(named: 'submissionId'),
            input: any(named: 'input'),
          )).thenAnswer((_) async => const Right(null));

      return SubmissionReviewCubit(
        grading: grading,
        assessmentId: 'a1',
        submissionId: 's1',
        assessment: assessment,
      );
    }

    test('orders the answers by the assessment question order', () async {
      final cubit = review(
        assessment: _assessment(questions: [
          {'id': 'aq-1', 'questionId': 'q1', 'order': 1},
          {'id': 'aq-2', 'questionId': 'q2', 'order': 2},
        ]),
        // Deliberately the wrong way round — the payload is unordered.
        payload: _submission(answers: [
          _answer('ans-2', assessmentQuestionId: 'aq-2'),
          _answer('ans-1', assessmentQuestionId: 'aq-1'),
        ]),
      );
      await cubit.load();

      expect([for (final a in cubit.state.answers) a.id], ['ans-1', 'ans-2']);
    });

    test('appends an answer with no matching question', () async {
      final cubit = review(
        assessment: _assessment(questions: [
          {'id': 'aq-1', 'questionId': 'q1', 'order': 1},
        ]),
        payload: _submission(answers: [
          _answer('ans-1', assessmentQuestionId: 'aq-1'),
          _answer('orphan', assessmentQuestionId: 'aq-removed'),
        ]),
      );
      await cubit.load();

      // Dropping it would hide a graded answer from the teacher.
      expect([for (final a in cubit.state.answers) a.id],
          ['ans-1', 'orphan']);
    });

    test('seeds the marks from the stored values', () async {
      final cubit = review(
        assessment: _assessment(questions: [
          {'id': 'aq-1', 'questionId': 'q1', 'order': 1},
        ]),
        payload: _submission(answers: [
          _answer(
            'ans-1',
            assessmentQuestionId: 'aq-1',
            score: 7,
            isCorrect: true,
          ),
        ]),
      );
      await cubit.load();

      expect(cubit.state.marks['ans-1']?.score, '7');
      expect(cubit.state.marks['ans-1']?.isCorrect, isTrue);
    });

    test('is read-only while the attempt is in progress', () async {
      final cubit = review(
        assessment: _assessment(),
        payload: _submission(status: SubmissionStatus.inProgress),
      );
      await cubit.load();

      expect(cubit.state.readOnly, isTrue);
      // Nothing to grade yet — the student can still change the answers.
      expect(await cubit.save(), isNull);
      verifyNever(() => grading.evaluate(
            assessmentId: any(named: 'assessmentId'),
            submissionId: any(named: 'submissionId'),
            input: any(named: 'input'),
          ));
    });

    group('gradeOf', () {
      test('buckets a coding answer by its test-case ratio', () async {
        final cubit = review(
          assessment: _assessment(questions: [
            {'id': 'aq-1', 'questionId': 'q1', 'order': 1},
            {'id': 'aq-2', 'questionId': 'q2', 'order': 2},
            {'id': 'aq-3', 'questionId': 'q3', 'order': 3},
          ]),
          payload: _submission(answers: [
            _answer('all', assessmentQuestionId: 'aq-1',
                type: QuestionType.coding,
                testCasesPassed: 4, testCasesTotal: 4),
            _answer('some', assessmentQuestionId: 'aq-2',
                type: QuestionType.coding,
                testCasesPassed: 2, testCasesTotal: 4),
            _answer('none', assessmentQuestionId: 'aq-3',
                type: QuestionType.coding,
                testCasesPassed: 0, testCasesTotal: 4),
          ]),
        );
        await cubit.load();

        final byId = {for (final a in cubit.state.answers) a.id: a};
        expect(cubit.gradeOf(byId['all']!), GradeState.correct);
        expect(cubit.gradeOf(byId['some']!), GradeState.partial);
        expect(cubit.gradeOf(byId['none']!), GradeState.wrong);
      });

      test('follows the teacher mark for everything else', () async {
        final cubit = review(
          assessment: _assessment(questions: [
            {'id': 'aq-1', 'questionId': 'q1', 'order': 1},
          ]),
          payload: _submission(answers: [
            _answer('ans-1', assessmentQuestionId: 'aq-1'),
          ]),
        );
        await cubit.load();
        final answer = cubit.state.answers.single;

        expect(cubit.gradeOf(answer), GradeState.ungraded);
        cubit.markCorrect(answer);
        expect(cubit.gradeOf(answer), GradeState.correct);
        cubit.markWrong(answer);
        expect(cubit.gradeOf(answer), GradeState.wrong);
      });
    });

    test('the shortcut buttons set the score alongside the mark', () async {
      final cubit = review(
        assessment: _assessment(questions: [
          {'id': 'aq-1', 'questionId': 'q1', 'order': 1},
        ]),
        payload: _submission(answers: [
          _answer('ans-1', assessmentQuestionId: 'aq-1', points: 10),
        ]),
      );
      await cubit.load();
      final answer = cubit.state.answers.single;

      cubit.markCorrect(answer);
      expect(cubit.state.marks['ans-1']?.score, '10');
      cubit.markWrong(answer);
      expect(cubit.state.marks['ans-1']?.score, '0');
    });

    group('buildInput', () {
      test('clamps a per-question score to the question points', () async {
        final cubit = review(
          assessment: _assessment(questions: [
            {'id': 'aq-1', 'questionId': 'q1', 'order': 1},
          ]),
          payload: _submission(answers: [
            _answer('ans-1', assessmentQuestionId: 'aq-1', points: 5),
          ]),
        );
        await cubit.load();
        cubit.setScore('ans-1', '500');

        // The web clamps only at zero, so a typo awards 500 on a 5-point
        // question and the server takes it.
        expect(cubit.buildInput().questions!.single.score, 5);
      });

      test('clamps a negative per-question score to zero', () async {
        final cubit = review(
          assessment: _assessment(questions: [
            {'id': 'aq-1', 'questionId': 'q1', 'order': 1},
          ]),
          payload: _submission(answers: [
            _answer('ans-1', assessmentQuestionId: 'aq-1', points: 5),
          ]),
        );
        await cubit.load();
        cubit.setScore('ans-1', '-3');

        expect(cubit.buildInput().questions!.single.score, 0);
      });

      test('keys each evaluation by the answer id', () async {
        final cubit = review(
          assessment: _assessment(questions: [
            {'id': 'aq-1', 'questionId': 'q1', 'order': 1},
          ]),
          payload: _submission(answers: [
            _answer('ans-1', assessmentQuestionId: 'aq-1'),
          ]),
        );
        await cubit.load();

        final json = cubit.buildInput().toJson();
        final rows = json['questionEvaluations'] as List;
        expect((rows.single as Map)['questionSubmissionId'], 'ans-1');
        // Not the question id, and not the join-row id.
        expect(json.containsKey('overallScore'), isFalse);
      });

      test('sends one overall score for a submission assessment', () async {
        final cubit = review(
          assessment: _assessment(
            type: AssessmentType.submission,
            totalMarks: 20,
          ),
          payload: _submission(),
        );
        await cubit.load();
        cubit.setOverallScore('15');

        final json = cubit.buildInput().toJson();
        expect(json['overallScore'], 15);
        expect(json.containsKey('questionEvaluations'), isFalse);
      });

      test('clamps the overall score to the total marks', () async {
        final cubit = review(
          assessment: _assessment(
            type: AssessmentType.submission,
            totalMarks: 20,
          ),
          payload: _submission(),
        );
        await cubit.load();
        cubit.setOverallScore('999');

        expect(cubit.buildInput().overallScore, 20);
      });

      test('sends a null feedback rather than an empty string', () async {
        final cubit = review(
          assessment: _assessment(type: AssessmentType.submission),
          payload: _submission(),
        );
        await cubit.load();

        expect(cubit.buildInput().toJson()['feedback'], isNull);
      });
    });

    group('re-attempt', () {
      test('is offered while the window is open', () async {
        final cubit = review(
          assessment: _assessment(endDate: '2099-01-01T00:00:00.000Z'),
          payload: _submission(),
        );
        await cubit.load();

        expect(cubit.windowOpen, isTrue);
        expect(cubit.canReattempt, isTrue);
      });

      test('is withheld once the window has closed', () async {
        final cubit = review(
          assessment: _assessment(endDate: '2020-01-01T00:00:00.000Z'),
          payload: _submission(),
        );
        await cubit.load();

        // A closed window cannot be resumed, so reopening achieves nothing.
        expect(cubit.windowOpen, isFalse);
        expect(cubit.canReattempt, isFalse);
      });

      test('is offered on a closed window when late is allowed', () async {
        final cubit = review(
          assessment: _assessment(
            endDate: '2020-01-01T00:00:00.000Z',
            lateAllowed: true,
          ),
          payload: _submission(),
        );
        await cubit.load();

        expect(cubit.canReattempt, isTrue);
      });

      test('is withheld for an attempt still in progress', () async {
        final cubit = review(
          assessment: _assessment(),
          payload: _submission(status: SubmissionStatus.inProgress),
        );
        await cubit.load();

        expect(cubit.canReattempt, isFalse);
      });
    });

    test('progress counts graded answers, or answered when read-only',
        () async {
      final answers = [
        _answer('ans-1', assessmentQuestionId: 'aq-1', isCorrect: true),
        {
          ..._answer('ans-2', assessmentQuestionId: 'aq-2'),
          'answerText': 'something',
        },
      ];
      final questions = [
        {'id': 'aq-1', 'questionId': 'q1', 'order': 1},
        {'id': 'aq-2', 'questionId': 'q2', 'order': 2},
      ];

      final graded = review(
        assessment: _assessment(questions: questions),
        payload: _submission(answers: answers),
      );
      await graded.load();
      expect(graded.progressCount, 1);

      final inProgress = review(
        assessment: _assessment(questions: questions),
        payload: _submission(
          status: SubmissionStatus.inProgress,
          answers: answers,
        ),
      );
      await inProgress.load();
      // Only one of the two has content the student actually entered.
      expect(inProgress.progressCount, 1);
    });
  });

  group('CSV export', () {
    test('ranks the attempted rows, ties sharing a place', () {
      final ranks = rankResults([
        _resultRow(id: 'a', totalScore: 10, timeSpentSeconds: 100),
        _resultRow(id: 'b', totalScore: 8, timeSpentSeconds: 200),
        _resultRow(id: 'c', totalScore: 8, timeSpentSeconds: 200),
        _resultRow(id: 'd', totalScore: 5, timeSpentSeconds: 300),
      ]);

      // b and c tie on both score and time, so they share second; d is fourth.
      expect(ranks, [1, 2, 2, 4]);
    });

    test('leaves non-attempters unranked', () {
      final ranks = rankResults([
        _resultRow(id: 'a', totalScore: 10),
        _resultRow(
          id: 'b',
          attempted: false,
          totalScore: 0,
          outcome: AssignmentOutcome.notAttempted,
        ),
        _resultRow(id: 'c', totalScore: 4, timeSpentSeconds: 400),
      ]);

      expect(ranks, [1, null, 2]);
    });

    test('blanks a non-attempter rather than zeroing them', () {
      final row = csvRowFor(
        _resultRow(
          id: 'b',
          attempted: false,
          totalScore: 0,
          outcome: AssignmentOutcome.notAttempted,
        ),
        null,
      );

      // Zeros here would drag down an average taken in a spreadsheet.
      expect(row[0], '');
      expect(row[3], 'Not Attempted');
      expect(row[4], '');
      expect(row[6], '');
      expect(row[7], '');
    });

    test('computes the percentage for an attempted row', () {
      final row = csvRowFor(
        _resultRow(id: 'a', totalScore: 8, maxScore: 10),
        1,
      );

      expect(row[0], '1');
      expect(row[4], '8');
      expect(row[5], '10');
      expect(row[6], '80%');
    });

    test('writes the web column set, quoted', () {
      final csv = buildResultsCsv(ResultSheet(
        title: 'Graph traversal',
        totalMarks: 10,
        rows: [_resultRow(id: 'a')],
      ));

      final lines = csv.split('\r\n');
      expect(lines.first, csvColumns.map((c) => '"$c"').join(','));
      expect(lines, hasLength(2));
    });

    test('escapes a quote inside a field by doubling it', () {
      final csv = buildResultsCsv(ResultSheet(
        title: 'x',
        totalMarks: 10,
        rows: [
          ResultRow(
            studentId: 'a',
            fullName: 'A "Ace" Rao',
            attempted: true,
            outcome: AssignmentOutcome.pass,
            totalScore: 5,
            maxScore: 10,
          ),
        ],
      ));

      expect(csv, contains('"A ""Ace"" Rao"'));
    });

    test('slugifies the file name', () {
      expect(csvFileName('Graph Traversal!'), 'graph-traversal-results.csv');
      expect(csvFileName('   '), 'assessment-results.csv');
    });
  });

  group('ApiUrls', () {
    test('shapes the grading paths', () {
      expect(
        ApiUrls.teacherAssignmentOverview('a1'),
        '/teacher/assignments/a1/overview',
      );
      expect(
        ApiUrls.teacherAssignmentStatistics('a1'),
        '/teacher/assignments/a1/statistics',
      );
      expect(
        ApiUrls.teacherAssignmentResults('a1'),
        '/teacher/assignments/a1/results',
      );
      expect(
        ApiUrls.teacherAssignmentSubmission('a1', 's1'),
        '/teacher/assignments/a1/submissions/s1',
      );
      expect(
        ApiUrls.teacherAssignmentEvaluate('a1', 's1'),
        '/teacher/assignments/a1/submissions/s1/evaluate',
      );
      expect(
        ApiUrls.teacherAssignmentReattempt('a1', 's1'),
        '/teacher/assignments/a1/submissions/s1/allow-reattempt',
      );
    });
  });

  group('screens', () {
    late TeacherGradingUseCases grading;

    setUp(() {
      grading = _MockGrading();
      when(() => grading.overview(
            assessmentId: any(named: 'assessmentId'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            search: any(named: 'search'),
            sortBy: any(named: 'sortBy'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer(
        (_) async => Right(AssignmentOverviewModel.fromJson(_overviewJson(
          learners: [
            _learner('s1', name: 'Asha Rao'),
            _learner(
              's2',
              name: 'Dev Kumar',
              status: SubmissionStatus.inProgress,
              totalScore: null,
              maxScore: null,
            ),
          ],
          total: 2,
          evaluated: 1,
        ))),
      );
      when(() => grading.statistics(any())).thenAnswer(
        (_) async => Right([
          QuestionStatModel.fromJson({
            'assessmentQuestionId': 'aq-1',
            'questionId': 'q-1',
            'order': 1,
            'title': 'Pick the traversal',
            'type': QuestionType.mcq,
            'points': 5,
            'totalResponses': 4,
            'correct': 3,
            'incorrect': 1,
            'accuracy': 75,
            'options': [
              {
                'id': 'o1',
                'label': 'BFS',
                'count': 3,
                'percent': 75,
                'isCorrect': true,
              },
            ],
          }),
          QuestionStatModel.fromJson({
            'assessmentQuestionId': 'aq-2',
            'questionId': 'q-2',
            'order': 2,
            'title': 'Implement it',
            'type': QuestionType.coding,
            'points': 10,
            'totalResponses': 4,
            'correct': 0,
            'incorrect': 0,
            'accuracy': null,
          }),
        ]),
      );
    });

    bothPlatforms('the overview lists learners with their state', (t, h) async {
      await t.pumpWidget(h(Scaffold(
        body: BlocProvider(
          create: (_) => OverviewCubit(grading: grading, assessmentId: 'a1'),
          child: OverviewTab(onOpenSubmission: (_) {}),
        ),
      )));
      await t.pumpAndSettle();

      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('Dev Kumar'), findsOneWidget);
      expect(find.text('8/10'), findsOneWidget);
      expect(find.text('Needs review'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      // An unscored attempt shows a dash rather than 0/0.
      expect(find.text('—'), findsWidgets);
    });

    bothPlatforms('the statistics tab separates manual questions',
        (t, h) async {
      await t.pumpWidget(h(Scaffold(
        body: BlocProvider(
          create: (_) => StatisticsCubit(grading: grading, assessmentId: 'a1'),
          child: const StatisticsTab(),
        ),
      )));
      await t.pumpAndSettle();

      expect(find.text('75%'), findsWidgets);
      // The coding question reads "Manual", never "0%".
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Coding question — graded manually.'), findsOneWidget);
      expect(find.text('Needs grading'), findsOneWidget);
    });

    bothPlatforms('the overview offers the empty state with no attempts',
        (t, h) async {
      when(() => grading.overview(
            assessmentId: any(named: 'assessmentId'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            search: any(named: 'search'),
            sortBy: any(named: 'sortBy'),
            sortOrder: any(named: 'sortOrder'),
          )).thenAnswer(
        (_) async => Right(AssignmentOverviewModel.fromJson(
          _overviewJson(learners: const [], total: 0, avgPercent: null),
        )),
      );

      await t.pumpWidget(h(Scaffold(
        body: BlocProvider(
          create: (_) => OverviewCubit(grading: grading, assessmentId: 'a1'),
          child: OverviewTab(onOpenSubmission: (_) {}),
        ),
      )));
      await t.pumpAndSettle();

      expect(find.text('No attempts yet'), findsOneWidget);
    });
  });
}
