import 'package:college_level/core/config/theme/app_theme.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/features/student/courses/domain/entities/course.dart';
import 'package:college_level/features/student/courses/domain/entities/course_tree.dart';
import 'package:college_level/features/shared/material_comments/domain/entities/material_comment.dart';
import 'package:college_level/features/student/courses/domain/repositories/course_repository.dart';
import 'package:college_level/features/student/courses/domain/usecases/course_usecases.dart';
import 'package:college_level/features/student/courses/presentation/bloc/courses_cubit.dart';
import 'package:college_level/features/student/courses/presentation/pages/material_detail_page.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// The material page derives everything it shows from the course tree on every
/// build, so a completion toggle that refetches shows through with no state to
/// keep in sync. These tests pin that, plus the two things about the tab strip
/// the web is specific about: Video only exists when the material has one, and
/// Attachments carries the file count.
const _progress = CourseProgress(totalMaterials: 1, completedMaterials: 0);

CourseTree _treeWith(CourseMaterial material) => CourseTree(
      id: 'course-1',
      name: 'Data Structures',
      code: 'CS201',
      progress: _progress,
      modules: [
        CourseModule(
          id: 'module-1',
          name: 'Module one',
          order: 1,
          progress: _progress,
          topics: [
            CourseTopic(
              id: 'topic-1',
              name: 'Topic one',
              order: 1,
              progress: _progress,
              materials: [material],
            ),
          ],
        ),
      ],
    );

CourseMaterial _material({
  String? videoUrl,
  List<String> attachments = const [],
  String? content,
  bool completed = false,
}) =>
    CourseMaterial(
      id: 'material-1',
      courseId: 'course-1',
      name: 'Binary search',
      order: 1,
      completed: completed,
      description: 'How halving the search space works.',
      content: content,
      videoUrl: videoUrl,
      attachments: attachments,
    );

/// Records the completion writes the page makes and serves a tree the test
/// controls, so the page can be exercised without a backend.
///
/// A write is applied to the stored tree, because `toggleMaterial` reloads
/// after every successful write — a fake that kept serving the old tree would
/// make the optimistic update look like it had been reverted.
class _FakeCourseRepository implements CourseRepository {
  _FakeCourseRepository(this.tree);

  CourseTree tree;
  final List<({String materialId, bool completed})> writes = [];

  @override
  Future<Either<Failure, CourseTree>> getCourseTree(String courseId) async =>
      Right(tree);

  @override
  Future<Either<Failure, Unit>> setMaterialCompleted({
    required String materialId,
    required bool completed,
  }) async {
    writes.add((materialId: materialId, completed: completed));

    final located = tree.locate(materialId);
    if (located != null) {
      tree = _treeWith(located.material.copyWith(completed: completed));
    }
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Course>> getCourse(String courseId) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Paginated<CourseEnrollment>>> listEnrolledCourses({
    int page = 1,
    int limit = 100,
    String? semesterId,
    String? status,
    String? search,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<MaterialComment>>> listComments(
    String materialId, {
    String? divisionId,
  }) async =>
      const Right([]);

  @override
  Future<Either<Failure, MaterialComment>> createComment({
    required String materialId,
    required String content,
    String? divisionId,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, MaterialComment>> replyToComment({
    required String commentId,
    required String content,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, MaterialComment>> updateComment({
    required String commentId,
    required String content,
  }) async =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Unit>> deleteComment(String commentId) async =>
      throw UnimplementedError();
}

Future<_FakeCourseRepository> _pump(
  WidgetTester tester,
  CourseMaterial material,
) async {
  final repository = _FakeCourseRepository(_treeWith(material));
  final cubit = CourseTreeCubit(
    getTree: GetCourseTreeUseCase(repository),
    setCompleted: SetMaterialCompletedUseCase(repository),
    courseId: 'course-1',
  );
  await cubit.load();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: BlocProvider.value(
        value: cubit,
        child: const MaterialDetailPage(
          courseId: 'course-1',
          materialId: 'material-1',
        ),
      ),
    ),
  );
  await tester.pump();

  return repository;
}

void main() {
  group('the tab strip', () {
    testWidgets('shows five tabs when the material has no video',
        (tester) async {
      await _pump(tester, _material());

      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Video'), findsNothing);
      expect(find.text('Attachments'), findsOneWidget);
      expect(find.text('Assignments'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Comments'), findsOneWidget);
    });

    testWidgets('adds the Video tab when the material has one', (tester) async {
      await _pump(
        tester,
        _material(videoUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      );

      expect(find.text('Video'), findsOneWidget);
    });

    testWidgets('Attachments carries the file count', (tester) async {
      await _pump(tester, _material(attachments: const ['a', 'b', 'c']));

      expect(find.text('Attachments'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('the count is absent when there are no attachments',
        (tester) async {
      await _pump(tester, _material());

      expect(find.text('0'), findsNothing);
    });
  });

  group('the header', () {
    testWidgets('shows the module and topic breadcrumb', (tester) async {
      await _pump(tester, _material());

      expect(find.text('Module one  ›  Topic one'), findsOneWidget);
    });

    testWidgets('the description is collapsed until asked for', (tester) async {
      await _pump(tester, _material());

      // The strip sits above every tab, so it stays one line by default.
      expect(find.text('How halving the search space works.'), findsNothing);

      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pump();

      expect(find.text('How halving the search space works.'), findsOneWidget);
    });

    testWidgets('the strip stays a single line tall', (tester) async {
      // The strip sits above every tab, so its height is taken from the
      // material on all six. It runs from the bottom of the tab bar to the top
      // of the tab content.
      await _pump(tester, _material());

      final stripHeight = tester.getRect(find.byType(TabBarView)).top -
          tester.getRect(find.byType(TabBar)).bottom;

      // One line plus padding. The stacked breadcrumb + description +
      // full-width button it replaced ran past 100; this bound is here to stop
      // it creeping back.
      expect(stripHeight, lessThan(50));
    });

    testWidgets('a material with no description has no disclosure',
        (tester) async {
      await _pump(
        tester,
        CourseMaterial(
          id: 'material-1',
          courseId: 'course-1',
          name: 'Binary search',
          order: 1,
          completed: false,
        ),
      );

      expect(find.byIcon(Icons.info_outline_rounded), findsNothing);
    });

    testWidgets('the toggle reflects completion and writes through',
        (tester) async {
      final repository = await _pump(tester, _material());

      expect(find.text('Mark complete'), findsOneWidget);

      await tester.tap(find.text('Mark complete'));
      await tester.pumpAndSettle();

      expect(
        repository.writes,
        [(materialId: 'material-1', completed: true)],
      );
      // The page re-derives from the reloaded tree, so the label follows the
      // server's state without the page holding a copy of its own.
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Mark complete'), findsNothing);
    });

    testWidgets('an already-complete material reads as Completed',
        (tester) async {
      await _pump(tester, _material(completed: true));

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Mark complete'), findsNothing);
    });
  });

  group('the Content tab', () {
    testWidgets('renders the material body, blocks and all', (tester) async {
      await _pump(
        tester,
        _material(
          content: 'Some prose.\n\n'
              '```alert\n{"variant": "warning", "body": "Read this first."}\n```',
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Some prose.'), findsOneWidget);
      expect(find.text('Read this first.'), findsOneWidget);
    });

    testWidgets('empty content shows the web copy', (tester) async {
      await _pump(tester, _material());

      expect(find.text('No content yet'), findsOneWidget);
      expect(
        find.text('This material has no written content.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a material missing from the tree is reported, not crashed',
      (tester) async {
    final repository = _FakeCourseRepository(_treeWith(_material()));
    final cubit = CourseTreeCubit(
      getTree: GetCourseTreeUseCase(repository),
      setCompleted: SetMaterialCompletedUseCase(repository),
      courseId: 'course-1',
    );
    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: BlocProvider.value(
          value: cubit,
          child: const MaterialDetailPage(
            courseId: 'course-1',
            materialId: 'deleted-material',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Material unavailable'), findsOneWidget);
  });
}
