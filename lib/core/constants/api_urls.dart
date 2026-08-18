/// Every backend path the app talks to, mirroring the React `src/api/*/apis.ts`
/// modules one-for-one.
///
/// All paths are relative to [ApiUrls.baseUrl], which already includes the
/// `/api/v1` prefix — so they are written without it, exactly as the axios
/// modules write them.
class ApiUrls {
  const ApiUrls._();

  /// The hosted backend. Every build points here by default, so the app needs
  /// no local server and behaves the same on a simulator, an emulator, and a
  /// real device.
  ///
  /// No trailing slash: every path constant below starts with `/`, and Dio
  /// concatenates the two.
  static const _defaultBaseUrl = 'https://collegelevel.blsheet.com/api/v1';

  /// Point at a different backend without editing code:
  /// `flutter run --dart-define=API_BASE_URL=http://localhost:3005/api/v1`
  /// (use `10.0.2.2` in place of `localhost` on the Android emulator, which
  /// cannot reach the host machine's loopback address).
  static const _override = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl => _override.isNotEmpty ? _override : _defaultBaseUrl;

  // ── Auth / account ────────────────────────────────────────────────────────
  static const login = '/users/login';
  static const acceptInvitation = '/users/accept-invitation';
  static const forgotPassword = '/users/forgot-password';
  static const resetPassword = '/users/reset-password';
  static const logout = '/users/logout';
  static const updateMyAccount = '/users/me';

  // ── Profiles ──────────────────────────────────────────────────────────────
  static const myStudentProfile = '/student-profiles/me';
  static const myTeacherProfile = '/teacher-profiles/me';

  // ── Public (no auth, no error interceptor) ────────────────────────────────
  static String publicStudentProfile(String username) => '/public/students/$username';

  // ── Files ─────────────────────────────────────────────────────────────────
  static const fileUpload = '/files/upload';
  static const fileUploadMultiple = '/files/upload-multiple';
  static String file(String id) => '/files/$id';
  static String filePresignedUrl(String id) => '/files/$id/presigned-url';

  // ── Notifications ─────────────────────────────────────────────────────────
  static const notifications = '/notifications';
  static const notificationsUnreadCount = '/notifications/unread-count';
  static const notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';

  // ── Student: courses ──────────────────────────────────────────────────────
  static const studentCourses = '/student/courses';
  static String studentCourse(String id) => '/student/courses/$id';
  static String studentCourseTree(String id) => '/student/courses/$id/tree';
  static String studentCourseProgress(String id) => '/student/courses/$id/progress';
  static String studentMaterialComplete(String materialId) =>
      '/student/course-materials/$materialId/complete';
  static String studentMaterialComments(String materialId) =>
      '/student/course-materials/$materialId/comments';
  static String studentCommentReplies(String commentId) =>
      '/student/course-material-comments/$commentId/replies';
  static String studentComment(String commentId) =>
      '/student/course-material-comments/$commentId';

  // ── Student: assignments & quizzes ────────────────────────────────────────
  static const studentAssignments = '/student/assignments';
  static const studentAssignmentsAll = '/student/assignments/all';
  static String studentAssignment(String id) => '/student/assignments/$id';
  static String studentAssignmentSubmission(String id) =>
      '/student/assignments/$id/submission';
  static String studentAssignmentSubmissions(String id) =>
      '/student/assignments/$id/submissions';
  static String studentAssignmentSubmit(String id) => '/student/assignments/$id/submit';
  static String studentAssignmentRun(String id) => '/student/assignments/$id/run';
  static String studentAssignmentProctorEvents(String id) =>
      '/student/assignments/$id/proctor-events';
  static String studentAssignmentLeaderboard(String id) =>
      '/student/assignments/$id/leaderboard';

  // ── Student: practice ─────────────────────────────────────────────────────
  static const practiceQuestions = '/student/practice/questions';
  static const practiceFilters = '/student/practice/filters';
  static const practiceSummary = '/student/practice/summary';
  static const practiceLeaderboard = '/student/practice/leaderboard';
  static const practiceBadges = '/student/practice/badges';
  static const practiceAnalytics = '/student/practice/analytics';
  static String practiceQuestion(String id) => '/student/practice/questions/$id';
  static String practiceQuestionAttempts(String id) =>
      '/student/practice/questions/$id/attempts';
  static String practiceQuestionNavigate(String id) =>
      '/student/practice/questions/$id/navigate';
  static String practiceQuestionRun(String id) => '/student/practice/questions/$id/run';
  static String practiceQuestionRunCustom(String id) =>
      '/student/practice/questions/$id/run-custom';
  static String practiceQuestionSubmit(String id) =>
      '/student/practice/questions/$id/submit';
  static String practiceQuestionBookmark(String id) =>
      '/student/practice/questions/$id/bookmark';

  // ── Student: daily challenge ──────────────────────────────────────────────
  static const dailyChallenge = '/student/practice/daily-challenge';
  static const dailyChallengeCalendar = '/student/practice/daily-challenge/calendar';
  static const dailyChallengeHistory = '/student/practice/daily-challenge/history';
  static String dailyChallengeByDate(String date) =>
      '/student/practice/daily-challenge/by-date/$date';
  static String dailyChallengeSubmit(String setId) =>
      '/student/practice/daily-challenge/$setId/submit';

  // ── Question discussions (any authenticated role) ─────────────────────────
  static String questionDiscussions(String questionId) =>
      '/practice/questions/$questionId/discussions';
  static String discussionReplies(String id) => '/practice/discussions/$id/replies';
  static String discussion(String id) => '/practice/discussions/$id';
  static String discussionReactions(String id) => '/practice/discussions/$id/reactions';

  // ── Student: contests ─────────────────────────────────────────────────────
  static const studentContests = '/student/contests';
  static String studentContest(String id) => '/student/contests/$id';
  static String studentContestRegister(String id) => '/student/contests/$id/register';
  static String studentContestStart(String id) => '/student/contests/$id/start';
  static String studentContestFinish(String id) => '/student/contests/$id/finish';
  static String studentContestStandings(String id) => '/student/contests/$id/standings';
  static String studentContestMySubmissions(String id) =>
      '/student/contests/$id/my-submissions';
  static String studentContestProctorEvents(String id) =>
      '/student/contests/$id/proctor-events';
  static String contestProblem(String contestId, String problemId) =>
      '/student/contests/$contestId/problems/$problemId';
  static String contestProblemRun(String contestId, String problemId) =>
      '/student/contests/$contestId/problems/$problemId/run';
  static String contestProblemRunCustom(String contestId, String problemId) =>
      '/student/contests/$contestId/problems/$problemId/run-custom';
  static String contestProblemSubmit(String contestId, String problemId) =>
      '/student/contests/$contestId/problems/$problemId/submit';
  static String contestSubmission(String submissionId) =>
      '/student/contests/submissions/$submissionId';
  static const contestRatingMe = '/student/contest-ratings/me';
  static const contestRatingLeaderboard = '/student/contest-ratings/leaderboard';

  // ── Student: attendance ───────────────────────────────────────────────────
  static const studentAttendanceSessions = '/student/attendance/sessions';
  static const studentAttendanceOverall = '/student/attendance/analytics/overall';
  static String studentCourseAttendance(String courseId) =>
      '/student/attendance/courses/$courseId/analytics';

  // ── Student: calendar / academic calendar ─────────────────────────────────
  static const studentCalendar = '/student/calendar';
  static const studentAcademicCalendar = '/student/academic-calendar';

  // ── Student: analytics ────────────────────────────────────────────────────
  static const studentAnalyticsOverview = '/student/analytics/overview';
  static String studentAnalyticsSemester(String semesterId) =>
      '/student/analytics/semester/$semesterId';

  // ── Student: admission ────────────────────────────────────────────────────
  static const studentAdmission = '/student/admission';
  static String studentAdmissionDocumentUrl(String docId) =>
      '/student/admission/documents/$docId/presigned-url';

  // ── Notes (any authenticated role) ────────────────────────────────────────
  static const notes = '/notes';
  static const notesMyStats = '/notes/my-stats';
  static const notesShareableStudents = '/notes/shareable-students';
  static String note(String id) => '/notes/$id';
  static String noteLike(String id) => '/notes/$id/like';
  static String noteComments(String id) => '/notes/$id/comments';
  static String noteComment(String commentId) => '/notes/comments/$commentId';
  static String noteShares(String id) => '/notes/$id/shares';
  static String noteShare(String id) => '/notes/$id/share';
  static String noteUnshare(String id, String userId) => '/notes/$id/shares/$userId';

  // ── Announcements ─────────────────────────────────────────────────────────
  static const announcementsFeed = '/announcements/student/feed';
  static const announcementsDashboard = '/announcements/student/dashboard';
  static String studentAnnouncement(String id) => '/announcements/student/$id';
  static String announcementRegister(String id) => '/announcements/$id/register';
  static String announcementCancelRegistration(String id) =>
      '/announcements/$id/cancel-registration';

  // ── Rewards ───────────────────────────────────────────────────────────────
  static const rewardsVisit = '/rewards/visit';
  static const rewardsStore = '/rewards/store';
  static String rewardsPurchase(String productId) => '/rewards/store/$productId/purchase';
  static const rewardsWallet = '/rewards/wallet';
  static const rewardsTransactions = '/rewards/wallet/transactions';
  static const rewardsOrders = '/rewards/orders';
  static String rewardsOrderMessages(String orderId) => '/rewards/orders/$orderId/messages';
  static const rewardsUseTicket = '/rewards/tickets/use';
}
