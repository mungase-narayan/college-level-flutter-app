import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/teacher/courses/data/models/teacher_course_model.dart';
import 'package:college_level/features/teacher/courses/data/models/teacher_course_tree_model.dart';
import 'package:college_level/features/teacher/courses/domain/entities/teacher_course.dart';
import 'package:college_level/features/teacher/courses/domain/entities/teacher_course_tree.dart';
import 'package:college_level/features/teacher/courses/domain/usecases/teacher_course_usecases.dart';
import 'package:college_level/features/teacher/courses/presentation/bloc/teacher_course_detail_cubit.dart';
import 'package:college_level/features/teacher/courses/presentation/bloc/teacher_courses_cubit.dart';
import 'package:college_level/features/teacher/courses/presentation/pages/teacher_course_detail_page.dart';
import 'package:college_level/features/teacher/courses/presentation/pages/teacher_courses_page.dart';
import 'package:college_level/features/teacher/courses/presentation/widgets/learning_plan_tab.dart';
import 'package:college_level/features/shared/auth/domain/entities/auth_session.dart';
import 'package:college_level/features/shared/auth/domain/entities/user.dart';
import 'package:college_level/features/shared/auth/presentation/bloc/auth/auth_bloc.dart';

import '../support/platform_parity.dart';

class _MockListCourses extends Mock implements ListTeacherCoursesUseCase {}

class _MockListDivisions extends Mock implements ListCourseDivisionsUseCase {}

class _MockGetTree extends Mock implements GetTeacherCourseTreeUseCase {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

/// One assignment row, as `GET /teacher/courses` sends it.
Map<String, dynamic> _row({
  required String courseId,
  required String divisionId,
  String divisionName = 'A',
  String name = 'Data Structures',
  String code = 'CS201',
  String type = 'regular',
  String status = 'active',
  Object? credits = 4,
}) =>
    {
      'id': 'ci-$courseId-$divisionId',
      'status': 'active',
      'divisionId': divisionId,
      'course': {
        'id': courseId,
        'name': name,
        'code': code,
        'type': type,
        'status': status,
        'credits': credits,
        'colorCode': '#4F46E5',
        'department': {'id': 'd1', 'name': 'Computer Engineering', 'code': 'CE'},
        'semester': {'id': 's1', 'code': '3', 'isCurrent': true},
        'division': {'id': divisionId, 'name': divisionName, 'code': divisionName},
      },
    };

TeacherCourseTree _tree({List<TeacherModule> modules = const []}) =>
    TeacherCourseTree(
      id: 'c1',
      name: 'Data Structures',
      code: 'CS201',
      type: 'regular',
      status: 'active',
      credits: 4,
      modules: modules,
      instructors: const [],
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const TeacherCourseListParams());
    registerFallbackValue(const IdParams('x'));
    registerFallbackValue(const CourseTreeParams(courseId: 'x'));
  });

  group('TeacherAssignedCourseModel', () {
    test('parses an assignment row', () {
      final row = TeacherAssignedCourseModel.fromJson(
        _row(courseId: 'c1', divisionId: 'd1'),
      );

      expect(row.divisionId, 'd1');
      expect(row.course.name, 'Data Structures');
      expect(row.course.code, 'CS201');
      expect(row.course.credits, 4);
      expect(row.course.department?.code, 'CE');
      expect(row.course.semester?.isCurrent, isTrue);
      expect(row.course.division?.label, 'A');
    });

    /// Regression: Postgres `numeric` columns arrive as **strings** through the
    /// pg driver, and a bare `as num?` threw on them — which surfaced as
    /// "Something went wrong" over the whole course list rather than as a bad
    /// field.
    test('accepts a numeric sent as a string', () {
      final row = TeacherAssignedCourseModel.fromJson(
        _row(courseId: 'c1', divisionId: 'd1', credits: '4'),
      );

      expect(row.course.credits, 4);
    });

    /// Regression, and the one that actually broke the screen: the API sends
    /// `semester.code` as a **number** for numeric semesters, so the display
    /// string `"3"` arrives as `3`. The `as String?` cast threw inside
    /// `RepositoryGuard`, which surfaced as "Something went wrong" over the
    /// whole list with no indication of which field was at fault.
    test('accepts a code sent as a number', () {
      final row = TeacherAssignedCourseModel.fromJson({
        'id': 'ci1',
        'status': 'active',
        'divisionId': 'd1',
        'course': {
          'id': 'c1',
          'name': 'DS',
          'code': 'CS201',
          'credits': 4,
          'semester': {'id': 's1', 'code': 3, 'isCurrent': true},
          'division': {'id': 'd1', 'name': 1, 'code': 1},
        },
      });

      expect(row.course.semester?.code, '3');
      // Divisions are commonly named "1"/"2" and hit the same problem.
      expect(row.course.division?.label, '1');
    });

    test('a non-numeric credits degrades to zero rather than throwing', () {
      final row = TeacherAssignedCourseModel.fromJson(
        _row(courseId: 'c1', divisionId: 'd1', credits: 'n/a'),
      );

      expect(row.course.credits, 0);
    });

    test('missing nested objects are absent, not empty shells', () {
      final row = TeacherAssignedCourseModel.fromJson(const {
        'id': 'ci1',
        'status': 'active',
        'divisionId': 'd1',
        'course': {'id': 'c1', 'name': 'X', 'code': 'X1'},
      });

      expect(row.course.department, isNull);
      expect(row.course.semester, isNull);
      expect(row.course.division, isNull);
    });
  });

  group('CourseDivision.label', () {
    test('falls back name → code → Section', () {
      expect(const CourseDivision(id: 'd', name: 'A', code: 'A').label, 'A');
      expect(const CourseDivision(id: 'd', code: 'B').label, 'B');
      expect(const CourseDivision(id: 'd').label, 'Section');
    });
  });

  group('TeacherCoursesCubit grouping', () {
    late _MockListCourses listCourses;

    setUp(() => listCourses = _MockListCourses());

    void stub(List<Map<String, dynamic>> rows) {
      when(() => listCourses(any())).thenAnswer(
        (_) async => Right(
          rows.map(TeacherAssignedCourseModel.fromJson).toList(),
        ),
      );
    }

    test('folds the sections of one course into a single card', () async {
      // The endpoint sends one row per (course, division). Left ungrouped the
      // teacher would see the same course three times.
      stub([
        _row(courseId: 'c1', divisionId: 'd1', divisionName: 'A'),
        _row(courseId: 'c1', divisionId: 'd2', divisionName: 'B'),
        _row(courseId: 'c2', divisionId: 'd3', name: 'Algorithms', code: 'CS301'),
      ]);

      final cubit = TeacherCoursesCubit(listCourses: listCourses);
      await cubit.load();

      final groups = cubit.state.data!;
      expect(groups, hasLength(2));
      expect(groups.first.sections, hasLength(2));
      expect(groups.first.sectionLabel, '2 sections');
      expect(groups.last.sectionLabel, 'Div A');
      await cubit.close();
    });

    test('search matches name, code, department, and division', () async {
      stub([
        _row(courseId: 'c1', divisionId: 'd1'),
        _row(
          courseId: 'c2',
          divisionId: 'd2',
          name: 'Thermodynamics',
          code: 'ME101',
        ),
      ]);

      final cubit = TeacherCoursesCubit(listCourses: listCourses);
      await cubit.load();

      cubit.setSearch('CS201');
      expect(cubit.state.data, hasLength(1));

      cubit.setSearch('thermo');
      expect(cubit.state.data!.single.course.code, 'ME101');

      cubit.setSearch('computer engineering');
      expect(cubit.state.data, hasLength(2));

      cubit.setSearch('');
      expect(cubit.state.data, hasLength(2));
      await cubit.close();
    });

    test('type filters client-side and status refetches', () async {
      stub([
        _row(courseId: 'c1', divisionId: 'd1'),
        _row(courseId: 'c2', divisionId: 'd2', type: 'laboratory'),
      ]);

      final cubit = TeacherCoursesCubit(listCourses: listCourses);
      await cubit.load();

      cubit.setType('laboratory');
      expect(cubit.state.data, hasLength(1));
      // Type never reaches the server — one call so far.
      verify(() => listCourses(any())).called(1);

      // Status is the one filter the API owns, so it must refetch.
      await cubit.setStatus('archived');
      final params = verify(() => listCourses(captureAny())).captured.last;
      expect((params as TeacherCourseListParams).status, 'archived');
      await cubit.close();
    });

    test('hasFilters drives which empty-state copy is shown', () async {
      stub([]);
      final cubit = TeacherCoursesCubit(listCourses: listCourses);
      await cubit.load();

      expect(cubit.hasFilters, isFalse);
      cubit.setSearch('nothing');
      expect(cubit.hasFilters, isTrue);
      await cubit.close();
    });

    test('surfaces a failure instead of an empty list', () async {
      when(() => listCourses(any()))
          .thenAnswer((_) async => const Left(ServerFailure('boom')));

      final cubit = TeacherCoursesCubit(listCourses: listCourses);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      await cubit.close();
    });
  });

  group('TeacherCourseTreeModel scope rules', () {
    Map<String, dynamic> node({
      String? divisionId,
      bool? isGlobal,
      String createdBy = 'me',
    }) =>
        {
          'id': 'm1',
          'courseId': 'c1',
          'name': 'Trees',
          'order': 1,
          'createdBy': createdBy,
          'divisionId': divisionId,
          'isGlobal': ?isGlobal,
          'creator': {'id': createdBy, 'fullName': 'Admin User'},
          'topics': <dynamic>[],
        };

    test('a null divisionId means school-wide even without the flag', () {
      final module = TeacherModuleModel.fromJson(node());
      expect(module.isGlobal, isTrue);
    });

    test('a division-scoped node is not global', () {
      final module = TeacherModuleModel.fromJson(node(divisionId: 'd1'));
      expect(module.isGlobal, isFalse);
      expect(module.scope.divisionId, 'd1');
    });

    test('school-wide content is read-only to its own author', () {
      // The server answers 403 COURSE_CONTENT_READ_ONLY regardless of who
      // wrote it, so the menu must not be offered.
      final module = TeacherModuleModel.fromJson(node(createdBy: 'me'));
      expect(module.canManage('me'), isFalse);
    });

    test('only the author may manage division-scoped content', () {
      final mine = TeacherModuleModel.fromJson(
        node(divisionId: 'd1', createdBy: 'me'),
      );
      final theirs = TeacherModuleModel.fromJson(
        node(divisionId: 'd1', createdBy: 'someone-else'),
      );

      expect(mine.canManage('me'), isTrue);
      expect(theirs.canManage('me'), isFalse);
    });

    test('the rule holds at topic and material level too', () {
      final topic = TeacherTopicModel.fromJson(const {
        'id': 't1',
        'courseId': 'c1',
        'courseModuleId': 'm1',
        'name': 'AVL',
        'order': 1,
        'createdBy': 'me',
        'divisionId': null,
        'materials': <dynamic>[],
      });
      final material = TeacherMaterialModel.fromJson(const {
        'id': 'x1',
        'courseId': 'c1',
        'courseModuleId': 'm1',
        'courseTopicId': 't1',
        'name': 'Notes',
        'order': 1,
        'createdBy': 'me',
        'divisionId': 'd1',
      });

      expect(topic.canManage('me'), isFalse);
      expect(material.canManage('me'), isTrue);
    });

    test('material kind drives the tree icon', () {
      TeacherMaterial build(Map<String, dynamic> extra) =>
          TeacherMaterialModel.fromJson({
            'id': 'x',
            'courseId': 'c',
            'courseModuleId': 'm',
            'courseTopicId': 't',
            'name': 'N',
            'order': 1,
            'divisionId': 'd1',
            ...extra,
          });

      expect(build({'videoUrl': 'https://x'}).kind, TeacherMaterialKind.video);
      expect(build({'attachments': ['f1']}).kind, TeacherMaterialKind.file);
      expect(build(const {}).kind, TeacherMaterialKind.reading);
    });

    test('instructor identity is read from the nested user object', () {
      final instructor = CourseInstructorModel.fromJson(const {
        'id': 'ci1',
        'designation': 'Assistant Professor',
        'division': {'id': 'd1', 'name': 'A', 'code': 'A'},
        'user': {'fullName': 'Asha Rao', 'email': 'asha@x.edu', 'avatar': null},
      });

      expect(instructor.fullName, 'Asha Rao');
      expect(instructor.subtitle, 'Assistant Professor · asha@x.edu');
      expect(instructor.division?.label, 'A');
    });

    test('the tree counts topics and materials across modules', () {
      final tree = TeacherCourseTreeModel.fromJson(const {
        'id': 'c1',
        'name': 'DS',
        'code': 'CS201',
        'credits': 4,
        'modules': [
          {
            'id': 'm1',
            'name': 'A',
            'order': 1,
            'divisionId': 'd1',
            'topics': [
              {
                'id': 't1',
                'name': 'T',
                'order': 1,
                'divisionId': 'd1',
                'materials': [
                  {'id': 'x1', 'name': 'M', 'order': 1, 'divisionId': 'd1'},
                  {'id': 'x2', 'name': 'N', 'order': 2, 'divisionId': 'd1'},
                ],
              },
            ],
          },
        ],
      });

      expect(tree.totalTopics, 1);
      expect(tree.totalMaterials, 2);
      expect(tree.locate('x2')?.topic.id, 't1');
      expect(tree.locate('nope'), isNull);
    });
  });

  group('TeacherCourseDetailCubit', () {
    late _MockListDivisions listDivisions;
    late _MockGetTree getTree;

    setUp(() {
      listDivisions = _MockListDivisions();
      getTree = _MockGetTree();
    });

    test('defaults to the first division and scopes the tree to it', () async {
      when(() => listDivisions(any())).thenAnswer(
        (_) async => const Right([
          CourseDivision(id: 'd1', name: 'A'),
          CourseDivision(id: 'd2', name: 'B'),
        ]),
      );
      when(() => getTree(any())).thenAnswer((_) async => Right(_tree()));

      final cubit = TeacherCourseDetailCubit(
        listDivisions: listDivisions,
        getTree: getTree,
        courseId: 'c1',
      );
      await cubit.load();

      expect(cubit.divisionId, 'd1');
      expect(cubit.state.data!.showDivisionPicker, isTrue);
      final params = verify(() => getTree(captureAny())).captured.single;
      expect((params as CourseTreeParams).divisionId, 'd1');
      await cubit.close();
    });

    test('a single section hides the picker', () async {
      when(() => listDivisions(any())).thenAnswer(
        (_) async => const Right([CourseDivision(id: 'd1', name: 'A')]),
      );
      when(() => getTree(any())).thenAnswer((_) async => Right(_tree()));

      final cubit = TeacherCourseDetailCubit(
        listDivisions: listDivisions,
        getTree: getTree,
        courseId: 'c1',
      );
      await cubit.load();

      expect(cubit.state.data!.showDivisionPicker, isFalse);
      await cubit.close();
    });

    test('selecting a section refetches the tree for it', () async {
      when(() => listDivisions(any())).thenAnswer(
        (_) async => const Right([
          CourseDivision(id: 'd1', name: 'A'),
          CourseDivision(id: 'd2', name: 'B'),
        ]),
      );
      when(() => getTree(any())).thenAnswer((_) async => Right(_tree()));

      final cubit = TeacherCourseDetailCubit(
        listDivisions: listDivisions,
        getTree: getTree,
        courseId: 'c1',
      );
      await cubit.load();
      await cubit.selectDivision('d2');

      expect(cubit.divisionId, 'd2');
      final captured = verify(() => getTree(captureAny())).captured;
      expect((captured.last as CourseTreeParams).divisionId, 'd2');
      // Divisions are fetched once, not per selection.
      verify(() => listDivisions(any())).called(1);
      await cubit.close();
    });

    test('re-selecting the current section is a no-op', () async {
      when(() => listDivisions(any())).thenAnswer(
        (_) async => const Right([CourseDivision(id: 'd1', name: 'A')]),
      );
      when(() => getTree(any())).thenAnswer((_) async => Right(_tree()));

      final cubit = TeacherCourseDetailCubit(
        listDivisions: listDivisions,
        getTree: getTree,
        courseId: 'c1',
      );
      await cubit.load();
      await cubit.selectDivision('d1');

      verify(() => getTree(any())).called(1);
      await cubit.close();
    });

    test('a divisions failure stops before requesting a tree', () async {
      when(() => listDivisions(any()))
          .thenAnswer((_) async => const Left(ForbiddenFailure('nope')));

      final cubit = TeacherCourseDetailCubit(
        listDivisions: listDivisions,
        getTree: getTree,
        courseId: 'c1',
      );
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      verifyNever(() => getTree(any()));
      await cubit.close();
    });
  });

  group('screens', () {
    late _MockAuthBloc auth;

    const user = User(
      id: 'me',
      schoolId: 's1',
      firstName: 'Asha',
      lastName: 'Rao',
      email: 'asha@x.edu',
      username: 'asha',
      isEmailVerified: true,
      status: 'active',
    );

    setUp(() {
      auth = _MockAuthBloc();
      whenListen(
        auth,
        const Stream<AuthState>.empty(),
        initialState: const AuthState(
          status: AuthStatus.authenticated,
          session: AuthSession(
            user: user,
            roles: [],
            tokens: Tokens(accessToken: 'a', refreshToken: 'r'),
          ),
        ),
      );
    });

    Widget wrap(ParityHost host, Widget child) => host(
          BlocProvider<AuthBloc>.value(value: auth, child: child),
        );

    // ── Courses list ────────────────────────────────────────────────────────

    bothPlatforms('the list shows search and the filter button',
        (tester, host) async {
      final listCourses = _MockListCourses();
      when(() => listCourses(any())).thenAnswer((_) async => const Right([]));

      await tester.pumpWidget(
        wrap(
          host,
          BlocProvider(
            create: (_) => TeacherCoursesCubit(listCourses: listCourses),
            child: const TeacherCoursesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search by name, code, or department'), findsOneWidget);
      // The two inline selects were replaced by one filter button, matching
      // every student list.
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.text('No courses assigned'), findsOneWidget);
    });

    bothPlatforms('a multi-section course renders as one card',
        (tester, host) async {
      final listCourses = _MockListCourses();
      when(() => listCourses(any())).thenAnswer(
        (_) async => Right([
          for (final d in ['d1', 'd2'])
            TeacherAssignedCourseModel.fromJson(
              _row(courseId: 'c1', divisionId: d, divisionName: d),
            ),
        ]),
      );

      await tester.pumpWidget(
        wrap(
          host,
          BlocProvider(
            create: (_) => TeacherCoursesCubit(listCourses: listCourses),
            child: const TeacherCoursesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.textContaining('2 sections'), findsOneWidget);
    });

    // ── Detail shell ────────────────────────────────────────────────────────

    Widget detail({required List<CourseDivision> divisions}) {
      final listDivisions = _MockListDivisions();
      final getTree = _MockGetTree();
      when(() => listDivisions(any())).thenAnswer((_) async => Right(divisions));
      when(() => getTree(any())).thenAnswer((_) async => Right(_tree()));

      return BlocProvider(
        create: (_) => TeacherCourseDetailCubit(
          listDivisions: listDivisions,
          getTree: getTree,
          courseId: 'c1',
        ),
        child: const TeacherCourseDetailPage(courseId: 'c1'),
      );
    }

    bothPlatforms('the detail shell carries all seven tabs, Analytics locked',
        (tester, host) async {
      await tester.pumpWidget(
        wrap(host, detail(divisions: const [CourseDivision(id: 'd1', name: 'A')])),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'Course Details',
        'Learning Plan',
        'Enrollments',
        'Assignments',
        'Quiz',
        'Attendance',
        'Analytics',
      ]) {
        expect(find.text(label), findsWidgets, reason: '\$label tab missing');
      }
      // Analytics is visible but not selectable — the padlock is the tell.
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    bothPlatforms('the division picker is hidden for a single section',
        (tester, host) async {
      await tester.pumpWidget(
        wrap(host, detail(divisions: const [CourseDivision(id: 'd1', name: 'A')])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Section'), findsNothing);
    });

    bothPlatforms('the division picker appears with more than one section',
        (tester, host) async {
      await tester.pumpWidget(
        wrap(
          host,
          detail(
            divisions: const [
              CourseDivision(id: 'd1', name: 'A'),
              CourseDivision(id: 'd2', name: 'B'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Section'), findsOneWidget);
    });

    // ── Learning plan tree ──────────────────────────────────────────────────

    TeacherModule module({
      required String createdBy,
      String? divisionId = 'd1',
    }) =>
        TeacherModuleModel.fromJson({
          'id': 'm1',
          'courseId': 'c1',
          'name': 'Trees',
          'order': 1,
          'createdBy': createdBy,
          'divisionId': divisionId,
          'creator': {'id': createdBy, 'fullName': 'Admin User'},
          'topics': const <dynamic>[],
        });

    Widget plan(TeacherModule m) => LearningPlanTab(
          tree: _tree(modules: [m]),
          courseId: 'c1',
          divisionId: 'd1',
        );

    bothPlatforms('an owned module offers its row menu', (tester, host) async {
      await tester.pumpWidget(
        wrap(host, Scaffold(body: plan(module(createdBy: 'me')))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trees'), findsOneWidget);
      expect(find.text('Curriculum'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
      // Adding inside is always offered.
      expect(find.text('Add topic'), findsOneWidget);
    });

    bothPlatforms('school-wide content is badged and has no row menu',
        (tester, host) async {
      await tester.pumpWidget(
        wrap(
          host,
          Scaffold(body: plan(module(createdBy: 'me', divisionId: null))),
        ),
      );
      await tester.pumpAndSettle();

      // Read-only even to the author — the server enforces the same.
      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
      expect(find.byIcon(Icons.public_rounded), findsOneWidget);
      // …but a teacher may still add their own topics inside it.
      expect(find.text('Add topic'), findsOneWidget);
    });

    bothPlatforms("another teacher's module is read-only", (tester, host) async {
      await tester.pumpWidget(
        wrap(host, Scaffold(body: plan(module(createdBy: 'someone-else')))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    });

    bothPlatforms('an empty curriculum invites the first module',
        (tester, host) async {
      await tester.pumpWidget(
        wrap(
          host,
          const Scaffold(
            body: LearningPlanTab(
              tree: TeacherCourseTree(
                id: 'c1',
                name: 'DS',
                code: 'CS201',
                type: 'regular',
                status: 'active',
                credits: 4,
                modules: [],
                instructors: [],
              ),
              courseId: 'c1',
              divisionId: 'd1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No modules yet'), findsOneWidget);
    });
  });

  group('endpoints', () {
    test('the teacher course paths match the backend router', () {
      expect(ApiUrls.teacherCourses, '/teacher/courses');
      expect(
        ApiUrls.teacherCourseDivisions('c1'),
        '/teacher/courses/c1/divisions',
      );
      expect(ApiUrls.teacherCourseTree('c1'), '/teacher/courses/c1/tree');
      expect(ApiUrls.teacherCourseModules, '/teacher/course-modules');
      expect(ApiUrls.teacherCourseModule('m1'), '/teacher/course-modules/m1');
      expect(ApiUrls.teacherCourseTopics, '/teacher/course-topics');
      expect(ApiUrls.teacherCourseTopic('t1'), '/teacher/course-topics/t1');
      expect(ApiUrls.teacherCourseMaterials, '/teacher/course-materials');
      expect(
        ApiUrls.teacherCourseMaterial('x1'),
        '/teacher/course-materials/x1',
      );
    });
  });
}
