import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/auth/data/datasources/auth_local_service.dart';
import '../../../features/auth/data/datasources/auth_service.dart';
import '../../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../../features/auth/domain/repositories/auth_repository.dart';
import '../../../features/auth/domain/usecases/accept_invitation_usecase.dart';
import '../../../features/auth/domain/usecases/auth_usecases.dart';
import '../../../features/auth/domain/usecases/login_usecase.dart';
import '../../../features/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../features/courses/data/datasources/course_service.dart';
import '../../../features/courses/data/repositories/course_repository_impl.dart';
import '../../../features/courses/domain/repositories/course_repository.dart';
import '../../../features/courses/domain/usecases/course_usecases.dart';
import '../../../features/courses/domain/usecases/material_comment_usecases.dart';
import '../../../features/discussions/data/datasources/discussion_service.dart';
import '../../../features/discussions/data/repositories/discussion_repository_impl.dart';
import '../../../features/discussions/domain/repositories/discussion_repository.dart';
import '../../../features/discussions/domain/usecases/discussion_usecases.dart';
import '../../../features/files/data/datasources/file_service.dart';
import '../../../features/files/data/repositories/file_repository_impl.dart';
import '../../../features/files/domain/repositories/file_repository.dart';
import '../../../features/files/domain/usecases/file_usecases.dart';
import '../../../features/notes/data/datasources/notes_service.dart';
import '../../../features/notes/data/repositories/notes_repository_impl.dart';
import '../../../features/notes/domain/repositories/notes_repository.dart';
import '../../../features/notes/domain/usecases/notes_usecases.dart';
import '../../../features/practice/data/datasources/practice_service.dart';
import '../../../features/practice/data/repositories/practice_repository_impl.dart';
import '../../../features/practice/domain/repositories/practice_repository.dart';
import '../../../features/academic_calendar/data/datasources/academic_calendar_service.dart';
import '../../../features/academic_calendar/data/repositories/academic_calendar_repository_impl.dart';
import '../../../features/academic_calendar/domain/repositories/academic_calendar_repository.dart';
import '../../../features/academic_calendar/domain/usecases/academic_calendar_usecases.dart';
import '../../../features/analytics/data/datasources/analytics_service.dart';
import '../../../features/assessments/data/datasources/assessment_service.dart';
import '../../../features/assessments/data/repositories/assessment_repository_impl.dart';
import '../../../features/assessments/domain/repositories/assessment_repository.dart';
import '../../../features/assessments/domain/usecases/attempt_usecases.dart';
import '../../../features/assessments/domain/usecases/list_course_assessments_usecase.dart';
import '../../../features/announcements/data/datasources/announcement_service.dart';
import '../../../features/announcements/data/repositories/announcement_repository_impl.dart';
import '../../../features/announcements/domain/repositories/announcement_repository.dart';
import '../../../features/announcements/domain/usecases/announcement_usecases.dart';
import '../../../features/attendance/data/datasources/attendance_service.dart';
import '../../../features/attendance/data/repositories/attendance_repository_impl.dart';
import '../../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../../features/attendance/domain/usecases/attendance_usecases.dart';
import '../../../features/calendar/data/datasources/calendar_service.dart';
import '../../../features/calendar/data/repositories/calendar_repository_impl.dart';
import '../../../features/calendar/domain/repositories/calendar_repository.dart';
import '../../../features/calendar/domain/usecases/calendar_usecases.dart';
import '../../../features/analytics/data/repositories/analytics_repository_impl.dart';
import '../../../features/analytics/domain/repositories/analytics_repository.dart';
import '../../../features/analytics/domain/usecases/analytics_usecases.dart';
import '../../../features/leaderboard/data/datasources/leaderboard_service.dart';
import '../../../features/leaderboard/data/repositories/leaderboard_repository_impl.dart';
import '../../../features/leaderboard/domain/repositories/leaderboard_repository.dart';
import '../../../features/leaderboard/domain/usecases/leaderboard_usecases.dart';
import '../../../features/practice/domain/usecases/practice_usecases.dart';
import '../../../features/rating/data/datasources/rating_service.dart';
import '../../../features/rating/data/repositories/rating_repository_impl.dart';
import '../../../features/rating/domain/repositories/rating_repository.dart';
import '../../../features/rating/domain/usecases/get_my_rating_usecase.dart';
import '../../../features/rewards/data/datasources/rewards_service.dart';
import '../../../features/rewards/data/repositories/rewards_repository_impl.dart';
import '../../../features/rewards/domain/repositories/rewards_repository.dart';
import '../../../features/rewards/domain/usecases/record_daily_visit_usecase.dart';
import '../../network/dio_client.dart';
import '../../network/session_manager.dart';
import '../theme/reduce_transparency_cubit.dart';
import '../theme/theme_cubit.dart';

final sl = GetIt.instance;

/// Registers every dependency, grouped by feature.
///
/// Must be awaited before `runApp` — the session is restored here so the router
/// knows on its first build whether anyone is signed in.
Future<void> initServiceLocator() async {
  await _initCore();
  _initAuth();
  _initCourses();
  _initPractice();
  _initRewards();
  _initAnalytics();
  _initRating();
  _initLeaderboard();
  _initAssessments();
  _initAttendance();
  _initAnnouncements();
  _initCalendar();
  _initAcademicCalendar();
  _initFiles();
  _initNotes();
  _initDiscussions();
}

/// Practice-question discussions. These endpoints sit under `/practice` rather
/// than `/student`: the thread is visible to any signed-in role.
void _initDiscussions() {
  sl
    ..registerLazySingleton<DiscussionService>(() => DiscussionService(sl()))
    ..registerLazySingleton<DiscussionRepository>(
      () => DiscussionRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => ListDiscussionsUseCase(sl()))
    ..registerLazySingleton(() => PostDiscussionUseCase(sl()))
    ..registerLazySingleton(() => EditDiscussionUseCase(sl()))
    ..registerLazySingleton(() => DeleteDiscussionUseCase(sl()))
    ..registerLazySingleton(() => ReactToDiscussionUseCase(sl()));
}

/// File metadata and presigned URLs — used by material attachments, and by
/// anything else that stores a bare file uuid.
void _initFiles() {
  sl
    ..registerLazySingleton<FileService>(() => FileService(sl()))
    ..registerLazySingleton<FileRepository>(() => FileRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetFileUseCase(sl()))
    ..registerLazySingleton(() => UploadFileUseCase(sl()))
    ..registerLazySingleton(() => ResolveFileUrlUseCase(sl()));
}

/// The notes feed, one note, the write operations and the like toggle.
///
/// Comments, sharing and attachment upload are a later pass — their counts
/// still come back on every row and are rendered.
void _initNotes() {
  sl
    ..registerLazySingleton<NotesService>(() => NotesService(sl()))
    ..registerLazySingleton<NotesRepository>(() => NotesRepositoryImpl(sl()))
    ..registerLazySingleton(() => ListNotesUseCase(sl()))
    ..registerLazySingleton(() => GetNoteUseCase(sl()))
    ..registerLazySingleton(() => CreateNoteUseCase(sl()))
    ..registerLazySingleton(() => UpdateNoteUseCase(sl()))
    ..registerLazySingleton(() => DeleteNoteUseCase(sl()))
    ..registerLazySingleton(() => ToggleNoteLikeUseCase(sl()))
    ..registerLazySingleton(() => GetMyNotesStatsUseCase(sl()));
}

void _initAssessments() {
  sl
    ..registerLazySingleton<AssessmentService>(() => AssessmentService(sl()))
    ..registerLazySingleton<AssessmentRepository>(
      () => AssessmentRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => ListCourseAssessmentsUseCase(sl()))
    ..registerLazySingleton(() => ListAllAssessmentsUseCase(sl()))
    ..registerLazySingleton(() => GetAssessmentDetailUseCase(sl()))
    ..registerLazySingleton(() => StartAttemptUseCase(sl()))
    ..registerLazySingleton(() => SaveAttemptUseCase(sl()))
    ..registerLazySingleton(() => SubmitAttemptUseCase(sl()));
}

void _initAttendance() {
  sl
    ..registerLazySingleton<AttendanceService>(() => AttendanceService(sl()))
    ..registerLazySingleton<AttendanceRepository>(
      () => AttendanceRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetCourseAttendanceUseCase(sl()))
    ..registerLazySingleton(() => GetOverallAttendanceUseCase(sl()))
    ..registerLazySingleton(() => ListAttendanceSessionsUseCase(sl()));
}

/// Campus announcements: the feed, one detail, and event registration.
void _initAnnouncements() {
  sl
    ..registerLazySingleton<AnnouncementService>(() => AnnouncementService(sl()))
    ..registerLazySingleton<AnnouncementRepository>(
      () => AnnouncementRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => ListAnnouncementsUseCase(sl()))
    ..registerLazySingleton(() => GetAnnouncementUseCase(sl()))
    ..registerLazySingleton(() => RegisterForAnnouncementUseCase(sl()))
    ..registerLazySingleton(() => CancelAnnouncementRegistrationUseCase(sl()));
}

/// The semester's published academic calendar — terms, holidays, exams and PL.
///
/// A separate feature from [_initCalendar], despite the name: different tables,
/// date-only entries, and no overlap in vocabulary.
void _initAcademicCalendar() {
  sl
    ..registerLazySingleton<AcademicCalendarService>(
      () => AcademicCalendarService(sl()),
    )
    ..registerLazySingleton<AcademicCalendarRepository>(
      () => AcademicCalendarRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetMyAcademicCalendarUseCase(sl()));
}

/// The combined timetable-and-events calendar.
void _initCalendar() {
  sl
    ..registerLazySingleton<CalendarService>(() => CalendarService(sl()))
    ..registerLazySingleton<CalendarRepository>(
      () => CalendarRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetCalendarUseCase(sl()));
}

void _initAnalytics() {
  sl
    ..registerLazySingleton<AnalyticsService>(() => AnalyticsService(sl()))
    ..registerLazySingleton<AnalyticsRepository>(
      () => AnalyticsRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetAnalyticsOverviewUseCase(sl()))
    ..registerLazySingleton(() => GetSemesterAnalyticsUseCase(sl()));
}

void _initRating() {
  sl
    ..registerLazySingleton<RatingService>(() => RatingService(sl()))
    ..registerLazySingleton<RatingRepository>(() => RatingRepositoryImpl(sl()))
    ..registerLazySingleton(() => GetMyRatingUseCase(sl()));
}

/// The leaderboard slice also owns the badges endpoint — both live under
/// `/student/practice` and are read together by the dashboard highlights.
void _initLeaderboard() {
  sl
    ..registerLazySingleton<LeaderboardService>(() => LeaderboardService(sl()))
    ..registerLazySingleton<LeaderboardRepository>(
      () => LeaderboardRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetLeaderboardUseCase(sl()))
    ..registerLazySingleton(() => GetBadgesUseCase(sl()));
}

void _initRewards() {
  sl
    ..registerLazySingleton<RewardsService>(() => RewardsService(sl()))
    ..registerLazySingleton<RewardsRepository>(() => RewardsRepositoryImpl(sl()))
    ..registerLazySingleton(() => RecordDailyVisitUseCase(sl()))
    ..registerLazySingleton(() => UseTimeTravelTicketUseCase(sl()));
}

Future<void> _initCore() async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  final session = SessionManager();
  // Load the tokens before the first request can be made.
  await session.restore();
  sl.registerSingleton<SessionManager>(session);

  sl.registerSingleton<DioClient>(DioClient(session: session));
  sl.registerFactory<ThemeCubit>(() => ThemeCubit(sl()));
  sl.registerFactory<ReduceTransparencyCubit>(
    () => ReduceTransparencyCubit(sl()),
  );
}

void _initAuth() {
  sl
    ..registerLazySingleton<AuthService>(() => AuthService(sl()))
    ..registerLazySingleton<AuthLocalService>(() => AuthLocalService(sl(), sl()))
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(sl(), sl()),
    )
    ..registerLazySingleton(() => LoginUseCase(sl()))
    ..registerLazySingleton(() => LogoutUseCase(sl()))
    ..registerLazySingleton(() => GetCachedSessionUseCase(sl()))
    ..registerLazySingleton(() => SetActiveRoleUseCase(sl()))
    ..registerLazySingleton(() => UpdateMyAccountUseCase(sl()))
    ..registerLazySingleton(() => UploadAvatarUseCase(sl()))
    ..registerLazySingleton(() => AcceptInvitationUseCase(sl()))
    // One AuthBloc for the whole app — the router depends on it.
    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(
        login: sl(),
        logout: sl(),
        getCachedSession: sl(),
        setActiveRole: sl(),
        repository: sl(),
        sessionManager: sl(),
      ),
    );
}

void _initCourses() {
  sl
    ..registerLazySingleton<CourseService>(() => CourseService(sl()))
    ..registerLazySingleton<CourseRepository>(() => CourseRepositoryImpl(sl()))
    ..registerLazySingleton(() => ListEnrolledCoursesUseCase(sl()))
    ..registerLazySingleton(() => GetCourseUseCase(sl()))
    ..registerLazySingleton(() => GetCourseTreeUseCase(sl()))
    ..registerLazySingleton(() => SetMaterialCompletedUseCase(sl()))
    // The material comment thread, all five verbs.
    ..registerLazySingleton(() => ListMaterialCommentsUseCase(sl()))
    ..registerLazySingleton(() => CreateMaterialCommentUseCase(sl()))
    ..registerLazySingleton(() => ReplyToMaterialCommentUseCase(sl()))
    ..registerLazySingleton(() => UpdateMaterialCommentUseCase(sl()))
    ..registerLazySingleton(() => DeleteMaterialCommentUseCase(sl()));
}

void _initPractice() {
  sl
    ..registerLazySingleton<PracticeService>(() => PracticeService(sl()))
    ..registerLazySingleton<PracticeRepository>(() => PracticeRepositoryImpl(sl()))
    ..registerLazySingleton(() => ListPracticeQuestionsUseCase(sl()))
    ..registerLazySingleton(() => GetPracticeQuestionUseCase(sl()))
    ..registerLazySingleton(() => GetPracticeAttemptsUseCase(sl()))
    ..registerLazySingleton(() => NavigatePracticeUseCase(sl()))
    ..registerLazySingleton(() => RunPracticeCodeUseCase(sl()))
    ..registerLazySingleton(() => RunPracticeCustomUseCase(sl()))
    ..registerLazySingleton(() => SubmitPracticeUseCase(sl()))
    ..registerLazySingleton(() => GetPracticeFiltersUseCase(sl()))
    ..registerLazySingleton(() => GetPracticeSummaryUseCase(sl()))
    ..registerLazySingleton(() => GetPracticeAnalyticsUseCase(sl()))
    ..registerLazySingleton(() => GetDailyChallengeUseCase(sl()))
    ..registerLazySingleton(() => GetDailyChallengeHistoryUseCase(sl()))
    ..registerLazySingleton(() => GetDailyChallengeByDateUseCase(sl()))
    ..registerLazySingleton(() => GetDailyCalendarUseCase(sl()))
    ..registerLazySingleton(() => SubmitDailyChallengeUseCase(sl()))
    ..registerLazySingleton(() => SetBookmarkedUseCase(sl()));
}
