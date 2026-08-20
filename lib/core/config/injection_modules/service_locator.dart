import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/shared/auth/data/datasources/auth_local_service.dart';
import '../../../features/shared/auth/data/datasources/auth_service.dart';
import '../../../features/shared/auth/data/repositories/auth_repository_impl.dart';
import '../../../features/shared/auth/domain/repositories/auth_repository.dart';
import '../../../features/shared/auth/domain/usecases/accept_invitation_usecase.dart';
import '../../../features/shared/auth/domain/usecases/password_reset_usecases.dart';
import '../../../features/shared/auth/domain/usecases/auth_usecases.dart';
import '../../../features/shared/auth/domain/usecases/login_usecase.dart';
import '../../../features/shared/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../features/student/courses/data/datasources/course_service.dart';
import '../../../features/student/courses/data/repositories/course_repository_impl.dart';
import '../../../features/student/courses/domain/repositories/course_repository.dart';
import '../../../features/student/courses/domain/usecases/course_usecases.dart';
import '../../../features/shared/material_comments/domain/usecases/material_comment_usecases.dart';
import '../../../features/student/discussions/data/datasources/discussion_service.dart';
import '../../../features/student/discussions/data/repositories/discussion_repository_impl.dart';
import '../../../features/student/discussions/domain/repositories/discussion_repository.dart';
import '../../../features/student/discussions/domain/usecases/discussion_usecases.dart';
import '../../../features/shared/files/data/datasources/file_service.dart';
import '../../../features/shared/files/data/repositories/file_repository_impl.dart';
import '../../../features/shared/files/domain/repositories/file_repository.dart';
import '../../../features/shared/files/domain/usecases/file_usecases.dart';
import '../../../features/shared/notes/data/datasources/notes_service.dart';
import '../../../features/shared/notes/data/repositories/notes_repository_impl.dart';
import '../../../features/shared/notes/domain/repositories/notes_repository.dart';
import '../../../features/shared/notes/domain/usecases/notes_usecases.dart';
import '../../../features/student/practice/data/datasources/practice_service.dart';
import '../../../features/student/practice/data/repositories/practice_repository_impl.dart';
import '../../../features/student/practice/domain/repositories/practice_repository.dart';
import '../../../features/student/academic_calendar/data/datasources/academic_calendar_service.dart';
import '../../../features/student/academic_calendar/data/repositories/academic_calendar_repository_impl.dart';
import '../../../features/student/academic_calendar/domain/repositories/academic_calendar_repository.dart';
import '../../../features/student/academic_calendar/domain/usecases/academic_calendar_usecases.dart';
import '../../../features/student/analytics/data/datasources/analytics_service.dart';
import '../../../features/student/assessments/data/datasources/assessment_service.dart';
import '../../../features/student/assessments/data/repositories/assessment_repository_impl.dart';
import '../../../features/student/assessments/domain/repositories/assessment_repository.dart';
import '../../../features/student/assessments/domain/usecases/attempt_usecases.dart';
import '../../../features/student/assessments/domain/usecases/list_course_assessments_usecase.dart';
import '../../../features/student/announcements/data/datasources/announcement_service.dart';
import '../../../features/student/announcements/data/repositories/announcement_repository_impl.dart';
import '../../../features/student/announcements/domain/repositories/announcement_repository.dart';
import '../../../features/student/announcements/domain/usecases/announcement_usecases.dart';
import '../../../features/student/attendance/data/datasources/attendance_service.dart';
import '../../../features/student/attendance/data/repositories/attendance_repository_impl.dart';
import '../../../features/student/attendance/domain/repositories/attendance_repository.dart';
import '../../../features/student/attendance/domain/usecases/attendance_usecases.dart';
import '../../../features/student/calendar/data/datasources/calendar_service.dart';
import '../../../features/student/calendar/data/repositories/calendar_repository_impl.dart';
import '../../../features/student/calendar/domain/repositories/calendar_repository.dart';
import '../../../features/student/calendar/domain/usecases/calendar_usecases.dart';
import '../../../features/student/analytics/data/repositories/analytics_repository_impl.dart';
import '../../../features/student/analytics/domain/repositories/analytics_repository.dart';
import '../../../features/student/analytics/domain/usecases/analytics_usecases.dart';
import '../../../features/student/leaderboard/data/datasources/leaderboard_service.dart';
import '../../../features/student/public_profile/data/datasources/public_profile_service.dart';
import '../../../features/student/public_profile/data/repositories/public_profile_repository_impl.dart';
import '../../../features/student/public_profile/domain/repositories/public_profile_repository.dart';
import '../../../features/student/public_profile/domain/usecases/get_public_profile_usecase.dart';
import '../../../features/student/leaderboard/data/repositories/leaderboard_repository_impl.dart';
import '../../../features/student/leaderboard/domain/repositories/leaderboard_repository.dart';
import '../../../features/student/leaderboard/domain/usecases/leaderboard_usecases.dart';
import '../../../features/shared/notifications/data/datasources/notification_service.dart';
import '../../../features/shared/notifications/data/repositories/notification_repository_impl.dart';
import '../../../features/shared/notifications/domain/repositories/notification_repository.dart';
import '../../../features/shared/notifications/domain/usecases/notification_usecases.dart';
import '../../../features/teacher/dashboard/data/datasources/teacher_service.dart';
import '../../../features/teacher/enrollments/data/datasources/enrollment_service.dart';
import '../../../features/teacher/enrollments/data/repositories/enrollment_repository_impl.dart';
import '../../../features/teacher/enrollments/domain/repositories/enrollment_repository.dart';
import '../../../features/teacher/enrollments/domain/usecases/enrollment_usecases.dart';
import '../../../features/teacher/assessments/data/datasources/teacher_assessment_service.dart';
import '../../../features/teacher/assessments/data/datasources/teacher_grading_service.dart';
import '../../../features/teacher/assessments/data/repositories/teacher_assessment_repository_impl.dart';
import '../../../features/teacher/assessments/data/repositories/teacher_grading_repository_impl.dart';
import '../../../features/teacher/assessments/domain/repositories/teacher_assessment_repository.dart';
import '../../../features/teacher/assessments/domain/repositories/teacher_grading_repository.dart';
import '../../../features/teacher/assessments/domain/usecases/teacher_assessment_usecases.dart';
import '../../../features/teacher/assessments/domain/usecases/teacher_grading_usecases.dart';
import '../../../features/teacher/attendance/data/datasources/teacher_attendance_service.dart';
import '../../../features/teacher/attendance/data/repositories/teacher_attendance_repository_impl.dart';
import '../../../features/teacher/attendance/domain/repositories/teacher_attendance_repository.dart';
import '../../../features/teacher/attendance/domain/usecases/attendance_usecases.dart';
import '../../../features/teacher/courses/data/datasources/teacher_course_service.dart';
import '../../../features/teacher/courses/data/repositories/teacher_course_repository_impl.dart';
import '../../../features/teacher/courses/domain/repositories/teacher_course_repository.dart';
import '../../../features/teacher/courses/domain/usecases/teacher_course_usecases.dart';
import '../../../features/teacher/dashboard/data/repositories/teacher_repository_impl.dart';
import '../../../features/teacher/dashboard/domain/repositories/teacher_repository.dart';
import '../../../features/teacher/dashboard/domain/usecases/teacher_usecases.dart';
import '../../../features/student/practice/domain/usecases/practice_usecases.dart';
import '../../../features/student/rating/data/datasources/rating_service.dart';
import '../../../features/student/rating/data/repositories/rating_repository_impl.dart';
import '../../../features/student/rating/domain/repositories/rating_repository.dart';
import '../../../features/student/rating/domain/usecases/get_my_rating_usecase.dart';
import '../../../features/student/rewards/data/datasources/rewards_service.dart';
import '../../../features/student/rewards/data/repositories/rewards_repository_impl.dart';
import '../../../features/student/rewards/domain/repositories/rewards_repository.dart';
import '../../../features/student/rewards/domain/usecases/rewards_usecases.dart';
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
  _initTeacher();
  _initTeacherCourses();
  _initTeacherAttendance();
  _initTeacherAssessments();
  _initTeacherGrading();
  _initEnrollments();
  _initNotifications();
  _initPublicProfile();
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
    ..registerLazySingleton(() => UploadFilesUseCase(sl()))
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
    ..registerLazySingleton(() => GetMyRatingUseCase(sl()))
    ..registerLazySingleton(() => GetRatingLeaderboardUseCase(sl()));
}

/// The leaderboard slice also owns the badges endpoint — both live under
/// `/student/practice` and are read together by the dashboard highlights.
/// The public student showcase reached by tapping a name on the leaderboard.
/// Its endpoint needs no auth, but it rides the same configured client.
void _initPublicProfile() {
  sl
    ..registerLazySingleton<PublicProfileService>(
      () => PublicProfileService(sl()),
    )
    ..registerLazySingleton<PublicProfileRepository>(
      () => PublicProfileRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetPublicProfileUseCase(sl()));
}

/// The teacher area. One endpoint so far — the dashboard aggregate.
void _initTeacher() {
  sl
    ..registerLazySingleton<TeacherService>(() => TeacherService(sl()))
    ..registerLazySingleton<TeacherRepository>(
      () => TeacherRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => GetTeacherDashboardUseCase(sl()));
}

/// The teacher's courses, the section-scoped tree, and the learning-plan
/// authoring beneath it.
void _initTeacherCourses() {
  sl
    ..registerLazySingleton<TeacherCourseService>(
      () => TeacherCourseService(sl()),
    )
    ..registerLazySingleton<TeacherCourseRepository>(
      () => TeacherCourseRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => ListTeacherCoursesUseCase(sl()))
    ..registerLazySingleton(() => ListCourseDivisionsUseCase(sl()))
    ..registerLazySingleton(() => GetTeacherCourseTreeUseCase(sl()))
    ..registerLazySingleton(() => ModuleUseCases(sl()))
    ..registerLazySingleton(() => TopicUseCases(sl()))
    ..registerLazySingleton(() => MaterialUseCases(sl()));
}

/// Teacher attendance: sessions, roster marking, and the course rollup.
void _initTeacherAttendance() {
  sl
    ..registerLazySingleton<TeacherAttendanceService>(
      () => TeacherAttendanceService(sl()),
    )
    ..registerLazySingleton<TeacherAttendanceRepository>(
      () => TeacherAttendanceRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => AttendanceUseCases(sl()));
}

/// Teacher assessment authoring. These paths sit on the `/assessments` router
/// rather than under `/teacher`, unlike the grading endpoints.
void _initTeacherAssessments() {
  sl
    ..registerLazySingleton<TeacherAssessmentService>(() => TeacherAssessmentService(sl()))
    ..registerLazySingleton<TeacherAssessmentRepository>(
      () => TeacherAssessmentRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => TeacherAssessmentUseCases(sl()));
}

/// Grading. Deliberately separate from authoring above: these paths are on
/// `/teacher/assignments`, and mixing the two families up is easy to do.
void _initTeacherGrading() {
  sl
    ..registerLazySingleton<TeacherGradingService>(
      () => TeacherGradingService(sl()),
    )
    ..registerLazySingleton<TeacherGradingRepository>(
      () => TeacherGradingRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => TeacherGradingUseCases(sl()));
}

/// Course enrolments. The endpoints are guarded `school_admin` + `teacher`, so
/// a class_teacher or hod is refused — the tab gates its own writes on that.
void _initEnrollments() {
  sl
    ..registerLazySingleton<EnrollmentService>(() => EnrollmentService(sl()))
    ..registerLazySingleton<EnrollmentRepository>(
      () => EnrollmentRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => EnrollmentUseCases(sl()));
}

/// The notification feed. Role-agnostic: the backend resolves the recipient
/// from the caller's roles, so student and teacher read the same endpoint.
void _initNotifications() {
  sl
    ..registerLazySingleton<NotificationService>(() => NotificationService(sl()))
    ..registerLazySingleton<NotificationRepository>(
      () => NotificationRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => ListNotificationsUseCase(sl()))
    ..registerLazySingleton(() => MarkNotificationReadUseCase(sl()));
}

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
    ..registerLazySingleton(() => UseTimeTravelTicketUseCase(sl()))
    ..registerLazySingleton(() => GetWalletUseCase(sl()))
    ..registerLazySingleton(() => ListTransactionsUseCase(sl()))
    ..registerLazySingleton(() => GetStoreUseCase(sl()))
    ..registerLazySingleton(() => PurchaseProductUseCase(sl()))
    ..registerLazySingleton(() => ListOrdersUseCase(sl()))
    ..registerLazySingleton(() => ListOrderMessagesUseCase(sl()))
    ..registerLazySingleton(() => SendOrderMessageUseCase(sl()));
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
    ..registerLazySingleton(() => RequestPasswordResetUseCase(sl()))
    ..registerLazySingleton(() => ResetPasswordUseCase(sl()))
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
