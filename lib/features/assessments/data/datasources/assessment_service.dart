import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';
import '../models/assessment_detail_model.dart';
import '../models/student_assessment_model.dart';

/// Raw HTTP for the student assessment endpoints — the port of
/// `src/api/student-assignment`.
class AssessmentService {
  const AssessmentService(this._client);

  final DioClient _client;

  /// `GET /student/assignments?courseId=…[&category=quiz]`.
  ///
  /// Returns a plain array — this endpoint is not paginated. Omitting
  /// `category` makes the backend **exclude** quiz categories, which is what
  /// separates the Assignments tab from the Quiz tab.
  Future<List<StudentAssessmentModel>> listForCourse({
    required String courseId,
    String? category,
    String? courseMaterialId,
  }) async {
    final response = await _client.get(
      ApiUrls.studentAssignments,
      query: {
        'courseId': courseId,
        'category': category,
        'courseMaterialId': courseMaterialId,
      },
      parse: (data) => (data as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(StudentAssessmentModel.fromJson)
              .toList(growable: false) ??
          const <StudentAssessmentModel>[],
    );
    return response.data;
  }

  /// `GET /student/assignments/:id` — assessment, questions, submission,
  /// answers, and whether results are published.
  Future<AssessmentDetailModel> getDetail(String assessmentId) async {
    final response = await _client.get(
      ApiUrls.studentAssignment(assessmentId),
      parse: (data) =>
          AssessmentDetailModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `POST /student/assignments/:id/submissions` — begins the attempt and
  /// starts the server-side clock.
  Future<void> startAttempt(String assessmentId) async {
    await _client.post(
      ApiUrls.studentAssignmentSubmissions(assessmentId),
      parse: (_) => null,
    );
  }

  /// `PATCH /student/assignments/:id/submission` — the autosave.
  ///
  /// `answers` entries are keyed by **assessmentQuestionId**, not questionId.
  Future<void> saveDraft({
    required String assessmentId,
    List<Map<String, dynamic>>? answers,
    String? note,
    List<String>? fileIds,
  }) async {
    await _client.patch(
      ApiUrls.studentAssignmentSubmission(assessmentId),
      body: {'answers': ?answers, 'note': ?note, 'fileIds': ?fileIds},
      parse: (_) => null,
    );
  }

  /// `POST /student/assignments/:id/submit` — finalizes the attempt.
  ///
  /// [autoSubmitted] is set by the proctoring layer when a violation limit
  /// forces the submission.
  Future<void> submit({
    required String assessmentId,
    List<Map<String, dynamic>>? answers,
    String? note,
    List<String>? fileIds,
    bool autoSubmitted = false,
  }) async {
    await _client.post(
      ApiUrls.studentAssignmentSubmit(assessmentId),
      body: {
        'answers': ?answers,
        'note': ?note,
        'fileIds': ?fileIds,
        'autoSubmitted': autoSubmitted,
      },
      parse: (_) => null,
    );
  }
}
