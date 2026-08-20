import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/features/student/assessments/domain/entities/student_assessment.dart';
import 'package:college_level/features/student/assessments/domain/usecases/list_course_assessments_usecase.dart';
import 'package:college_level/features/student/assessments/presentation/bloc/assignments_cubit.dart';
import 'package:college_level/features/student/assessments/presentation/bloc/quizzes_cubit.dart';
import 'package:college_level/features/student/assessments/presentation/pages/assignments_page.dart';
import 'package:college_level/features/student/assessments/presentation/pages/quizzes_page.dart';
import 'package:college_level/core/common/widgets/widgets.dart';
import 'package:college_level/features/shared/auth/presentation/bloc/auth/auth_bloc.dart';
import 'package:college_level/features/student/academic_calendar/domain/entities/academic_calendar.dart';
import 'package:college_level/features/student/academic_calendar/domain/usecases/academic_calendar_usecases.dart';
import 'package:college_level/features/student/academic_calendar/presentation/bloc/academic_calendar_cubit.dart';
import 'package:college_level/features/student/academic_calendar/presentation/pages/academic_calendar_page.dart';
import 'package:college_level/features/student/announcements/domain/entities/announcement.dart';
import 'package:college_level/features/student/announcements/domain/usecases/announcement_usecases.dart';
import 'package:college_level/features/student/announcements/presentation/bloc/announcement_detail_cubit.dart';
import 'package:college_level/features/student/announcements/presentation/bloc/announcements_cubit.dart';
import 'package:college_level/features/student/announcements/presentation/pages/announcement_detail_page.dart';
import 'package:college_level/features/student/announcements/presentation/pages/announcements_page.dart';
import 'package:college_level/features/student/attendance/domain/entities/attendance.dart';
import 'package:college_level/features/student/attendance/domain/usecases/attendance_usecases.dart';
import 'package:college_level/features/student/attendance/presentation/bloc/attendance_overview_cubit.dart';
import 'package:college_level/features/student/attendance/presentation/bloc/attendance_sessions_cubit.dart';
import 'package:college_level/features/student/attendance/presentation/pages/attendance_page.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/student/courses/domain/entities/course.dart';
import 'package:college_level/features/student/courses/domain/usecases/course_usecases.dart';
import 'package:college_level/features/student/courses/presentation/bloc/courses_cubit.dart';
import 'package:college_level/features/student/courses/presentation/pages/courses_page.dart';
import 'package:college_level/features/student/badges/domain/entities/badge.dart';
import 'package:college_level/features/student/badges/presentation/bloc/badges_cubit.dart';
import 'package:college_level/features/student/badges/presentation/pages/badges_page.dart';
import 'package:college_level/features/student/leaderboard/domain/usecases/leaderboard_usecases.dart';
import 'package:college_level/features/student/leaderboard/domain/entities/leaderboard.dart';
import 'package:college_level/features/student/public_profile/data/models/public_profile_model.dart';
import 'package:college_level/features/student/public_profile/domain/entities/public_profile.dart';
import 'package:college_level/features/student/public_profile/domain/usecases/get_public_profile_usecase.dart';
import 'package:college_level/features/student/public_profile/presentation/bloc/public_profile_cubit.dart';
import 'package:college_level/features/student/public_profile/presentation/pages/public_profile_page.dart';
import 'package:college_level/features/student/public_profile/presentation/widgets/public_badge_row.dart';
import 'package:college_level/features/student/rating/data/models/contest_rating_model.dart';
import 'package:college_level/features/student/rating/domain/entities/contest_rating.dart';
import 'package:college_level/features/student/rating/domain/usecases/get_my_rating_usecase.dart';
import 'package:college_level/features/student/rating/presentation/bloc/rating_cubit.dart';
import 'package:college_level/features/student/rating/presentation/bloc/rating_leaderboard_cubit.dart';
import 'package:college_level/features/student/rating/presentation/pages/rating_page.dart';
import 'package:college_level/features/student/rating/presentation/widgets/rating_leaderboard_row.dart';
import 'package:college_level/features/student/leaderboard/presentation/bloc/leaderboard_cubit.dart';
import 'package:college_level/features/student/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:college_level/features/student/rewards/domain/entities/rewards.dart';
import 'package:college_level/features/student/rewards/domain/usecases/rewards_usecases.dart';
import 'package:college_level/features/student/rewards/presentation/bloc/order_chat_cubit.dart';
import 'package:college_level/features/student/rewards/presentation/bloc/store_cubit.dart';
import 'package:college_level/features/student/rewards/presentation/bloc/wallet_cubit.dart';
import 'package:college_level/features/student/rewards/presentation/pages/wallet_page.dart';
import 'package:college_level/features/shared/auth/domain/usecases/password_reset_usecases.dart';
import 'package:college_level/features/shared/auth/presentation/pages/forgot_password_page.dart';
import 'package:college_level/features/shared/auth/presentation/pages/reset_password_page.dart';
import 'package:college_level/features/shared/notes/domain/entities/note.dart';
import 'package:college_level/features/shared/notes/domain/usecases/notes_usecases.dart';
import 'package:college_level/features/shared/notes/presentation/bloc/my_notes_stats_cubit.dart';
import 'package:college_level/features/shared/notes/presentation/bloc/note_detail_cubit.dart';
import 'package:college_level/features/shared/notes/presentation/bloc/notes_hub_cubit.dart';
import 'package:college_level/features/shared/notes/presentation/pages/note_detail_page.dart';
import 'package:college_level/features/shared/notes/presentation/pages/notes_page.dart';
import 'package:college_level/features/shared/notes/presentation/widgets/note_composer_sheet.dart';

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

class _MockRequestPasswordReset extends Mock
    implements RequestPasswordResetUseCase {}

class _MockResetPassword extends Mock implements ResetPasswordUseCase {}

class _MockGetBadges extends Mock implements GetBadgesUseCase {}

class _MockGetLeaderboard extends Mock implements GetLeaderboardUseCase {}

class _MockGetPublicProfile extends Mock implements GetPublicProfileUseCase {}

class _MockGetMyRating extends Mock implements GetMyRatingUseCase {}

class _MockGetRatingLeaderboard extends Mock
    implements GetRatingLeaderboardUseCase {}

class _MockGetWallet extends Mock implements GetWalletUseCase {}

class _MockListTransactions extends Mock implements ListTransactionsUseCase {}

class _MockGetStore extends Mock implements GetStoreUseCase {}

class _MockPurchaseProduct extends Mock implements PurchaseProductUseCase {}

class _MockListOrders extends Mock implements ListOrdersUseCase {}

class _MockListOrderMessages extends Mock
    implements ListOrderMessagesUseCase {}

class _MockSendOrderMessage extends Mock implements SendOrderMessageUseCase {}

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
    registerFallbackValue(const RequestPasswordResetParams(email: 'a@b.co'));
    registerFallbackValue(const PageParams());
    registerFallbackValue(
      const SendMessageParams(orderId: 'o1', content: 'hi'),
    );
    registerFallbackValue(const LeaderboardParams());
    registerFallbackValue(const RatingLeaderboardParams());
    registerFallbackValue(
      const ResetPasswordParams(email: 'a@b.co', otp: '123456', password: 'p'),
    );
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

  /// Password recovery has no web counterpart to mirror — the React login
  /// screen's "Forgot password?" is a button with no handler — so these lock in
  /// the copy the two clients will have to agree on later.
  group('Password reset', () {
    late _MockRequestPasswordReset requestReset;
    late _MockResetPassword resetPassword;

    setUp(() {
      requestReset = _MockRequestPasswordReset();
      resetPassword = _MockResetPassword();

      when(() => requestReset(any()))
          .thenAnswer((_) async => const Right<Failure, Unit>(unit));
      when(() => resetPassword(any()))
          .thenAnswer((_) async => const Right<Failure, Unit>(unit));
    });

    Widget forgotPage() =>
        ForgotPasswordPage(requestPasswordReset: requestReset);

    Widget resetPage({String? email = 'ada@school.edu'}) => ResetPasswordPage(
          resetPassword: resetPassword,
          requestPasswordReset: requestReset,
          email: email,
        );

    bothPlatforms('the forgot screen asks for an email and nothing else',
        (tester, host) async {
      await tester.pumpWidget(host(forgotPage()));
      await tester.pumpAndSettle();

      expect(find.text('Forgot password'), findsOneWidget);
      expect(
        find.textContaining("we'll send you a 6-digit code"),
        findsOneWidget,
      );
      expect(find.text('Send code'), findsOneWidget);
      expect(find.text('Back to sign in'), findsOneWidget);
      // One field: the code is asked for on the next screen.
      expect(find.byType(AppPasswordInput), findsNothing);
    });

    bothPlatforms('the reset screen carries the code, both passwords and resend',
        (tester, host) async {
      await tester.pumpWidget(host(resetPage()));
      await tester.pumpAndSettle();

      expect(find.text('Verification code'), findsOneWidget);
      expect(find.text('New password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.text("Didn't get a code?"), findsOneWidget);
      expect(find.byType(AppPasswordInput), findsNWidgets(2));
    });

    /// The server answers the same way for an address it has never seen, and
    /// stays silent for inactive and unverified accounts, so neither screen may
    /// state that an email was actually delivered.
    bothPlatforms('the sent-to notice is hedged, not a promise',
        (tester, host) async {
      await tester.pumpWidget(host(resetPage()));
      await tester.pumpAndSettle();

      expect(find.textContaining('If an account exists for'), findsOneWidget);
      expect(find.textContaining('ada@school.edu'), findsOneWidget);
      expect(find.textContaining('expires in 10 minutes'), findsOneWidget);
    });

    bothPlatforms('resend is held shut while a fresh code is in flight',
        (tester, host) async {
      await tester.pumpWidget(host(resetPage()));
      await tester.pump();

      expect(find.text('Resend in 60s'), findsOneWidget);
      expect(find.text('Resend code'), findsNothing);
    });

    /// Landing cold — a restart, or a link — leaves no address to resend to.
    bothPlatforms('a missing email becomes a field, not a caption',
        (tester, host) async {
      await tester.pumpWidget(host(resetPage(email: null)));
      await tester.pumpAndSettle();

      expect(find.text('Email'), findsOneWidget);
      expect(find.textContaining('If an account exists for'), findsNothing);
      expect(find.text('Resend code'), findsOneWidget);
    });
  });

  group('Badges', () {
    late _MockGetBadges getBadges;

    BadgeDefinition def(
      String key,
      String category,
      String tier,
      String name,
    ) =>
        BadgeDefinition(
          key: key,
          name: name,
          description: '$name description',
          category: category,
          tier: tier,
        );

    EarnedBadge earned(
      String key,
      String category, {
      String tier = 'bronze',
      String name = 'Earned badge',
      String period = '',
      String earnedAt = '2026-03-04T10:00:00.000Z',
    }) =>
        EarnedBadge(
          badgeKey: key,
          name: name,
          category: category,
          tier: tier,
          period: period,
          earnedAt: earnedAt,
        );

    /// Two monthly and two streak badges, plus the recurring daily template —
    /// five catalog entries, mirroring the shape the API actually returns.
    List<BadgeDefinition> catalog() => [
          def('monthly_bronze', 'monthly', 'bronze', 'Monthly Bronze'),
          def('monthly_silver', 'monthly', 'silver', 'Monthly Silver'),
          def('streak_bronze', 'streak', 'bronze', '3-Day Streak'),
          def('streak_gold', 'streak', 'gold', '30-Day Streak'),
          def(
            'daily_perfect_month',
            'daily_challenge',
            'gold',
            'Monthly Completion',
          ),
        ];

    void stub({
      List<EarnedBadge> earnedBadges = const [],
      List<BadgeDefinition>? catalogBadges,
    }) {
      when(() => getBadges(any())).thenAnswer(
        (_) async => Right<Failure, BadgeCollection>(
          BadgeCollection(
            earned: earnedBadges,
            catalog: catalogBadges ?? catalog(),
          ),
        ),
      );
    }

    Widget page() => BlocProvider(
          create: (_) => BadgesCubit(getBadges: getBadges),
          child: const BadgesPage(),
        );

    setUp(() {
      getBadges = _MockGetBadges();
      stub(
        earnedBadges: [
          earned('monthly_bronze', 'monthly', name: 'Monthly Bronze'),
          earned('streak_bronze', 'streak', name: '3-Day Streak'),
        ],
      );
    });

    bothPlatforms('the hero counts earned against the catalog',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      // Four fixed badges plus no completed daily months; two earned.
      expect(find.text("You've earned 2 of 4 badges."), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    /// The `totalCount > 0` guard: with nothing to progress towards, the bar
    /// would otherwise sit at a meaningless zero.
    bothPlatforms('an empty catalog drops the bar for the fallback copy',
        (tester, host) async {
      stub(catalogBadges: const []);

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(
        find.text('Earn badges by practicing consistently.'),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    bothPlatforms('sections follow catalog order, each with its count',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('Monthly Practice'), findsOneWidget);
      expect(find.text('Daily Streak'), findsOneWidget);
      expect(find.text('Daily Challenge'), findsOneWidget);
      expect(find.text('1/2'), findsNWidgets(2));
      expect(find.text('0 earned'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Monthly Practice')).dy,
        lessThan(tester.getTopLeft(find.text('Daily Streak')).dy),
      );
    });

    bothPlatforms('an earned card is dated and a locked one is not',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('Monthly Bronze'), findsOneWidget);
      expect(find.text('Monthly Silver'), findsOneWidget);
      // House format is day-first, not the web's en-US sample.
      expect(find.text('Earned 4 Mar 2026'), findsNWidgets(2));
      expect(find.textContaining('Earned '), findsNWidgets(2));
    });

    bothPlatforms('the tier chip is upper-cased, not humanised',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      // monthly_bronze + streak_bronze; streak_gold + the daily template.
      expect(find.text('BRONZE'), findsNWidgets(2));
      expect(find.text('GOLD'), findsNWidgets(2));
      expect(find.text('Bronze'), findsNothing);
    });

    /// The daily badge recurs monthly, so the single catalog template is
    /// replaced by one card per completed month.
    bothPlatforms('each completed daily month gets its own card, newest first',
        (tester, host) async {
      stub(
        earnedBadges: [
          earned(
            'daily_perfect_month',
            'daily_challenge',
            tier: 'gold',
            period: '2026-06',
            earnedAt: '2026-06-30T10:00:00.000Z',
          ),
          earned(
            'daily_perfect_month',
            'daily_challenge',
            tier: 'gold',
            period: '2026-07',
            earnedAt: '2026-07-31T10:00:00.000Z',
          ),
        ],
      );

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('July 2026 Daily Challenge'), findsOneWidget);
      expect(find.text('June 2026 Daily Challenge'), findsOneWidget);
      expect(find.text('2 earned'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('July 2026 Daily Challenge')).dy,
        lessThan(tester.getTopLeft(find.text('June 2026 Daily Challenge')).dy),
      );
    });

    bothPlatforms('no completed month falls back to the locked template',
        (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('Monthly Completion'), findsOneWidget);
      expect(find.textContaining('Daily Challenge'), findsOneWidget);
    });

    /// The regression test for not using RemoteView: it would swap the whole
    /// subtree and take the hero down with the sections.
    bothPlatforms('a failure offers a retry and keeps the hero',
        (tester, host) async {
      when(() => getBadges(any())).thenAnswer(
        (_) async => const Left<Failure, BadgeCollection>(
          NetworkFailure('offline'),
        ),
      );

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Badges'), findsOneWidget);
      expect(
        find.text('Earn badges by practicing consistently.'),
        findsOneWidget,
      );
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
  });

  group('Wallet', () {
    late _MockGetWallet getWallet;
    late _MockListTransactions listTransactions;
    late _MockGetStore getStore;
    late _MockPurchaseProduct purchaseProduct;
    late _MockListOrders listOrders;
    late _MockListOrderMessages listMessages;
    late _MockSendOrderMessage sendMessage;

    PointTransaction txn({
      String id = 't1',
      int amount = 10,
      String type = 'daily_challenge',
      String reason = 'Completed the challenge',
    }) =>
        PointTransaction(id: id, amount: amount, type: type, reason: reason);

    void stubWallet({int balance = 120}) {
      when(() => getWallet(any())).thenAnswer(
        (_) async => Right<Failure, Wallet>(Wallet(balance: balance)),
      );
    }

    void stubTransactions(List<PointTransaction> items) {
      when(() => listTransactions(any())).thenAnswer(
        (_) async => Right<Failure, Paginated<PointTransaction>>(
          Paginated<PointTransaction>(
            items: items,
            pagination: Pagination(
              page: 1,
              limit: 20,
              total: items.length,
              totalPages: 1,
            ),
          ),
        ),
      );
    }

    void stubStore(List<Product> products, {int balance = 120}) {
      when(() => getStore(any())).thenAnswer(
        (_) async => Right<Failure, Store>(
          Store(products: products, wallet: Wallet(balance: balance)),
        ),
      );
    }

    void stubOrders(List<RewardOrder> orders) {
      when(() => listOrders(any())).thenAnswer(
        (_) async => Right<Failure, List<RewardOrder>>(orders),
      );
    }

    Widget page({WalletTab tab = WalletTab.wallet}) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => WalletCubit(getWallet: getWallet)),
            BlocProvider(
              create: (_) =>
                  WalletTransactionsCubit(listTransactions: listTransactions),
            ),
            BlocProvider(
              create: (_) => StoreCubit(
                getStore: getStore,
                purchaseProduct: purchaseProduct,
              ),
            ),
            BlocProvider(create: (_) => OrdersCubit(listOrders: listOrders)),
          ],
          child: WalletPage(
            initialTab: tab,
            createChatCubit: (orderId) => OrderChatCubit(
              orderId: orderId,
              listMessages: listMessages,
              sendMessage: sendMessage,
            ),
          ),
        );

    setUp(() {
      getWallet = _MockGetWallet();
      listTransactions = _MockListTransactions();
      getStore = _MockGetStore();
      purchaseProduct = _MockPurchaseProduct();
      listOrders = _MockListOrders();
      listMessages = _MockListOrderMessages();
      sendMessage = _MockSendOrderMessage();

      stubWallet();
      stubTransactions([txn()]);
      stubStore(const []);
      stubOrders(const []);
    });

    bothPlatforms('the hero shows the balance', (tester, host) async {
      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('MY REWARDS'), findsOneWidget);
      expect(find.text('Your Rewards Wallet'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('points'), findsOneWidget);
    });

    /// The regression test for keeping the hero outside every branch: a dead
    /// network must not blank the screen down to a bare tab strip.
    bothPlatforms('a failure keeps the hero and offers a retry',
        (tester, host) async {
      when(() => listTransactions(any())).thenAnswer(
        (_) async => const Left<Failure, Paginated<PointTransaction>>(
          NetworkFailure('offline'),
        ),
      );

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Your Rewards Wallet'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
    });

    /// A debit's amount already carries its minus — prefixing it again would
    /// render "--70".
    bothPlatforms('credits gain a plus and debits keep one minus',
        (tester, host) async {
      stubTransactions([
        txn(amount: 10),
        txn(id: 't2', amount: -70, type: 'purchase', reason: 'Purchased X'),
      ]);

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('+10'), findsOneWidget);
      expect(find.text('-70'), findsOneWidget);
      expect(find.text('--70'), findsNothing);
      expect(find.text('Reward redeemed'), findsOneWidget);
    });

    bothPlatforms('an empty ledger says so', (tester, host) async {
      stubTransactions(const []);

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      expect(find.text('No points activity yet'), findsOneWidget);
    });

    /// Notifications deep-link with `?tab=`, so the initial tab must be
    /// honoured rather than always opening the ledger.
    bothPlatforms('the initial tab is honoured', (tester, host) async {
      await tester.pumpWidget(host(page(tab: WalletTab.earn)));
      await tester.pumpAndSettle();

      expect(find.text('Visit daily'), findsOneWidget);
      expect(find.text('Complete a perfect month'), findsOneWidget);
      expect(find.text('+30'), findsOneWidget);
    });

    /// The Earn tab is static, and the ledger must not be fetched for a tab the
    /// student never opened.
    bothPlatforms('an unopened tab is not fetched', (tester, host) async {
      await tester.pumpWidget(host(page(tab: WalletTab.earn)));
      await tester.pumpAndSettle();

      verifyNever(() => listTransactions(any()));
      verifyNever(() => getStore(any()));
      verifyNever(() => listOrders(any()));
    });

    bothPlatforms('switching tabs loads that tab once', (tester, host) async {
      stubOrders([
        const RewardOrder(id: 'o1', productTitle: 'Hoodie', pointsSpent: 300),
      ]);

      await tester.pumpWidget(host(page()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
      expect(find.text('Hoodie'), findsOneWidget);

      // Back and forth again must not refetch what is already loaded.
      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      verify(() => listOrders(any())).called(1);
    });

    bothPlatforms('an affordable product offers Redeem', (tester, host) async {
      stubStore(const [
        Product(id: 'p1', title: 'Hoodie', price: 100),
      ], balance: 120);

      await tester.pumpWidget(host(page(tab: WalletTab.store)));
      await tester.pumpAndSettle();

      expect(find.text('Hoodie'), findsOneWidget);
      expect(find.text('Redeem'), findsOneWidget);
      expect(find.text('Not enough'), findsNothing);
    });

    bothPlatforms('an unaffordable product is inert', (tester, host) async {
      stubStore(const [
        Product(id: 'p1', title: 'Hoodie', price: 900),
      ], balance: 120);

      await tester.pumpWidget(host(page(tab: WalletTab.store)));
      await tester.pumpAndSettle();

      expect(find.text('Not enough'), findsOneWidget);

      await tester.tap(find.text('Not enough'));
      await tester.pumpAndSettle();

      verifyNever(() => purchaseProduct(any()));
    });

    /// Spending points is irreversible, so nothing may be purchased on a single
    /// unconfirmed tap.
    bothPlatforms('redeeming asks before spending', (tester, host) async {
      stubStore(const [Product(id: 'p1', title: 'Hoodie', price: 100)]);

      await tester.pumpWidget(host(page(tab: WalletTab.store)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Redeem'));
      await tester.pumpAndSettle();

      expect(find.text('Redeem "Hoodie"?'), findsOneWidget);
      expect(
        find.textContaining('This will spend 100 points'),
        findsOneWidget,
      );
      verifyNever(() => purchaseProduct(any()));
    });

    bothPlatforms('an empty store says so', (tester, host) async {
      await tester.pumpWidget(host(page(tab: WalletTab.store)));
      await tester.pumpAndSettle();

      expect(find.text('No rewards available yet'), findsOneWidget);
    });

    /// A ticket takes effect in the app; only physical goods are fulfilled by
    /// hand and have anything to chase up.
    bothPlatforms('a ticket order is badged but not trackable',
        (tester, host) async {
      stubOrders([
        const RewardOrder(
          id: 'o1',
          productTitle: 'Time Travel Ticket',
          pointsSpent: 70,
          productType: RewardsMeta.timeTravelTicket,
          effectStatus: RewardsMeta.effectUnused,
        ),
      ]);

      await tester.pumpWidget(host(page(tab: WalletTab.orders)));
      await tester.pumpAndSettle();

      expect(find.text('Ready to use'), findsOneWidget);
      expect(find.text('Track order'), findsNothing);
      expect(find.text('Processing'), findsNothing);
    });

    bothPlatforms('a goods order is trackable and shows its unread count',
        (tester, host) async {
      stubOrders([
        const RewardOrder(
          id: 'o1',
          productTitle: 'Hoodie',
          pointsSpent: 300,
          unreadCount: 3,
        ),
      ]);

      await tester.pumpWidget(host(page(tab: WalletTab.orders)));
      await tester.pumpAndSettle();

      expect(find.text('Processing'), findsOneWidget);
      expect(find.text('Track order'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    bothPlatforms('a fulfilled order reads as completed', (tester, host) async {
      stubOrders([
        const RewardOrder(
          id: 'o1',
          productTitle: 'Hoodie',
          pointsSpent: 300,
          fulfilledAt: '2026-08-01T00:00:00.000Z',
        ),
      ]);

      await tester.pumpWidget(host(page(tab: WalletTab.orders)));
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Processing'), findsNothing);
    });

    bothPlatforms('an empty orders list says so', (tester, host) async {
      await tester.pumpWidget(host(page(tab: WalletTab.orders)));
      await tester.pumpAndSettle();

      expect(find.text('No orders yet'), findsOneWidget);
    });
  });

  group('Leaderboard', () {
    late _MockGetLeaderboard getLeaderboard;

    LeaderboardRow row({
      int rank = 1,
      String name = 'Asha Rao',
      int points = 500,
      int solved = 100,
      int? accuracy = 90,
      bool isMe = false,
      String? username = 'asha',
    }) =>
        LeaderboardRow(
          rank: rank,
          points: points,
          solved: solved,
          studentId: 's$rank',
          username: username,
          fullName: name,
          accuracy: accuracy,
          isMe: isMe,
        );

    void stub({
      List<LeaderboardRow> rows = const [],
      LeaderboardMe? me,
      int page = 1,
      int totalPages = 1,
    }) {
      when(() => getLeaderboard(any())).thenAnswer(
        (_) async => Right<Failure, LeaderboardStandings>(
          LeaderboardStandings(
            rows: rows,
            pagination: Pagination(
              page: page,
              limit: 20,
              total: rows.length,
              totalPages: totalPages,
            ),
            me: me,
            scope: LeaderboardScope.school,
            period: LeaderboardPeriod.allTime,
          ),
        ),
      );
    }

    /// Four rows so the podium takes three and one falls through to the list.
    List<LeaderboardRow> fourRows() => [
          row(rank: 1, name: 'First'),
          row(rank: 2, name: 'Second'),
          row(rank: 3, name: 'Third'),
          row(rank: 4, name: 'Fourth', isMe: true),
        ];

    Widget screen() => BlocProvider(
          create: (_) => LeaderboardCubit(getLeaderboard: getLeaderboard),
          child: const LeaderboardPage(),
        );

    setUp(() {
      getLeaderboard = _MockGetLeaderboard();
      stub(rows: fourRows());
    });

    bothPlatforms('the toolbar offers every scope behind a filter button',
        (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('School'), findsOneWidget);
      expect(find.text('Batch'), findsOneWidget);
      expect(find.text('Department'), findsOneWidget);
      // Period lives behind the filter button rather than costing a row of its
      // own, so the label is not on screen until the sheet opens.
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
      expect(find.text('All time'), findsNothing);
    });

    bothPlatforms('the filter button opens the period sheet',
        (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Period'), findsOneWidget);
      expect(find.text('All time'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
    });

    bothPlatforms('the my-rank banner shows the standing', (tester, host) async {
      stub(
        rows: fourRows(),
        me: const LeaderboardMe(rank: 4, points: 120, solved: 30, accuracy: 77),
      );

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('Your rank'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('77%'), findsOneWidget);
    });

    /// `me` is null until the student has solved something.
    bothPlatforms('no standing means no banner', (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('Your rank'), findsNothing);
    });

    /// A 0% would claim the student got everything wrong.
    bothPlatforms('a null accuracy is omitted from the banner',
        (tester, host) async {
      stub(
        rows: fourRows(),
        me: const LeaderboardMe(rank: 9, points: 0, solved: 0),
      );

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('ACCURACY'), findsNothing);
      expect(find.text('POINTS'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
    });

    /// The podium's whole point is the 2‑1‑3 arrangement, with the winner
    /// centre rather than left.
    bothPlatforms('the podium puts the winner between second and third',
        (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      final second = tester.getTopLeft(find.text('Second')).dx;
      final first = tester.getTopLeft(find.text('First')).dx;
      final third = tester.getTopLeft(find.text('Third')).dx;

      expect(second, lessThan(first));
      expect(first, lessThan(third));
      expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    });

    /// On page 2 ranks 21+ are not the top three, so a podium would be a lie.
    bothPlatforms('page two has no podium', (tester, host) async {
      stub(rows: fourRows(), page: 2, totalPages: 2);

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.emoji_events_rounded), findsNothing);
      expect(find.text('Fourth'), findsOneWidget);
    });

    /// The regression test for the isCurrentUser fix, at the widget level.
    bothPlatforms('the reader own row is marked', (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('(You)'), findsOneWidget);
      expect(find.text('Fourth'), findsOneWidget);
    });

    bothPlatforms('a row with no accuracy shows an em dash',
        (tester, host) async {
      stub(rows: [
        row(rank: 1, name: 'First'),
        row(rank: 2, name: 'Second'),
        row(rank: 3, name: 'Third'),
        row(rank: 4, name: 'Fourth', accuracy: null, solved: 0),
      ]);

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      // Exact, not `textContaining('0%')` — that also matches "90%".
      expect(find.text('0 solved · —'), findsOneWidget);
    });

    bothPlatforms('an empty board says so', (tester, host) async {
      stub();

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('No rankings yet'), findsOneWidget);
      expect(
        find.text('Solve practice questions to climb the leaderboard.'),
        findsOneWidget,
      );
    });

    bothPlatforms('a failure offers a retry', (tester, host) async {
      when(() => getLeaderboard(any())).thenAnswer(
        (_) async =>
            const Left<Failure, LeaderboardStandings>(NetworkFailure('offline')),
      );

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
    });

    /// The paginator hides itself on a single page, as the web's does.
    bothPlatforms('one page shows no paginator', (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    });

    bothPlatforms('more than one page shows the paginator',
        (tester, host) async {
      stub(rows: fourRows(), totalPages: 3);

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('1 / 3'), findsOneWidget);
    });

    /// Changing scope must restart at page 1, not keep the reader deep in a
    /// board they have not seen the top of.
    bothPlatforms('changing scope refetches from page 1', (tester, host) async {
      stub(rows: fourRows(), totalPages: 3);

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Batch'));
      await tester.pumpAndSettle();

      verify(() => getLeaderboard(
            const LeaderboardParams(scope: 'batch'),
          )).called(1);
    });
  });

  group('PublicProfile', () {
    late _MockGetPublicProfile getPublicProfile;

    void stub(Map<String, dynamic> json) {
      when(() => getPublicProfile(any())).thenAnswer(
        (_) async => Right<Failure, PublicProfile>(
          PublicProfileModel.fromJson(json),
        ),
      );
    }

    Map<String, dynamic> payload({
      Object? rank = 4,
      List<Object?> badges = const [],
      List<Object?> recent = const [],
    }) =>
        {
          'username': 'asha.rao@gis2025.seed',
          'fullName': 'Asha Rao',
          'schoolName': 'Green Valley',
          'stats': {
            'solved': 83,
            'currentStreak': 5,
            'points': 388,
            'rank': rank,
            'totalStudents': 6,
          },
          'badges': badges,
          'recentSolved': recent,
        };

    Widget screen() => BlocProvider(
          create: (_) => PublicProfileCubit(
            getPublicProfile: getPublicProfile,
            username: 'asha.rao@gis2025.seed',
          ),
          child: const PublicProfilePage(),
        );

    setUp(() {
      getPublicProfile = _MockGetPublicProfile();
      stub(payload());
    });

    bothPlatforms('the header shows the name, handle and school',
        (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('Asha Rao'), findsOneWidget);
      // The domain is trimmed — a full email would render "@asha.rao@…".
      expect(find.text('@asha.rao'), findsOneWidget);
      expect(find.text('Green Valley'), findsOneWidget);
    });

    bothPlatforms('every stat tile is present', (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('83'), findsOneWidget);
      expect(find.text('388'), findsOneWidget);
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('of 6 in school'), findsOneWidget);
    });

    /// An unranked student is not "#0".
    bothPlatforms('a null rank reads as unranked', (tester, host) async {
      stub(payload(rank: null));

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('Unranked'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('#0'), findsNothing);
    });

    /// One badge per row, stacked — not a grid.
    bothPlatforms('badges render one per row', (tester, host) async {
      stub(payload(badges: [
        {
          'badgeKey': 'monthly_bronze',
          'name': 'Monthly Bronze',
          'tier': 'bronze',
          'category': 'monthly',
          'period': '2026-08',
          'earnedAt': '2026-08-01T00:00:00.000Z',
        },
        {
          'badgeKey': 'streak_7',
          'name': '7-Day Streak',
          'tier': 'silver',
          'category': 'streak',
          'period': '2026-07',
          'earnedAt': '2026-07-01T00:00:00.000Z',
        },
      ]));

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.byType(PublicBadgeRow), findsNWidgets(2));
      expect(find.text('Monthly Bronze'), findsOneWidget);
      expect(find.text('Monthly Practice · Aug 2026'), findsOneWidget);

      // Stacked vertically: the second row sits below the first, not beside it.
      final first = tester.getTopLeft(find.byType(PublicBadgeRow).first);
      final second = tester.getTopLeft(find.byType(PublicBadgeRow).last);
      expect(second.dy, greaterThan(first.dy));
      expect(second.dx, equals(first.dx));
    });

    bothPlatforms('a solved question shows its difficulty and date',
        (tester, host) async {
      stub(payload(recent: [
        {
          'questionId': 'q1',
          'title': 'The degree of a node in a tree is defined as',
          'difficulty': 'easy',
          'solvedAt': '2026-08-18T10:00:00.000Z',
        },
      ]));

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(
        find.text('The degree of a node in a tree is defined as'),
        findsOneWidget,
      );
      expect(find.text('easy'), findsOneWidget);
      expect(find.text('18 Aug 2026'), findsOneWidget);
    });

    /// Question text is authored with caret exponents; rendered raw, `x^2`
    /// reads as a typo.
    bothPlatforms('an exponent in a question title is raised',
        (tester, host) async {
      stub(payload(recent: [
        {
          'questionId': 'q1',
          'title': 'What is the codomain of the function f(x) = x^2?',
          'difficulty': 'easy',
          'solvedAt': '2026-08-16T10:00:00.000Z',
        },
      ]));

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(
        find.text('What is the codomain of the function f(x) = x²?'),
        findsOneWidget,
      );
      expect(find.textContaining('x^2'), findsNothing);
    });

    bothPlatforms('empty sections say so', (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('No badges earned yet.'), findsOneWidget);
      expect(find.text('No solved questions yet.'), findsOneWidget);
    });

    bothPlatforms('a failure offers a retry', (tester, host) async {
      when(() => getPublicProfile(any())).thenAnswer(
        (_) async => const Left<Failure, PublicProfile>(NetworkFailure('offline')),
      );

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Rating', () {
    late _MockGetMyRating getMyRating;
    late _MockGetRatingLeaderboard getRatingLeaderboard;

    void stubRating(Map<String, dynamic> json) {
      when(() => getMyRating(any())).thenAnswer(
        (_) async => Right<Failure, ContestRating>(
          ContestRatingModel.fromJson(json),
        ),
      );
    }

    void stubBoard(Map<String, dynamic> json) {
      when(() => getRatingLeaderboard(any())).thenAnswer(
        (_) async => Right<Failure, RatingLeaderboard>(
          RatingLeaderboardModel.fromJson(json),
        ),
      );
    }

    Map<String, dynamic> ratingPayload({
      int rating = 1543,
      bool provisional = false,
      List<Object?> history = const [],
    }) =>
        {
          'rating': rating,
          'peakRating': 1580,
          'contestsPlayed': history.length,
          'tier': 'Specialist',
          'tierColor': '#03a89e',
          'isProvisional': provisional,
          'history': history,
        };

    Map<String, dynamic> entry({
      required String id,
      required String name,
      int rank = 1,
      int rating = 1500,
      bool isMe = false,
    }) =>
        {
          'studentId': id,
          'name': name,
          'username': name.toLowerCase(),
          'rank': rank,
          'rating': rating,
          'peakRating': rating,
          'contestsPlayed': 3,
          'tier': 'Specialist',
          'tierColor': '#03a89e',
          'isCurrentUser': isMe,
        };

    Widget screen() => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => RatingCubit(getMyRating: getMyRating)),
            BlocProvider(
              create: (_) => RatingLeaderboardCubit(
                getRatingLeaderboard: getRatingLeaderboard,
              ),
            ),
          ],
          child: const RatingPage(),
        );

    setUp(() {
      getMyRating = _MockGetMyRating();
      getRatingLeaderboard = _MockGetRatingLeaderboard();
      stubRating(ratingPayload());
      stubBoard(const {
        'entries': [],
        'myRank': null,
        'pagination': {'page': 1, 'limit': 20, 'total': 0, 'totalPages': 1},
      });
    });

    bothPlatforms('the stat tiles show rating, peak and tier',
        (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('1543'), findsOneWidget);
      expect(find.text('1580'), findsOneWidget);
      expect(find.text('Specialist'), findsOneWidget);
      expect(find.text('37 to go'), findsOneWidget);
    });

    bothPlatforms('being at your peak says so', (tester, host) async {
      stubRating(ratingPayload(rating: 1580));

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('At your best'), findsOneWidget);
    });

    /// An unrated student has no rank at all — never "#0".
    bothPlatforms('a null myRank reads as an em dash', (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('#0'), findsNothing);
      expect(find.text('—'), findsOneWidget);
    });

    // Two tests rather than one that re-pumps: pumping a second widget into the
    // same tester reuses the element tree, so `BlocProvider.create` never runs
    // again and the restubbed cubit is never built.
    bothPlatforms('a rated student gets no provisional note',
        (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('starting rating'), findsNothing);
    });

    bothPlatforms('an unrated student is told the rating is provisional',
        (tester, host) async {
      stubRating(ratingPayload(provisional: true));

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.textContaining('starting rating'), findsOneWidget);
    });

    bothPlatforms('no history shows the empty curve copy', (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('No rated contests yet'), findsOneWidget);
      expect(find.text('Your contest history will appear here.'), findsOneWidget);
    });

    /// The delta sign rule: zero counts as a gain, negatives keep their own sign.
    bothPlatforms('delta pills carry the right sign', (tester, host) async {
      stubRating(ratingPayload(history: [
        {'contestId': 'a', 'contestTitle': 'Gain', 'ratingAfter': 1243, 'ratingDelta': 43},
        {'contestId': 'b', 'contestTitle': 'Loss', 'ratingAfter': 1231, 'ratingDelta': -12},
        {'contestId': 'c', 'contestTitle': 'Flat', 'ratingAfter': 1231, 'ratingDelta': 0},
      ]));

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('+43'), findsOneWidget);
      expect(find.text('-12'), findsOneWidget);
      // Zero appears twice: in the Flat row and in the Rating tile's footer,
      // which mirrors the most recent change.
      expect(find.text('+0'), findsNWidgets(2));
    });

    /// The API returns oldest-first; the newest contest is the one worth reading.
    bothPlatforms('history is newest first', (tester, host) async {
      stubRating(ratingPayload(history: [
        {'contestId': 'a', 'contestTitle': 'Oldest', 'ratingAfter': 1200, 'ratingDelta': 5},
        {'contestId': 'b', 'contestTitle': 'Newest', 'ratingAfter': 1250, 'ratingDelta': 50},
      ]));

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      final newest = tester.getTopLeft(find.text('Newest')).dy;
      final oldest = tester.getTopLeft(find.text('Oldest')).dy;
      expect(newest, lessThan(oldest));
    });

    bothPlatforms('the curve renders once there is history', (tester, host) async {
      stubRating(ratingPayload(history: [
        {'contestId': 'a', 'contestTitle': 'One', 'ratingAfter': 1200, 'ratingDelta': 5},
        {'contestId': 'b', 'contestTitle': 'Two', 'ratingAfter': 1320, 'ratingDelta': 120},
      ]));

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('No rated contests yet'), findsNothing);
      expect(find.text('2 rated contests'), findsOneWidget);
    });

    bothPlatforms('the leaderboard tab lists rated students',
        (tester, host) async {
      stubBoard({
        'entries': [
          entry(id: 's1', name: 'Asha', rank: 1, rating: 1600),
          entry(id: 's2', name: 'Ravi', rank: 2, rating: 1500, isMe: true),
        ],
        'myRank': 2,
        'pagination': {'page': 1, 'limit': 20, 'total': 2, 'totalPages': 1},
      });

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('School leaderboard'));
      await tester.pumpAndSettle();

      expect(find.byType(RatingLeaderboardRow), findsNWidgets(2));
      expect(find.text('Asha'), findsOneWidget);
      expect(find.text('(you)'), findsOneWidget);
    });

    bothPlatforms('an empty leaderboard says so', (tester, host) async {
      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('School leaderboard'));
      await tester.pumpAndSettle();

      expect(find.text('Nobody is rated yet'), findsOneWidget);
    });

    bothPlatforms('the paginator appears only beyond one page',
        (tester, host) async {
      stubBoard({
        'entries': [entry(id: 's1', name: 'Asha')],
        'myRank': 1,
        'pagination': {'page': 1, 'limit': 20, 'total': 60, 'totalPages': 3},
      });

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('School leaderboard'));
      await tester.pumpAndSettle();

      expect(find.text('1 / 3'), findsOneWidget);
    });

    bothPlatforms('a rating failure offers a retry', (tester, host) async {
      when(() => getMyRating(any())).thenAnswer(
        (_) async => const Left<Failure, ContestRating>(NetworkFailure('down')),
      );

      await tester.pumpWidget(host(screen()));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
