import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/features/assessments/domain/entities/student_assessment.dart';
import 'package:college_level/features/assessments/domain/usecases/list_course_assessments_usecase.dart';
import 'package:college_level/features/assessments/presentation/bloc/assignments_cubit.dart';
import 'package:college_level/features/assessments/presentation/bloc/quizzes_cubit.dart';
import 'package:college_level/features/assessments/presentation/pages/assignments_page.dart';
import 'package:college_level/features/assessments/presentation/pages/quizzes_page.dart';
import 'package:college_level/core/common/widgets/widgets.dart';
import 'package:college_level/features/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:college_level/features/academic_calendar/domain/entities/academic_calendar.dart';
import 'package:college_level/features/academic_calendar/domain/usecases/academic_calendar_usecases.dart';
import 'package:college_level/features/academic_calendar/presentation/bloc/academic_calendar_cubit.dart';
import 'package:college_level/features/academic_calendar/presentation/pages/academic_calendar_page.dart';
import 'package:college_level/features/announcements/domain/entities/announcement.dart';
import 'package:college_level/features/announcements/domain/usecases/announcement_usecases.dart';
import 'package:college_level/features/announcements/presentation/bloc/announcement_detail_cubit.dart';
import 'package:college_level/features/announcements/presentation/bloc/announcements_cubit.dart';
import 'package:college_level/features/announcements/presentation/pages/announcement_detail_page.dart';
import 'package:college_level/features/announcements/presentation/pages/announcements_page.dart';
import 'package:college_level/features/attendance/domain/entities/attendance.dart';
import 'package:college_level/features/attendance/domain/usecases/attendance_usecases.dart';
import 'package:college_level/features/attendance/presentation/bloc/attendance_overview_cubit.dart';
import 'package:college_level/features/attendance/presentation/bloc/attendance_sessions_cubit.dart';
import 'package:college_level/features/attendance/presentation/pages/attendance_page.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/courses/domain/entities/course.dart';
import 'package:college_level/features/courses/domain/usecases/course_usecases.dart';
import 'package:college_level/features/courses/presentation/bloc/courses_cubit.dart';
import 'package:college_level/features/courses/presentation/pages/courses_page.dart';
import 'package:college_level/features/notes/domain/entities/note.dart';
import 'package:college_level/features/notes/domain/usecases/notes_usecases.dart';
import 'package:college_level/features/notes/presentation/bloc/my_notes_stats_cubit.dart';
import 'package:college_level/features/notes/presentation/bloc/note_detail_cubit.dart';
import 'package:college_level/features/notes/presentation/bloc/notes_hub_cubit.dart';
import 'package:college_level/features/notes/presentation/pages/note_detail_page.dart';
import 'package:college_level/features/notes/presentation/pages/notes_page.dart';
import 'package:college_level/features/notes/presentation/widgets/note_composer_sheet.dart';

import '../support/platform_parity.dart';

class _MockListAll extends Mock implements ListAllAssessmentsUseCase {}

class _MockListCourses extends Mock implements ListEnrolledCoursesUseCase {}

class _MockGetOverall extends Mock implements GetOverallAttendanceUseCase {}

class _MockListSessions extends Mock implements ListAttendanceSessionsUseCase {}

class _MockGetAcademicCalendar extends Mock
    implements GetMyAcademicCalendarUseCase {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class _MockListAnnouncements extends Mock implements ListAnnouncementsUseCase {}

class _MockGetAnnouncement extends Mock implements GetAnnouncementUseCase {}

class _MockRegisterFor extends Mock
    implements RegisterForAnnouncementUseCase {}

class _MockCancelRegistration extends Mock
    implements CancelAnnouncementRegistrationUseCase {}

class _MockListNotes extends Mock implements ListNotesUseCase {}

class _MockGetNote extends Mock implements GetNoteUseCase {}

class _MockCreateNote extends Mock implements CreateNoteUseCase {}

class _MockUpdateNote extends Mock implements UpdateNoteUseCase {}

class _MockDeleteNote extends Mock implements DeleteNoteUseCase {}

class _MockToggleNoteLike extends Mock implements ToggleNoteLikeUseCase {}

class _MockGetNotesStats extends Mock implements GetMyNotesStatsUseCase {}

/// Every sidebar destination that owns a real screen, pumped down both the
/// Material and the Liquid Glass branch.
///
/// These assert *features*, not pixels — the two branches are meant to look
/// different. What must not differ is which controls exist and what they say.
void main() {
  late _MockListAll listAll;
  late _MockListCourses listCourses;

  setUpAll(() {
    registerFallbackValue(const AssessmentQueryParams());
    registerFallbackValue(const ListCoursesParams());
    registerFallbackValue(const AttendanceSessionParams());
    registerFallbackValue(const NoParams());
    registerFallbackValue(const AnnouncementQueryParams());
    registerFallbackValue(const IdParams('a1'));
    registerFallbackValue(const ListNotesParams());
    registerFallbackValue(
      const CreateNoteInput(title: 't', content: 'c', link: NoteLinkContext()),
    );
    registerFallbackValue(const UpdateNoteInput(id: 'n1'));
  });

  setUp(() {
    listAll = _MockListAll();
    listCourses = _MockListCourses();

    when(() => listAll(any())).thenAnswer(
      (_) async => Right<Failure, Paginated<StudentAssessment>>(
        Paginated.emptyOf<StudentAssessment>(),
      ),
    );
    when(() => listCourses(any())).thenAnswer(
      (_) async => Right<Failure, Paginated<CourseEnrollment>>(
        Paginated.emptyOf<CourseEnrollment>(),
      ),
    );
  });

  group('Quizzes', () {
    bothPlatforms('renders search, the filter button and the empty state',
        (tester, host) async {
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) =>
                QuizzesCubit(listAll: listAll, listCourses: listCourses),
            child: const QuizzesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Search quizzes'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.text('No quizzes yet'), findsOneWidget);
    });

    bothPlatforms('the filter sheet carries Status, Reset and Apply',
        (tester, host) async {
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) =>
                QuizzesCubit(listAll: listAll, listCourses: listCourses),
            child: const QuizzesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Status'), findsOneWidget);
      expect(find.text('All statuses'), findsOneWidget);
      expect(find.text('Submitted'), findsOneWidget);
      // The arrangement this session standardised on, everywhere.
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });
  });

  group('Assignments', () {
    bothPlatforms('renders search, the filter button and the empty state',
        (tester, host) async {
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) =>
                AssignmentsCubit(listAll: listAll, listCourses: listCourses),
            child: const AssignmentsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.textContaining('assignment'), findsWidgets);
    });

    bothPlatforms('the filter sheet carries Status, Reset and Apply',
        (tester, host) async {
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) =>
                AssignmentsCubit(listAll: listAll, listCourses: listCourses),
            child: const AssignmentsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
    });
  });

  group('Courses', () {
    bothPlatforms('renders its empty state', (tester, host) async {
      await tester.pumpWidget(
        host(
          BlocProvider(
            create: (_) => CoursesCubit(listCourses),
            child: const CoursesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Whatever the copy, the screen must resolve to a state rather than
      // sitting on a skeleton forever.
      expect(find.byType(CoursesPage), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('Attendance', () {
    late _MockGetOverall getOverall;
    late _MockListSessions listSessions;

    const overall = CourseAttendance(
      totalSessions: 50,
      percentage: 82,
      counts: AttendanceCounts(present: 41, absent: 6, late: 2, leave: 1),
    );

    CourseAttendanceSummary summary(String id) => CourseAttendanceSummary(
          courseId: id,
          courseName: 'Data Structures',
          courseCode: 'CS201',
          divisionId: 'd1',
          totalSessions: 20,
          percentage: 90,
          counts: const AttendanceCounts(present: 18, absent: 2, late: 0, leave: 0),
        );

    void stubOverview({required List<CourseAttendanceSummary> courses}) {
      when(() => getOverall(any())).thenAnswer(
        (_) async => Right<Failure, AttendanceOverview>(
          AttendanceOverview(overall: overall, courses: courses),
        ),
      );
    }

    void stubSessions(List<AttendanceSession> items) {
      when(() => listSessions(any())).thenAnswer(
        (_) async => Right<Failure, Paginated<AttendanceSession>>(
          Paginated<AttendanceSession>(
            items: items,
            pagination: Pagination(
              page: 1,
              limit: 10,
              total: items.length,
              totalPages: 1,
            ),
          ),
        ),
      );
    }

    Widget page() => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => AttendanceOverviewCubit(getOverall: getOverall),
            ),
            BlocProvider(
              create: (_) =>
                  AttendanceSessionsCubit(listSessions: listSessions),
            ),
          ],
          child: const AttendancePage(),
        );

    setUp(() {
      getOverall = _MockGetOverall();
      listSessions = _MockListSessions();
      stubOverview(courses: [summary('c1')]);
      stubSessions(const []);
    });

    bothPlatforms('renders the stat tiles and the overall percentage',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('Total Sessions'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('Late / Leave'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // late + leave, summed client-side
      expect(find.text('82%'), findsOneWidget);
    });

    bothPlatforms('renders the course-wise breakdown', (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('Course-wise Attendance'), findsOneWidget);
      expect(find.text('Data Structures'), findsOneWidget);
      expect(find.text('CS201'), findsOneWidget);
      expect(find.text('18/20 present · 2 absent'), findsOneWidget);
    });

    bothPlatforms('hides the breakdown when there are no courses',
        (tester, host) async {
      stubOverview(courses: const []);

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('Course-wise Attendance'), findsNothing);
      // The stats still stand on their own.
      expect(find.text('Total Sessions'), findsOneWidget);
    });

    /// The header lives outside the sessions RemoteView, so an empty list must
    /// not take the stats down with it.
    bothPlatforms('an empty session list keeps the stats on screen',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('No attendance records'), findsOneWidget);
      expect(
        find.text('Your attendance will appear here once your teachers mark it.'),
        findsOneWidget,
      );
      expect(find.text('Total Sessions'), findsOneWidget);
    });

    bothPlatforms('a session row shows the date, course and type — and hides '
        'the remark', (tester, host) async {
      stubSessions([
        const AttendanceSession(
          id: 's1',
          status: 'present',
          type: 'lecture',
          sessionDate: '2026-08-02',
          courseCode: 'CS201',
          topic: 'Recursion',
          remark: 'Left early',
          startTime: '2026-08-02T10:00:00.000Z',
        ),
      ]);

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('02 Aug 2026'), findsOneWidget);
      expect(find.text('CS201 · Lecture'), findsOneWidget);
      expect(find.text('Recursion'), findsOneWidget);
      // Neither web page renders these.
      expect(find.text('Left early'), findsNothing);
      expect(find.textContaining('10:00'), findsNothing);
    });

    bothPlatforms('the filter sheet carries Course, Status, Reset and Apply',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Course'), findsOneWidget);
      expect(find.text('All courses'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('All statuses'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    /// The server caps the list at ten while the headline totals count every
    /// course, so the note has to appear exactly when that can be true. Two
    /// tests rather than two pumps: pumping the same tree again reuses the
    /// BlocProvider's element, so a restubbed use case never reloads.
    bothPlatforms('explains the ten-course cap when the list is full',
        (tester, host) async {
      stubOverview(courses: [for (var i = 0; i < 10; i++) summary('c$i')]);

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Showing 10 courses'), findsOneWidget);
    });

    bothPlatforms('says nothing about the cap on a short list',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Showing 10 courses'), findsNothing);
    });
  });

  group('Announcements', () {
    late _MockListAnnouncements listAnnouncements;
    late _MockGetAnnouncement getAnnouncement;

    // Every fixture leaves the cover null: CachedNetworkImage issues a real
    // request under flutter_test and can hang pumpAndSettle. Null also
    // exercises the fallback, which is the branch worth covering.
    Announcement item({
      String id = 'a1',
      String type = 'GENERAL',
      String priority = 'MEDIUM',
      String? roomId,
      String? description = 'Join us for the annual fest.',
      String? startDate = '2026-08-02T10:00:00.000Z',
    }) =>
        Announcement(
          id: id,
          title: 'Annual tech fest',
          type: type,
          priority: priority,
          description: description,
          startDate: startDate,
          roomId: roomId,
        );

    void stubFeed(List<Announcement> items) {
      when(() => listAnnouncements(any())).thenAnswer(
        (_) async => Right<Failure, Paginated<Announcement>>(
          Paginated<Announcement>(
            items: items,
            pagination: Pagination(
              page: 1,
              limit: 12,
              total: items.length,
              totalPages: 1,
            ),
          ),
        ),
      );
    }

    void stubDetail(AnnouncementDetail detail) {
      when(() => getAnnouncement(any()))
          .thenAnswer((_) async => Right<Failure, AnnouncementDetail>(detail));
    }

    Widget listPage() => BlocProvider(
          create: (_) =>
              AnnouncementsCubit(listAnnouncements: listAnnouncements),
          child: const AnnouncementsPage(),
        );

    Widget detailPage() => BlocProvider(
          create: (_) => AnnouncementDetailCubit(
            announcementId: 'a1',
            getAnnouncement: getAnnouncement,
            registerFor: _MockRegisterFor(),
            cancelRegistrationFor: _MockCancelRegistration(),
          ),
          child: const AnnouncementDetailPage(),
        );

    AnnouncementDetail detail({
      String type = 'EVENT',
      bool isRegistered = false,
      String? registrationStatus,
      List<AnnouncementFileRef> files = const [],
    }) =>
        AnnouncementDetail(
          id: 'a1',
          title: 'Annual tech fest',
          type: type,
          priority: 'HIGH',
          description: 'Join us for the annual fest.',
          startDate: '2026-08-02T10:00:00.000Z',
          isRegistered: isRegistered,
          registrationStatus: registrationStatus,
          registrationCount: 12,
          attachmentFiles: files,
          author: const AnnouncementAuthor(id: 'u1', fullName: 'Ada Lovelace'),
        );

    setUp(() {
      listAnnouncements = _MockListAnnouncements();
      getAnnouncement = _MockGetAnnouncement();
      stubFeed([item()]);
      stubDetail(detail());
    });

    bothPlatforms('renders the search field and the filter button',
        (tester, host) async {
      await tester.pumpWidget(host(listPage()));
      await tester.pumpAndSettle();

      // Named for what the server actually matches.
      expect(find.text('Search by title'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    bothPlatforms('an empty feed says nothing has been posted',
        (tester, host) async {
      stubFeed(const []);

      await tester.pumpWidget(host(listPage()));
      await tester.pumpAndSettle();

      expect(find.text('No announcements yet'), findsOneWidget);
      // Nothing to clear, so no button.
      expect(find.text('Clear filters'), findsNothing);
    });

    bothPlatforms('a card carries its badge, date, title, excerpt and CTA',
        (tester, host) async {
      await tester.pumpWidget(host(listPage()));
      await tester.pumpAndSettle();

      expect(find.text('General'), findsOneWidget);
      expect(find.text('2 Aug 2026'), findsOneWidget);
      expect(find.text('Annual tech fest'), findsOneWidget);
      expect(find.text('Join us for the annual fest.'), findsOneWidget);
      expect(find.text('View details'), findsOneWidget);
    });

    bothPlatforms('only a high-priority card is flagged', (tester, host) async {
      stubFeed([
        item(priority: 'HIGH'),
        item(id: 'a2', priority: 'LOW'),
      ]);

      await tester.pumpWidget(host(listPage()));
      await tester.pumpAndSettle();

      expect(find.text('High'), findsOneWidget);
    });

    /// The feed payload has no room, so the card promises a venue by the word
    /// alone — and only for an event that has one.
    bothPlatforms('the venue chip appears only for an event with a room',
        (tester, host) async {
      stubFeed([
        item(type: 'EVENT', roomId: 'r1'),
        item(id: 'a2', type: 'GENERAL'),
      ]);

      await tester.pumpWidget(host(listPage()));
      await tester.pumpAndSettle();

      expect(find.text('Venue'), findsOneWidget);
    });

    bothPlatforms('the filter sheet lists the types with Reset and Apply',
        (tester, host) async {
      await tester.pumpWidget(host(listPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Type'), findsOneWidget);
      expect(find.text('All types'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Apply'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
    });

    bothPlatforms('the detail shows its badges, body and author',
        (tester, host) async {
      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.text('Event'), findsOneWidget);
      // The web prints the raw enum beside the word.
      expect(find.text('HIGH priority'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.textContaining('Posted by Ada Lovelace'), findsOneWidget);
    });

    bothPlatforms('an unregistered event offers only Register now',
        (tester, host) async {
      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      // Uppercased in the string, since Flutter has no text-transform — the
      // web reaches the same rendering through CSS.
      expect(find.text('WHEN'), findsOneWidget);
      expect(find.text('VENUE'), findsOneWidget);
      expect(find.text('FEES'), findsOneWidget);
      expect(find.text('REGISTERED'), findsOneWidget);
      expect(find.text('Register now'), findsOneWidget);
      expect(find.text('Cancel registration'), findsNothing);
    });

    bothPlatforms('a registered event offers only Cancel registration',
        (tester, host) async {
      stubDetail(detail(isRegistered: true, registrationStatus: 'REGISTERED'));

      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.text("You're registered"), findsOneWidget);
      expect(find.text('Cancel registration'), findsOneWidget);
      expect(find.text('Register now'), findsNothing);
    });

    /// Attended is terminal: the web renders no button at all, not a disabled
    /// one.
    bothPlatforms('an attended event offers neither button',
        (tester, host) async {
      stubDetail(detail(isRegistered: true, registrationStatus: 'ATTENDED'));

      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.text('You attended this event'), findsOneWidget);
      expect(find.text('Cancel registration'), findsNothing);
      expect(find.text('Register now'), findsNothing);
    });

    bothPlatforms('a general announcement has no event card at all',
        (tester, host) async {
      stubDetail(detail(type: 'GENERAL'));

      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.text('WHEN'), findsNothing);
      expect(find.text('FEES'), findsNothing);
      expect(find.text('REGISTERED'), findsNothing);
      expect(find.text('Register now'), findsNothing);
    });

    // Two tests rather than two pumps: pumping the same tree again reuses the
    // BlocProvider's element, so a restubbed use case never reloads.
    bothPlatforms('attachments are listed with their count',
        (tester, host) async {
      stubDetail(
        detail(
          files: const [
            AnnouncementFileRef(
              id: 'f1',
              url: 'https://example.test/rules.pdf',
              name: 'Rules.pdf',
            ),
          ],
        ),
      );

      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.text('Attachments (1)'), findsOneWidget);
      expect(find.text('Rules.pdf'), findsOneWidget);
    });

    bothPlatforms('no attachments means no heading', (tester, host) async {
      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Attachments'), findsNothing);
    });

    bothPlatforms('a failed detail offers the way back', (tester, host) async {
      when(() => getAnnouncement(any())).thenAnswer(
        (_) async => const Left<Failure, AnnouncementDetail>(
          ServerFailure('gone', statusCode: 404),
        ),
      );

      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.text('This announcement is not available.'), findsOneWidget);
      expect(find.text('Back to announcements'), findsOneWidget);
    });
  });

  group('Academic Calendar', () {
    late _MockGetAcademicCalendar getCalendar;
    late _MockAuthBloc auth;

    AcademicCalendarEntry entry({
      String id = 'e1',
      String type = 'pl',
      String title = 'Preparation leave',
      String startDate = '2025-08-12',
      String? endDate = '2025-08-16',
      String? description = 'No classes during PL.',
    }) =>
        AcademicCalendarEntry(
          id: id,
          type: type,
          title: title,
          startDate: startDate,
          endDate: endDate,
          description: description,
        );

    AcademicCalendar calendar({
      List<AcademicCalendarEntry> entries = const [],
    }) =>
        AcademicCalendar(
          id: 'c1',
          title: 'Odd Semester 2025-26',
          description: 'Term plan for the odd semester.',
          startDate: '2025-07-01',
          endDate: '2025-11-30',
          departmentName: 'CSE',
          batchName: 'Batch 2024',
          semesterCode: 5,
          entries: entries,
        );

    void stub(AcademicCalendar? value) {
      when(() => getCalendar(any()))
          .thenAnswer((_) async => Right<Failure, AcademicCalendar?>(value));
    }

    // The download reads the school name off the session, so the page needs an
    // AuthBloc above it exactly as the shell provides in the app.
    Widget page() => MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider(
              create: (_) => AcademicCalendarCubit(getMyCalendar: getCalendar),
            ),
          ],
          child: const AcademicCalendarPage(),
        );

    setUp(() {
      getCalendar = _MockGetAcademicCalendar();
      auth = _MockAuthBloc();
      whenListen(
        auth,
        const Stream<AuthState>.empty(),
        initialState: const AuthState(status: AuthStatus.unauthenticated),
      );
      stub(calendar(entries: [entry()]));
    });

    /// A 200 carrying `data: null` means the school published nothing — a
    /// successful answer, and a different message from an empty calendar.
    bothPlatforms('nothing published says so, with no download offered',
        (tester, host) async {
      stub(null);

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('No academic calendar published'), findsOneWidget);
      expect(
        find.textContaining("Your school hasn't published an academic"),
        findsOneWidget,
      );
      expect(find.text('Download'), findsNothing);
    });

    bothPlatforms('the header carries title, scope, term and description',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('Odd Semester 2025-26'), findsOneWidget);
      expect(find.text('CSE • Batch 2024 • Semester 5'), findsOneWidget);
      expect(find.text('Term: 1 Jul – 30 Nov 2025'), findsOneWidget);
      expect(find.text('Term plan for the odd semester.'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    /// The regression test for using RemoteView here: an `isEmpty` predicate
    /// would blank the header and its download along with the entries.
    bothPlatforms('a published calendar with no entries keeps its header',
        (tester, host) async {
      stub(calendar());

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('No entries yet'), findsOneWidget);
      expect(
        find.text('This calendar has no events, holidays, exams or PL added.'),
        findsOneWidget,
      );
      expect(find.text('Odd Semester 2025-26'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    bothPlatforms('entries group under uppercase month headings, in order',
        (tester, host) async {
      stub(
        calendar(
          entries: [
            entry(startDate: '2025-08-12', endDate: '2025-08-16'),
            entry(id: 'e2', startDate: '2025-09-03', endDate: null),
          ],
        ),
      );

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('AUGUST 2025'), findsOneWidget);
      expect(find.text('SEPTEMBER 2025'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('AUGUST 2025')).dy,
        lessThan(tester.getTopLeft(find.text('SEPTEMBER 2025')).dy),
      );
    });

    bothPlatforms('an entry shows its badge, title, description and range',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('Preparation Leave'), findsOneWidget);
      expect(find.text('Preparation leave'), findsOneWidget);
      expect(find.text('No classes during PL.'), findsOneWidget);
      expect(find.text('12–16 Aug 2025'), findsOneWidget);
    });

    bothPlatforms('a failure offers a retry', (tester, host) async {
      when(() => getCalendar(any())).thenAnswer(
        (_) async =>
            const Left<Failure, AcademicCalendar?>(NetworkFailure('offline')),
      );

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
    });

    /// The web page has none of these, and the port keeps it that way.
    bothPlatforms('there is no search, filter or pagination control',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.tune_rounded), findsNothing);
      expect(find.byType(AppSearchField), findsNothing);
      expect(find.byType(TabBar), findsNothing);
    });

    /// Reachable without touching Printing: the builder returns null before it.
    bothPlatforms('downloading an empty calendar says there is nothing to print',
        (tester, host) async {
      stub(calendar());

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Download'));
      // Not pumpAndSettle: the toast dismisses itself, and settling would run
      // the clock past it and find nothing.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('This calendar has no entries yet.'), findsOneWidget);

      // Drain the dismissal timer so it does not outlive the test.
      await tester.pumpAndSettle();
    });
  });

  group('Notes', () {
    late _MockListNotes listNotes;
    late _MockGetNote getNote;
    late _MockCreateNote createNote;
    late _MockUpdateNote updateNote;
    late _MockDeleteNote deleteNote;
    late _MockToggleNoteLike toggleNoteLike;
    late _MockGetNotesStats getStats;

    NoteListItem item({
      String id = 'n1',
      String authorRole = 'student',
      String visibility = 'published',
      List<String> tags = const ['dsa'],
      bool isOwner = false,
    }) =>
        NoteListItem(
          id: id,
          title: 'How TCP handshake works',
          excerpt: 'Three packets, one connection.',
          visibility: visibility,
          authorRole: authorRole,
          author: const NoteAuthor(id: 'u1', fullName: 'Ada Lovelace'),
          tags: tags,
          likeCount: 1200,
          commentCount: 3,
          viewCount: 0,
          liked: false,
          isOwner: isOwner,
          isEdited: false,
        );

    NoteDetail detail({
      bool isOwner = true,
      List<NoteAttachment> files = const [],
    }) =>
        NoteDetail(
          id: 'n1',
          title: 'How TCP handshake works',
          content: 'Three packets, one connection.',
          visibility: 'published',
          authorRole: 'teacher',
          author: const NoteAuthor(id: 'u1', fullName: 'Ada Lovelace'),
          tags: const ['dsa'],
          likeCount: 4,
          commentCount: 3,
          viewCount: 9,
          liked: false,
          isOwner: isOwner,
          isEdited: false,
          attachmentFiles: files,
        );

    void stubFeed(List<NoteListItem> items) {
      when(() => listNotes(any())).thenAnswer(
        (_) async => Right<Failure, Paginated<NoteListItem>>(
          Paginated<NoteListItem>(
            items: items,
            pagination: Pagination(
              page: 1,
              limit: 12,
              total: items.length,
              totalPages: 1,
            ),
          ),
        ),
      );
    }

    Widget hub() => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => NotesHubCubit(
                list: listNotes,
                create: createNote,
                toggleLikeUseCase: toggleNoteLike,
                deleteUseCase: deleteNote,
              ),
            ),
            BlocProvider(
              create: (_) => MyNotesStatsCubit(getStats: getStats),
            ),
          ],
          child: const NotesPage(),
        );

    Widget detailPage() => BlocProvider(
          create: (_) => NoteDetailCubit(
            noteId: 'n1',
            getNote: getNote,
            updateUseCase: updateNote,
            deleteUseCase: deleteNote,
            toggleLikeUseCase: toggleNoteLike,
          ),
          child: const NoteDetailPage(),
        );

    setUp(() {
      listNotes = _MockListNotes();
      getNote = _MockGetNote();
      createNote = _MockCreateNote();
      updateNote = _MockUpdateNote();
      deleteNote = _MockDeleteNote();
      toggleNoteLike = _MockToggleNoteLike();
      getStats = _MockGetNotesStats();

      stubFeed([item()]);
      when(() => getNote(any()))
          .thenAnswer((_) async => Right<Failure, NoteDetail>(detail()));
      when(() => getStats(any())).thenAnswer(
        (_) async => const Right<Failure, MyNotesStats>(
          MyNotesStats(
            totalViews: 1240,
            totalLikes: 87,
            totalComments: 12,
            publishedNotes: 5,
          ),
        ),
      );
    });

    bothPlatforms('the toolbar carries search, filters and New note',
        (tester, host) async {
      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      // Not "by title" like Announcements: this endpoint matches the body too.
      expect(find.text('Search notes…'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });

    bothPlatforms('the three tabs are chips, not a TabBar', (tester, host) async {
      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      expect(find.text('All notes'), findsOneWidget);
      expect(find.text('My notes'), findsOneWidget);
      // The whole label, not an ellipsis — the reason these are chips.
      expect(find.text('Shared with me'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);
    });

    bothPlatforms('the stats row belongs to My notes alone', (tester, host) async {
      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      expect(find.text('Total views'), findsNothing);
      verifyNever(() => getStats(any()));

      await tester.tap(find.text('My notes'));
      await tester.pumpAndSettle();

      expect(find.text('Total views'), findsOneWidget);
      expect(find.text('1,240'), findsOneWidget);
      expect(find.text('Published notes'), findsOneWidget);
      // Lazily, and only once it is looked at.
      verify(() => getStats(any())).called(1);
    });

    bothPlatforms('a card carries its byline, excerpt, tag and counts',
        (tester, host) async {
      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      expect(find.text('by Ada Lovelace'), findsOneWidget);
      expect(find.text('How TCP handshake works'), findsOneWidget);
      expect(find.text('Three packets, one connection.'), findsOneWidget);
      expect(find.text('#dsa'), findsOneWidget);
      expect(find.text('1.2K'), findsOneWidget);
      // No role badge for a student, and an em dash rather than a zero view.
      expect(find.text('Teacher'), findsNothing);
      expect(find.text('—'), findsOneWidget);
    });

    bothPlatforms('a teacher note is badged and a private one is pilled',
        (tester, host) async {
      stubFeed([item(authorRole: 'teacher', visibility: 'private')]);

      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
    });

    bothPlatforms('an empty feed invites the first note', (tester, host) async {
      stubFeed(const []);

      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      expect(find.text('No notes yet'), findsOneWidget);
      expect(find.text('Write the first note for your school.'), findsOneWidget);
      // Nothing is filtered, so nothing to clear.
      expect(find.text('Clear filters'), findsNothing);
    });

    bothPlatforms('the Shared tab has its own empty state', (tester, host) async {
      stubFeed(const []);

      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      // Three chips are wider than a 390pt phone, so the strip scrolls and the
      // last one starts off-screen — as it does for a student.
      await tester.ensureVisible(find.text('Shared with me'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shared with me'));
      await tester.pumpAndSettle();

      expect(find.text('No notes shared with you yet'), findsOneWidget);
      expect(
        find.text('Notes your friends share with you will show up here.'),
        findsOneWidget,
      );
    });

    bothPlatforms('tapping a tag filters the feed by it', (tester, host) async {
      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('#dsa'));
      await tester.pumpAndSettle();

      expect(find.text('Filtered by'), findsOneWidget);
      // The chip on the card and the one in the filter row.
      expect(find.text('#dsa'), findsNWidgets(2));
    });

    bothPlatforms('a filtered empty feed offers Clear filters',
        (tester, host) async {
      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      // Empty *because of* the filter: re-stubbing after the tap would race the
      // refetch the tap itself fires.
      when(() => listNotes(any())).thenAnswer((invocation) async {
        final params = invocation.positionalArguments.first as ListNotesParams;
        return Right<Failure, Paginated<NoteListItem>>(
          Paginated<NoteListItem>(
            items: params.tag == null ? [item()] : const [],
            pagination: const Pagination(
              page: 1,
              limit: 12,
              total: 0,
              totalPages: 1,
            ),
          ),
        );
      });

      await tester.tap(find.text('#dsa'));
      await tester.pumpAndSettle();

      expect(find.text('No notes match your filters'), findsOneWidget);
      expect(find.text('Try adjusting your search or filters.'), findsOneWidget);
      expect(find.text('Clear filters'), findsOneWidget);
    });

    bothPlatforms('Access is offered on My notes only', (tester, host) async {
      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Sort'), findsOneWidget);
      expect(find.text('Most liked'), findsOneWidget);
      // Elsewhere the server already hides everyone else's private notes.
      expect(find.text('Access'), findsNothing);
    });

    bothPlatforms('the detail shows its meta line, body and like row',
        (tester, host) async {
      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.text('How TCP handshake works'), findsOneWidget);
      expect(find.textContaining('1 min read'), findsOneWidget);
      expect(find.textContaining('9 views'), findsOneWidget);
      expect(find.text('Teacher'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    bothPlatforms('edit and delete are the owner\'s alone', (tester, host) async {
      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    bothPlatforms('someone else\'s note carries no actions', (tester, host) async {
      when(() => getNote(any())).thenAnswer(
        (_) async => Right<Failure, NoteDetail>(detail(isOwner: false)),
      );

      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    bothPlatforms('deleting asks first, and says it cannot be undone',
        (tester, host) async {
      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Delete this note?'), findsOneWidget);
      expect(
        find.textContaining('permanently removes the note and its comments'),
        findsOneWidget,
      );
      verifyNever(() => deleteNote(any()));
    });

    /// A 403 on a private note and a 404 collapse into one message on purpose:
    /// "not allowed" would confirm the note exists.
    bothPlatforms('a missing note does not admit it exists', (tester, host) async {
      when(() => getNote(any())).thenAnswer(
        (_) async => const Left<Failure, NoteDetail>(
          ServerFailure('Forbidden', statusCode: 403),
        ),
      );

      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.text('Note not found'), findsOneWidget);
      expect(
        find.text('It may have been removed or is private.'),
        findsOneWidget,
      );
    });

    bothPlatforms('a web-authored attachment still opens', (tester, host) async {
      when(() => getNote(any())).thenAnswer(
        (_) async => Right<Failure, NoteDetail>(
          detail(
            files: const [
              NoteAttachment(id: 'f1', name: 'handshake.pdf', url: 'https://x/y.pdf'),
            ],
          ),
        ),
      );

      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      expect(find.text('Attachments (1)'), findsOneWidget);
      expect(find.text('handshake.pdf'), findsOneWidget);
    });

    bothPlatforms('the composer offers Write and Preview', (tester, host) async {
      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Write a note'), findsOneWidget);
      expect(find.text('Write'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Press enter or a comma to add a tag.'), findsOneWidget);
    });

    /// The label follows the visibility, because "Publish" would be a lie for a
    /// note only its author can read.
    bothPlatforms('the submit label follows the visibility', (tester, host) async {
      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Publish'), findsOneWidget);

      await tester.tap(find.text('Private'));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Publish'), findsNothing);
    });

    bothPlatforms('an empty composer is refused before the network',
        (tester, host) async {
      await tester.pumpWidget(host(hub()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      // The sheet body scrolls and the submit button starts below the fold.
      await tester.ensureVisible(find.text('Publish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();

      expect(find.text('A title and some content are required.'), findsOneWidget);
      verifyNever(() => createNote(any()));
    });

    bothPlatforms('editing opens the composer on the note', (tester, host) async {
      await tester.pumpWidget(host(detailPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Edit note'), findsOneWidget);
      // Prefilled, and labelled for an edit rather than a first publish.
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.byType(NoteDraft), findsNothing);
      expect(
        find.widgetWithText(TextField, 'How TCP handshake works'),
        findsOneWidget,
      );
    });
  });
}
