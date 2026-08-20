import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/config/injection_modules/service_locator.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/features/teacher/assessments/data/models/teacher_assessment_model.dart';
import 'package:college_level/features/shared/files/domain/usecases/file_usecases.dart';
import 'package:college_level/features/teacher/assessments/domain/entities/bank_question.dart';
import 'package:college_level/features/teacher/assessments/domain/entities/teacher_assessment.dart';
import 'package:college_level/features/teacher/assessments/domain/usecases/teacher_assessment_usecases.dart';
import 'package:college_level/features/teacher/assessments/presentation/bloc/assessment_form_cubit.dart';
import 'package:college_level/features/teacher/assessments/presentation/bloc/assessments_list_cubit.dart';
import 'package:college_level/features/teacher/assessments/presentation/bloc/question_bank_cubit.dart';
import 'package:college_level/features/teacher/assessments/presentation/widgets/assessment_form_sheet.dart';
import 'package:college_level/features/teacher/assessments/presentation/widgets/assessment_view_sheet.dart';
import 'package:college_level/features/teacher/assessments/presentation/widgets/assessments_tab.dart';
import 'package:college_level/features/teacher/assessments/presentation/widgets/material_assignments_panel.dart';

import '../support/platform_parity.dart';

class _MockAssessments extends Mock implements TeacherAssessmentUseCases {}

class _MockUploadFiles extends Mock implements UploadFilesUseCase {}

/// One list row. `totalMarks` arrives as a string here on purpose — Postgres
/// `numeric` columns come back that way, which is the shape that broke the
/// courses list earlier.
Map<String, dynamic> _row(
  String id, {
  required String category,
  String title = '',
  Object? totalMarks = '50',
  Object? passingMarks,
}) =>
    {
      'id': id,
      'title': title.isEmpty ? 'Item $id' : title,
      'category': category,
      'type': 'submission',
      'status': 'active',
      'totalMarks': totalMarks,
      'passingMarks': passingMarks,
      'startDate': '2026-08-01T09:00:00.000Z',
      'endDate': '2026-08-08T09:00:00.000Z',
    };

List<TeacherAssessment> _rows(List<Map<String, dynamic>> json) =>
    json.map(TeacherAssessmentModel.fromJson).toList(growable: false);

AssessmentsListCubit _cubit(
  TeacherAssessmentUseCases assessments, {
  required bool quizzes,
  String? divisionId = 'd1',
  String? courseMaterialId,
}) =>
    AssessmentsListCubit(
      assessments: assessments,
      courseId: 'c1',
      divisionId: divisionId,
      courseMaterialId: courseMaterialId,
      quizzes: quizzes,
    );

void main() {
  group('TeacherAssessmentModel', () {
    test('coerces the numeric fields the API sends as strings', () {
      final row = TeacherAssessmentModel.fromJson(_row(
        'a1',
        category: AssessmentCategory.courseAssignment,
        totalMarks: '50',
        passingMarks: '20',
      ));

      expect(row.totalMarks, 50);
      expect(row.passingMarks, 20);
    });

    test('keeps a missing pass mark null rather than zero', () {
      final row = TeacherAssessmentModel.fromJson(
        _row('a1', category: AssessmentCategory.courseAssignment),
      );

      // "No pass mark set" and "pass mark of zero" are different states, and
      // the card only renders the caption for the second.
      expect(row.passingMarks, isNull);
    });

    test('treats a null division as semester-wide', () {
      final row = TeacherAssessmentModel.fromJson(
        _row('a1', category: AssessmentCategory.quiz),
      );

      expect(row.isSemesterWide, isTrue);
      expect(row.resultsPublished, isFalse);
    });

    test('parses a detail payload, question rows included', () {
      final detail = TeacherAssessmentDetailModel.fromJson({
        ..._row('a1', category: AssessmentCategory.quiz),
        'type': AssessmentType.questions,
        'maxAttempt': '3',
        'durationMinutes': '45',
        'isProctored': true,
        'maxViolations': 5,
        'proctoringConfig': {'fullscreen': true, 'copyPaste': false},
        'questions': [
          {
            'id': 'join-1',
            'questionId': 'q-1',
            'order': 1,
            'questionTitle': 'Balance an AVL tree',
            'questionType': QuestionType.coding,
            'questionPoints': '10',
          },
          {
            'id': 'join-2',
            'questionId': 'q-2',
            'order': 2,
            'questionPoints': 5,
          },
        ],
      });

      expect(detail.maxAttempt, 3);
      expect(detail.durationMinutes, 45);
      expect(detail.questions, hasLength(2));

      // The join-row id and the question id are distinct, and detaching needs
      // the first — passing the second fails silently on the server.
      expect(detail.questions.first.id, 'join-1');
      expect(detail.questions.first.questionId, 'q-1');
    });

    test('fills every proctoring signal, defaulting the absent ones off', () {
      final detail = TeacherAssessmentDetailModel.fromJson({
        ..._row('a1', category: AssessmentCategory.quiz),
        'isProctored': true,
        'proctoringConfig': {'fullscreen': true},
      });

      expect(
        detail.proctoringConfig?.keys,
        containsAll(ProctoringSignal.options),
      );
      expect(detail.proctoringConfig?['fullscreen'], isTrue);
      expect(detail.proctoringConfig?['print'], isFalse);
    });

    test('leaves the proctoring config null when there is none', () {
      final detail = TeacherAssessmentDetailModel.fromJson(
        _row('a1', category: AssessmentCategory.quiz),
      );

      expect(detail.proctoringConfig, isNull);
    });

    test('derives total marks from the questions when question-typed', () {
      final detail = TeacherAssessmentDetailModel.fromJson({
        ..._row('a1', category: AssessmentCategory.quiz, totalMarks: '99'),
        'type': AssessmentType.questions,
        'questions': [
          {'id': 'j1', 'questionId': 'q1', 'order': 1, 'questionPoints': 10},
          {'id': 'j2', 'questionId': 'q2', 'order': 2, 'questionPoints': 5},
        ],
      });

      // The server recomputes this from the attached questions, so the value
      // it sent is display-only.
      expect(detail.derivedTotalMarks, 15);
    });

    test('keeps the sent total for submission-typed assessments', () {
      final detail = TeacherAssessmentDetailModel.fromJson(
        _row('a1', category: AssessmentCategory.courseAssignment,
            totalMarks: 40),
      );

      expect(detail.derivedTotalMarks, 40);
    });
  });

  group('AssessmentCategory', () {
    test('counts both quiz categories as quizzes', () {
      expect(AssessmentCategory.isQuiz(AssessmentCategory.quiz), isTrue);
      expect(AssessmentCategory.isQuiz(AssessmentCategory.liveQuiz), isTrue);
      expect(
        AssessmentCategory.isQuiz(AssessmentCategory.courseAssignment),
        isFalse,
      );
      expect(
        AssessmentCategory.isQuiz(AssessmentCategory.courseMaterialAssignment),
        isFalse,
      );
    });

    test('labels every known value and falls through to the raw one', () {
      expect(AssessmentCategory.label(AssessmentCategory.liveQuiz),
          'Live Quiz');
      expect(AssessmentCategory.label('something_new'), 'something_new');
    });
  });

  group('AssessmentsListCubit', () {
    late TeacherAssessmentUseCases assessments;

    /// One payload holding both halves, which is what the API returns — both
    /// tabs read it and keep their own.
    final mixed = _rows([
      _row('a1', category: AssessmentCategory.courseAssignment),
      _row('a2', category: AssessmentCategory.courseMaterialAssignment),
      _row('q1', category: AssessmentCategory.quiz),
      _row('q2', category: AssessmentCategory.liveQuiz),
    ]);

    setUp(() {
      assessments = _MockAssessments();
      when(() => assessments.list(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
            courseMaterialId: any(named: 'courseMaterialId'),
          )).thenAnswer((_) async => Right(mixed));
    });

    test('splits one payload into the tab that owns each row', () async {
      final assignments = _cubit(assessments, quizzes: false);
      final quiz = _cubit(assessments, quizzes: true);
      await assignments.load();
      await quiz.load();

      expect([for (final a in assignments.owned) a.id], ['a1', 'a2']);
      expect([for (final a in quiz.owned) a.id], ['q1', 'q2']);
    });

    test('passes the material scope through and omits the division', () async {
      final cubit = _cubit(
        assessments,
        quizzes: false,
        divisionId: null,
        courseMaterialId: 'm1',
      );
      await cubit.load();

      verify(() => assessments.list(
            courseId: 'c1',
            divisionId: null,
            courseMaterialId: 'm1',
          )).called(1);
    });

    test('reports an empty category, not an empty search', () async {
      when(() => assessments.list(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
            courseMaterialId: any(named: 'courseMaterialId'),
          )).thenAnswer(
        (_) async => Right(_rows([
          _row('q1', category: AssessmentCategory.quiz),
        ])),
      );

      final assignments = _cubit(assessments, quizzes: false);
      await assignments.load();

      // The web tests the *unfiltered* payload here, so a course holding only
      // quizzes tells the teacher "no matches" on the Assignments tab instead
      // of offering to create the first assignment.
      expect(assignments.isEmptyCategory, isTrue);
    });

    test('searches within the owned half only', () async {
      when(() => assessments.list(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
            courseMaterialId: any(named: 'courseMaterialId'),
          )).thenAnswer(
        (_) async => Right(_rows([
          _row('a1', category: AssessmentCategory.courseAssignment,
              title: 'Graph traversal'),
          _row('q1', category: AssessmentCategory.quiz,
              title: 'Graph quiz'),
        ])),
      );

      final assignments = _cubit(assessments, quizzes: false);
      await assignments.load();
      assignments.setSearch('GRAPH');

      expect([for (final a in assignments.matching) a.id], ['a1']);
      expect(assignments.isEmptyCategory, isFalse);
    });

    test('pages the owned half and numbers from the page start', () async {
      when(() => assessments.list(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
            courseMaterialId: any(named: 'courseMaterialId'),
          )).thenAnswer(
        (_) async => Right(_rows([
          for (var i = 0; i < 23; i++)
            _row('a$i', category: AssessmentCategory.courseAssignment),
        ])),
      );

      final cubit = _cubit(assessments, quizzes: false);
      await cubit.load();

      expect(cubit.totalPages, 3);
      expect(cubit.visible, hasLength(AssessmentsListCubit.pageSize));

      cubit.setPage(3);
      expect(cubit.visible, hasLength(3));
      expect(cubit.visible.first.id, 'a20');
    });

    test('clamps a page stranded past the end by a search', () async {
      final cubit = _cubit(assessments, quizzes: false);
      await cubit.load();

      cubit.setPage(5);
      cubit.setSearch('a1');

      // setSearch resets to page one; the clamp is the second guard, for a
      // page set after the list has already shortened.
      expect(cubit.page, 1);
      expect(cubit.visible, isNotEmpty);
    });

    test('surfaces a failure and leaves the rows alone', () async {
      when(() => assessments.list(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
            courseMaterialId: any(named: 'courseMaterialId'),
          )).thenAnswer((_) async => const Left(ServerFailure('boom')));

      final cubit = _cubit(assessments, quizzes: false);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      expect(cubit.owned, isEmpty);
    });

    test('refetches after a delete and returns null on success', () async {
      when(() => assessments.delete(any()))
          .thenAnswer((_) async => const Right(null));

      final cubit = _cubit(assessments, quizzes: false);
      await cubit.load();
      final failure = await cubit.delete('a1');

      expect(failure, isNull);
      verify(() => assessments.list(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
            courseMaterialId: any(named: 'courseMaterialId'),
          )).called(2);
    });

    test('returns the failure and does not refetch when a delete fails',
        () async {
      when(() => assessments.delete(any()))
          .thenAnswer((_) async => const Left(ServerFailure('nope')));

      final cubit = _cubit(assessments, quizzes: false);
      await cubit.load();
      final failure = await cubit.delete('a1');

      expect(failure, isA<ServerFailure>());
      verify(() => assessments.list(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
            courseMaterialId: any(named: 'courseMaterialId'),
          )).called(1);
    });

    test('names the right noun for each tab', () {
      expect(_cubit(assessments, quizzes: false).noun, 'assignment');
      expect(_cubit(assessments, quizzes: true).noun, 'quiz');
      expect(_cubit(assessments, quizzes: true).nounPlural, 'quizzes');
    });
  });

  group('AssessmentFormCubit', () {
    late TeacherAssessmentUseCases assessments;
    late UploadFilesUseCase uploadFiles;

    setUp(() {
      assessments = _MockAssessments();
      uploadFiles = _MockUploadFiles();
    });

    AssessmentFormCubit form({
      required bool quiz,
      String? divisionId = 'd1',
      String? courseMaterialId,
      String? assessmentId,
    }) =>
        AssessmentFormCubit(
          assessments: assessments,
          uploadFiles: uploadFiles,
          courseId: 'c1',
          quiz: quiz,
          divisionId: divisionId,
          courseMaterialId: courseMaterialId,
          assessmentId: assessmentId,
        );

    /// A form filled in far enough to submit.
    void fill(
      AssessmentFormCubit cubit, {
      String start = '2026-09-01T09:00:00.000Z',
      String end = '2026-09-01T11:00:00.000Z',
    }) {
      cubit
        ..setTitle('Graph traversal')
        ..setStartDate(start)
        ..setEndDate(end);
    }

    group('category', () {
      test('is derived from the variant and the material scope', () {
        expect(form(quiz: false).category, AssessmentCategory.courseAssignment);
        expect(
          form(quiz: false, courseMaterialId: 'm1').category,
          AssessmentCategory.courseMaterialAssignment,
        );
        expect(form(quiz: true).category, AssessmentCategory.quiz);
        // A quiz stays a quiz even inside a material panel — the web never
        // creates one there, and the category would be wrong if it did.
        expect(
          form(quiz: true, courseMaterialId: 'm1').category,
          AssessmentCategory.quiz,
        );
      });
    });

    group('validation', () {
      test('needs a title and both ends of the window', () {
        final cubit = form(quiz: false);
        expect(cubit.blocker, 'A title is required.');

        cubit.setTitle('Graph traversal');
        expect(cubit.blocker, 'Set when it opens.');

        cubit.setStartDate('2026-09-01T09:00:00.000Z');
        expect(cubit.blocker, 'Set when it is due.');

        cubit.setEndDate('2026-09-01T11:00:00.000Z');
        expect(cubit.blocker, isNull);
      });

      test('refuses a due date at or before the open date', () {
        final cubit = form(quiz: false);
        fill(
          cubit,
          start: '2026-09-01T11:00:00.000Z',
          end: '2026-09-01T09:00:00.000Z',
        );

        expect(cubit.blocker, 'The due date must be after it opens.');
      });

      test('refuses a title over the server limit', () {
        final cubit = form(quiz: false);
        fill(cubit);
        cubit.setTitle('x' * 501);

        expect(cubit.blocker, contains('longer than 500'));
      });

      test('a quiz needs a time limit', () {
        final cubit = form(quiz: true);
        fill(cubit);
        cubit.setDurationMinutes('0');

        expect(cubit.blocker, 'Set a time limit.');
      });

      test('refuses a time limit longer than the window', () {
        // A two-hour window cannot grant a three-hour attempt; the server
        // rejects it with ASSESSMENT_DURATION_EXCEEDS_WINDOW.
        final cubit = form(quiz: true);
        fill(cubit);
        cubit.setDurationMinutes('180');

        expect(cubit.durationExceedsWindow, isTrue);
        expect(cubit.blocker, contains('120-minute window'));
      });

      test('accepts a time limit that exactly fills the window', () {
        final cubit = form(quiz: true);
        fill(cubit);
        cubit.setDurationMinutes('120');

        expect(cubit.durationExceedsWindow, isFalse);
        expect(cubit.blocker, isNull);
      });

      test('never applies the duration rule to an assignment', () {
        final cubit = form(quiz: false);
        fill(cubit);
        cubit.setDurationMinutes('9999');

        expect(cubit.durationExceedsWindow, isFalse);
        expect(cubit.blocker, isNull);
      });

      test('bounds the violation threshold, but only when proctored', () {
        final cubit = form(quiz: true);
        fill(cubit);
        cubit.setMaxViolations('0');
        expect(cubit.blocker, isNull);

        cubit.setProctored(true);
        expect(cubit.blocker, contains('between 1 and 100'));

        cubit.setMaxViolations('3');
        expect(cubit.blocker, isNull);
      });

      test('bounds the late penalty, but only when late is allowed', () {
        final cubit = form(quiz: false);
        fill(cubit);
        cubit.setLatePenalty('9');
        expect(cubit.blocker, isNull);

        cubit.setLateAllowed(true);
        expect(cubit.blocker, contains('between 0 and 5'));
      });
    });

    group('buildBody', () {
      test('carries the create-only scope fields', () {
        final cubit = form(quiz: false, courseMaterialId: 'm1');
        fill(cubit);

        final body = cubit.buildBody();
        expect(body['category'], AssessmentCategory.courseMaterialAssignment);
        expect(body['courseMaterialId'], 'm1');
        expect(body['divisionId'], 'd1');
        expect(body['isSemesterWide'], isFalse);
      });

      test('omits category and material on edit', () async {
        when(() => assessments.getDetail(any())).thenAnswer(
          (_) async => Right(TeacherAssessmentDetailModel.fromJson(
            _row('a1', category: AssessmentCategory.courseMaterialAssignment),
          )),
        );

        final cubit =
            form(quiz: false, courseMaterialId: 'm1', assessmentId: 'a1');
        await cubit.load();
        fill(cubit);

        final body = cubit.buildBody();
        // The update endpoint applies whatever it receives, so resending these
        // would let an edit silently re-scope the assessment.
        expect(body.containsKey('category'), isFalse);
        expect(body.containsKey('courseMaterialId'), isFalse);
      });

      test('drops the division when semester-wide', () {
        final cubit = form(quiz: false);
        fill(cubit);
        cubit.setSemesterWide(true);

        final body = cubit.buildBody();
        expect(body['isSemesterWide'], isTrue);
        expect(body.containsKey('divisionId'), isFalse);
      });

      test('sends duration and proctoring only for a quiz', () {
        final assignment = form(quiz: false)..setTitle('a');
        expect(assignment.buildBody().containsKey('durationMinutes'), isFalse);
        expect(assignment.buildBody().containsKey('isProctored'), isFalse);

        final quiz = form(quiz: true)
          ..setTitle('q')
          ..setDurationMinutes('45');
        final body = quiz.buildBody();
        expect(body['durationMinutes'], 45);
        expect(body['isProctored'], isFalse);
        // The config only rides along once proctoring is actually on.
        expect(body.containsKey('proctoringConfig'), isFalse);
        expect(body.containsKey('maxViolations'), isFalse);
      });

      test('sends every proctoring signal once enabled', () async {
        final cubit = form(quiz: true);
        await cubit.load();
        fill(cubit);
        cubit
          ..setProctored(true)
          ..setProctoringSignal(ProctoringSignal.copyPaste, false);

        final body = cubit.buildBody();
        final config = body['proctoringConfig'] as Map<String, bool>;
        expect(config.keys, containsAll(ProctoringSignal.options));
        expect(config[ProctoringSignal.copyPaste], isFalse);
        // load() seeds them all on, matching what the server applies.
        expect(config[ProctoringSignal.fullscreen], isTrue);
        expect(body['maxViolations'], 3);
      });

      test('zeroes the late penalty when late submission is off', () {
        final cubit = form(quiz: false)
          ..setTitle('a')
          ..setLatePenalty('4');

        expect(cubit.buildBody()['latePenalty'], 0);

        cubit.setLateAllowed(true);
        expect(cubit.buildBody()['latePenalty'], 4);
      });

      test('sends the typed total for a submission assessment', () {
        final cubit = form(quiz: false)
          ..setTitle('a')
          ..setTotalMarks('40');

        expect(cubit.buildBody()['totalMarks'], 40);
      });

      test('omits an empty pass mark rather than sending zero', () {
        final cubit = form(quiz: false)..setTitle('a');
        expect(cubit.buildBody().containsKey('passingMarks'), isFalse);

        cubit.setPassingMarks('20');
        expect(cubit.buildBody()['passingMarks'], 20);
      });
    });

    group('questions', () {
      final picked = [
        const BankQuestion(
          id: 'q-1',
          title: 'Balance an AVL tree',
          type: QuestionType.coding,
          difficulty: QuestionDifficulty.hard,
          category: QuestionCategory.exam,
          points: 10,
        ),
        const BankQuestion(
          id: 'q-2',
          title: 'Pick the traversal',
          type: QuestionType.mcq,
          difficulty: QuestionDifficulty.easy,
          category: QuestionCategory.practice,
          points: 5,
        ),
      ];

      test('holds picks pending while creating, deduping them', () async {
        final cubit = form(quiz: false);
        await cubit.addQuestions(picked);
        await cubit.addQuestions([picked.first]);

        expect([for (final q in cubit.state.pending) q.id], ['q-1', 'q-2']);
        verifyNever(() => assessments.addQuestion(
              assessmentId: any(named: 'assessmentId'),
              questionId: any(named: 'questionId'),
            ));
      });

      test('derives the total from the pending picks', () async {
        final cubit = form(quiz: false);
        cubit.setType(AssessmentType.questions);
        await cubit.addQuestions(picked);

        expect(cubit.state.derivedMarks, 15);
        expect(cubit.buildBody()['totalMarks'], 15);
      });

      test('attaches immediately in edit mode', () async {
        when(() => assessments.getDetail(any())).thenAnswer(
          (_) async => Right(TeacherAssessmentDetailModel.fromJson(
            _row('a1', category: AssessmentCategory.courseAssignment),
          )),
        );
        when(() => assessments.addQuestion(
              assessmentId: any(named: 'assessmentId'),
              questionId: any(named: 'questionId'),
            )).thenAnswer((_) async => const Right(null));

        final cubit = form(quiz: false, assessmentId: 'a1');
        await cubit.load();
        await cubit.addQuestions(picked);

        expect(cubit.state.pending, isEmpty);
        verify(() => assessments.addQuestion(
              assessmentId: 'a1',
              questionId: 'q-1',
            )).called(1);
        verify(() => assessments.addQuestion(
              assessmentId: 'a1',
              questionId: 'q-2',
            )).called(1);
      });

      test('detaches with the join-row id, not the question id', () async {
        when(() => assessments.getDetail(any())).thenAnswer(
          (_) async => Right(TeacherAssessmentDetailModel.fromJson({
            ..._row('a1', category: AssessmentCategory.courseAssignment),
            'type': AssessmentType.questions,
            'questions': [
              {
                'id': 'join-1',
                'questionId': 'q-1',
                'order': 1,
                'questionPoints': 10,
              },
            ],
          })),
        );
        when(() => assessments.removeQuestion(
              assessmentId: any(named: 'assessmentId'),
              assessmentQuestionId: any(named: 'assessmentQuestionId'),
            )).thenAnswer((_) async => const Right(null));

        final cubit = form(quiz: false, assessmentId: 'a1');
        await cubit.load();
        await cubit.removeAttached(cubit.state.attached.single.id);

        // Passing 'q-1' here detaches nothing and still reports success, which
        // is why the entity keeps the two ids apart.
        verify(() => assessments.removeQuestion(
              assessmentId: 'a1',
              assessmentQuestionId: 'join-1',
            )).called(1);
      });
    });

    group('submit', () {
      test('creates, then attaches the pending questions', () async {
        when(() => assessments.create(any())).thenAnswer(
          (_) async => Right(TeacherAssessmentModel.fromJson(
            _row('new-1', category: AssessmentCategory.courseAssignment),
          )),
        );
        when(() => assessments.addQuestion(
              assessmentId: any(named: 'assessmentId'),
              questionId: any(named: 'questionId'),
            )).thenAnswer((_) async => const Right(null));

        final cubit = form(quiz: false);
        fill(cubit);
        cubit.setType(AssessmentType.questions);
        await cubit.addQuestions([
          const BankQuestion(
            id: 'q-1',
            title: 'Balance an AVL tree',
            type: QuestionType.coding,
            difficulty: QuestionDifficulty.hard,
            category: QuestionCategory.exam,
            points: 10,
          ),
        ]);

        expect(await cubit.submit(), isNull);
        // Questions can only be attached once the assessment has an id.
        verify(() => assessments.create(any())).called(1);
        verify(() => assessments.addQuestion(
              assessmentId: 'new-1',
              questionId: 'q-1',
            )).called(1);
      });

      test('does not attach anything when the create fails', () async {
        when(() => assessments.create(any()))
            .thenAnswer((_) async => const Left(ServerFailure('boom')));

        final cubit = form(quiz: false);
        fill(cubit);

        expect(await cubit.submit(), isA<ServerFailure>());
        expect(cubit.state.isSaving, isFalse);
        verifyNever(() => assessments.addQuestion(
              assessmentId: any(named: 'assessmentId'),
              questionId: any(named: 'questionId'),
            ));
      });

      test('updates rather than creating when editing', () async {
        when(() => assessments.getDetail(any())).thenAnswer(
          (_) async => Right(TeacherAssessmentDetailModel.fromJson(
            _row('a1', category: AssessmentCategory.courseAssignment),
          )),
        );
        when(() => assessments.update(
              id: any(named: 'id'),
              body: any(named: 'body'),
            )).thenAnswer((_) async => const Right(null));

        final cubit = form(quiz: false, assessmentId: 'a1');
        await cubit.load();

        expect(await cubit.submit(), isNull);
        verify(() => assessments.update(
              id: 'a1',
              body: any(named: 'body'),
            )).called(1);
        verifyNever(() => assessments.create(any()));
      });

      test('does nothing while the form is invalid', () async {
        final cubit = form(quiz: false);

        expect(await cubit.submit(), isNull);
        verifyNever(() => assessments.create(any()));
      });

      test('refuses to change the type in edit mode', () async {
        when(() => assessments.getDetail(any())).thenAnswer(
          (_) async => Right(TeacherAssessmentDetailModel.fromJson(
            _row('a1', category: AssessmentCategory.courseAssignment),
          )),
        );

        final cubit = form(quiz: false, assessmentId: 'a1');
        await cubit.load();
        cubit.setType(AssessmentType.questions);

        // Switching a submission to a question paper would orphan every
        // submission already made against it.
        expect(cubit.state.type, AssessmentType.submission);
      });
    });
  });

  group('QuestionBankCubit', () {
    late TeacherAssessmentUseCases assessments;

    Paginated<BankQuestion> page(List<String> ids) => Paginated<BankQuestion>(
          items: [
            for (final id in ids)
              BankQuestion(
                id: id,
                title: 'Question $id',
                type: QuestionType.mcq,
                difficulty: QuestionDifficulty.easy,
                category: QuestionCategory.practice,
                points: 5,
              ),
          ],
          pagination: const Pagination(
            page: 1,
            limit: 8,
            total: 2,
            totalPages: 1,
          ),
        );

    setUp(() {
      assessments = _MockAssessments();
      when(() => assessments.listBankQuestions(
            assessmentId: any(named: 'assessmentId'),
            page: any(named: 'page'),
            limit: any(named: 'limit'),
            search: any(named: 'search'),
            type: any(named: 'type'),
            difficulty: any(named: 'difficulty'),
            category: any(named: 'category'),
          )).thenAnswer((_) async => Right(page(['q-1', 'q-2'])));
    });

    test('hides what the basket already holds', () async {
      // Only matters while creating: the bank endpoint excludes attached
      // questions itself, the active-questions fallback does not.
      final cubit = QuestionBankCubit(
        assessments: assessments,
        excludedIds: const {'q-1'},
      );
      await cubit.load();

      expect([for (final q in cubit.visible) q.id], ['q-2']);
    });

    test('sends no filter params while every filter is "all"', () async {
      final cubit = QuestionBankCubit(assessments: assessments);
      await cubit.load();

      verify(() => assessments.listBankQuestions(
            assessmentId: null,
            page: 1,
            limit: QuestionBankCubit.pageSize,
            search: null,
            type: null,
            difficulty: null,
            category: null,
          )).called(1);
    });

    test('sends the filters once set, and resets to page one', () async {
      final cubit = QuestionBankCubit(
        assessments: assessments,
        assessmentId: 'a1',
      );
      cubit.setPage(3);
      cubit.setType(QuestionType.coding);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.page, 1);
      verify(() => assessments.listBankQuestions(
            assessmentId: 'a1',
            page: 1,
            limit: QuestionBankCubit.pageSize,
            search: null,
            type: QuestionType.coding,
            difficulty: null,
            category: null,
          )).called(1);
    });
  });

  group('ApiUrls', () {
    test('shapes the assessment paths', () {
      expect(ApiUrls.assessments, '/assessments');
      expect(ApiUrls.assessment('a1'), '/assessments/a1');
      expect(ApiUrls.assessmentQuestions('a1'), '/assessments/a1/questions');
      expect(
        ApiUrls.assessmentQuestion('a1', 'join-1'),
        '/assessments/a1/questions/join-1',
      );
      expect(
        ApiUrls.assessmentQuestionBank('a1'),
        '/assessments/a1/questions/bank',
      );
      expect(
        ApiUrls.assessmentPublishResults('a1'),
        '/assessments/a1/publish-results',
      );
    });
  });

  group('screens', () {
    late TeacherAssessmentUseCases assessments;

    setUp(() {
      assessments = _MockAssessments();
      when(() => assessments.list(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
            courseMaterialId: any(named: 'courseMaterialId'),
          )).thenAnswer(
        (_) async => Right(_rows([
          _row('a1', category: AssessmentCategory.courseAssignment,
              title: 'Graph traversal', passingMarks: 20),
          _row('q1', category: AssessmentCategory.quiz, title: 'Trees quiz'),
        ])),
      );
    });

    Widget host(ParityHost h, Widget child, {required bool quizzes,
        String? courseMaterialId}) =>
        h(Scaffold(
          body: BlocProvider(
            create: (_) => _cubit(
              assessments,
              quizzes: quizzes,
              divisionId: courseMaterialId == null ? 'd1' : null,
              courseMaterialId: courseMaterialId,
            ),
            child: child,
          ),
        ));

    bothPlatforms('the Assignments tab lists only its own half', (t, h) async {
      await t.pumpWidget(
        host(h, const AssessmentsTab(), quizzes: false),
      );
      await t.pumpAndSettle();

      expect(find.text('Graph traversal'), findsOneWidget);
      expect(find.text('Trees quiz'), findsNothing);
      expect(find.text('Search assignments'), findsOneWidget);
      expect(find.text('pass 20'), findsOneWidget);
    });

    bothPlatforms('the Quiz tab says "quiz", never "assignment"', (t, h) async {
      await t.pumpWidget(host(h, const AssessmentsTab(), quizzes: true));
      await t.pumpAndSettle();

      expect(find.text('Trees quiz'), findsOneWidget);
      expect(find.text('Graph traversal'), findsNothing);
      expect(find.text('Search quizzes'), findsOneWidget);
    });

    bothPlatforms('an empty category offers to create the first one',
        (t, h) async {
      when(() => assessments.list(
            courseId: any(named: 'courseId'),
            divisionId: any(named: 'divisionId'),
            courseMaterialId: any(named: 'courseMaterialId'),
          )).thenAnswer(
        (_) async => Right(_rows([
          _row('q1', category: AssessmentCategory.quiz),
        ])),
      );

      await t.pumpWidget(host(h, const AssessmentsTab(), quizzes: false));
      await t.pumpAndSettle();

      expect(find.text('No assignments yet'), findsOneWidget);
      expect(find.text('No matching assignments'), findsNothing);
    });

    /// The form pumped directly, with its cubit already seeded.
    Widget formHost(
      ParityHost h, {
      required bool quiz,
      String? assessmentId,
      String? divisionId = 'd1',
      String? courseMaterialId,
    }) =>
        h(Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: BlocProvider(
              create: (_) => AssessmentFormCubit(
                assessments: assessments,
                uploadFiles: _MockUploadFiles(),
                courseId: 'c1',
                quiz: quiz,
                divisionId: divisionId,
                courseMaterialId: courseMaterialId,
                assessmentId: assessmentId,
              )..load(),
              child: const AssessmentFormBody(),
            ),
          ),
        ));

    bothPlatforms('the assignment form hides the quiz-only sections',
        (t, h) async {
      await t.pumpWidget(formHost(h, quiz: false));
      await t.pumpAndSettle();

      expect(find.text('BASICS'), findsOneWidget);
      expect(find.text('SCORING'), findsOneWidget);
      expect(find.text('ADVANCED'), findsOneWidget);
      // Duration and proctoring are quiz-only concepts.
      expect(find.text('PROCTORING'), findsNothing);
      expect(find.text('Time limit (minutes)'), findsNothing);
      expect(find.text('Create assignment'), findsOneWidget);
    });

    bothPlatforms('the quiz form carries duration and proctoring',
        (t, h) async {
      await t.pumpWidget(formHost(h, quiz: true));
      await t.pumpAndSettle();

      expect(find.text('Time limit (minutes)'), findsOneWidget);
      expect(find.text('PROCTORING'), findsOneWidget);
      expect(find.text('Create quiz'), findsOneWidget);
      // The six signal toggles stay hidden until proctoring is switched on.
      expect(find.text('Block printing'), findsNothing);
    });

    bothPlatforms('the form locks the type in edit mode', (t, h) async {
      when(() => assessments.getDetail(any())).thenAnswer(
        (_) async => Right(TeacherAssessmentDetailModel.fromJson(
          _row('a1', category: AssessmentCategory.courseAssignment,
              title: 'Graph traversal'),
        )),
      );

      await t.pumpWidget(formHost(h, quiz: false, assessmentId: 'a1'));
      await t.pumpAndSettle();

      expect(find.text('The type cannot be changed after creation.'),
          findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    bothPlatforms('the form drops the scope switch without a section',
        (t, h) async {
      await t.pumpWidget(formHost(
        h,
        quiz: false,
        divisionId: null,
        courseMaterialId: 'm1',
      ));
      await t.pumpAndSettle();

      // A material assignment has no section to scope to, so the choice does
      // not arise.
      expect(find.text('Semester-wide'), findsNothing);
    });

    /// The view sheet resolves its own use cases, so the locator has to hold
    /// the mock for the duration of the pump.
    void provide(TeacherAssessmentUseCases mock) {
      if (sl.isRegistered<TeacherAssessmentUseCases>()) {
        sl.unregister<TeacherAssessmentUseCases>();
      }
      sl.registerSingleton<TeacherAssessmentUseCases>(mock);
      addTearDown(() => sl.unregister<TeacherAssessmentUseCases>());
    }

    bothPlatforms('the detail sheet leads with the window and the numbers',
        (t, h) async {
      provide(assessments);
      when(() => assessments.getDetail(any())).thenAnswer(
        (_) async => Right(TeacherAssessmentDetailModel.fromJson({
          ..._row('a1', category: AssessmentCategory.quiz,
              title: 'test quiz 01', totalMarks: 5),
          'type': AssessmentType.questions,
          // 08:08 → 08:45 on one day: a 37-minute window.
          'startDate': '2026-08-20T08:08:00.000Z',
          'endDate': '2026-08-20T08:45:00.000Z',
          'maxAttempt': 1,
          'durationMinutes': 30,
          'isProctored': true,
          'maxViolations': 3,
          'questions': [
            {
              'id': 'j1',
              'questionId': 'q1',
              'order': 1,
              'questionTitle': 'What is the codomain of f(x) = x^2?',
              'questionType': QuestionType.mcq,
              'questionDifficulty': QuestionDifficulty.easy,
              'questionPoints': 1,
            },
          ],
        })),
      );

      await t.pumpWidget(h(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showAssessmentViewSheet(context, assessmentId: 'a1'),
            child: const Text('open'),
          ),
        ),
      )));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();

      expect(find.text('test quiz 01'), findsOneWidget);
      // The window's length is stated, not left for the reader to subtract.
      expect(find.text('Open for 37 min'), findsOneWidget);
      // Numbers are tiles now, and the marks come from the questions.
      expect(find.text('Marks'), findsOneWidget);
      expect(find.text('Attempts'), findsOneWidget);
      expect(find.text('Time limit'), findsOneWidget);
      // The booleans that are off no longer spend a row each saying so.
      expect(find.text('Not allowed'), findsNothing);
      expect(find.text('Proctored · max 3'), findsOneWidget);
      expect(find.text('QUESTIONS'), findsOneWidget);
    });

    bothPlatforms('the detail sheet says so when no rule is set', (t, h) async {
      provide(assessments);
      when(() => assessments.getDetail(any())).thenAnswer(
        (_) async => Right(TeacherAssessmentDetailModel.fromJson(
          _row('a1', category: AssessmentCategory.courseAssignment),
        )),
      );

      await t.pumpWidget(h(Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showAssessmentViewSheet(context, assessmentId: 'a1'),
            child: const Text('open'),
          ),
        ),
      )));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();

      expect(
        find.text('No late submission, no resubmission, not proctored.'),
        findsOneWidget,
      );
      // A submission assignment has no time limit and no question list.
      expect(find.text('Time limit'), findsNothing);
      expect(find.text('QUESTIONS'), findsNothing);
    });

    bothPlatforms('the material panel scopes to the material', (t, h) async {
      await t.pumpWidget(host(
        h,
        const MaterialAssignmentsPanel(courseMaterialId: 'm1'),
        quizzes: false,
        courseMaterialId: 'm1',
      ));
      await t.pumpAndSettle();

      expect(find.text('Assignments (1)'), findsOneWidget);
      expect(find.text('Scoped to this material'), findsOneWidget);
      expect(find.text('Graph traversal'), findsOneWidget);
    });
  });
}
