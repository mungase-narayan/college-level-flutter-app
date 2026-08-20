import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/network/dio_client.dart';
import '../../../../../core/utils/json_coerce.dart';
import '../../domain/entities/student_assessment.dart';
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

  /// `GET /student/assignments/all?category=quiz&…` — every quiz (or
  /// assignment) across the student's enrolled courses.
  ///
  /// Unlike [listForCourse] this one is paginated and filtered server-side, and
  /// each row carries the course and the teacher who set it. `category` is as
  /// load-bearing here as it is there: omit it and the backend *excludes*
  /// quizzes and hands back assignments instead.
  Future<Paginated<StudentAssessmentModel>> listAll({
    String? category,
    String? courseId,
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get(
      ApiUrls.studentAssignmentsAll,
      query: {
        'category': category,
        'courseId': courseId,
        'status': status,
        'search': search,
        'page': page,
        'limit': limit,
      },
      parse: (data) => Paginated<StudentAssessmentModel>.fromJson(
        data,
        StudentAssessmentModel.fromJson,
      ),
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

  /// `POST /student/assignments/:id/proctor-events` — records one violation.
  ///
  /// The response, not the client, is the authority: it carries the running
  /// total and whether that total has tripped the assessment's limit.
  Future<ProctorEventResult> recordProctorEvent({
    required String assessmentId,
    required String eventType,
    required String occurredAt,
    Map<String, dynamic>? meta,
  }) async {
    final response = await _client.post(
      ApiUrls.studentAssignmentProctorEvents(assessmentId),
      body: {
        'eventType': eventType,
        'occurredAt': occurredAt,
        'meta': ?meta,
      },
      parse: (data) {
        final json = (data as Map<String, dynamic>?) ?? const {};
        return ProctorEventResult(
          violationCount: asInt(json['violationCount']),
          shouldAutoSubmit: json['shouldAutoSubmit'] as bool? ?? false,
        );
      },
    );
    return response.data;
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
