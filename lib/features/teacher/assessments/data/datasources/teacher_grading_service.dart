import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/dio_client.dart';
import '../../domain/entities/submission.dart';
import '../models/submission_model.dart';

/// Raw HTTP for grading.
///
/// These paths sit under `/teacher/assignments`, **not** on the `/assessments`
/// router that authoring uses. The two families are not interchangeable, so
/// they get separate services.
class TeacherGradingService {
  const TeacherGradingService(this._client);

  final DioClient _client;

  Future<AssignmentOverviewModel> getOverview({
    required String assessmentId,
    int page = 1,
    int limit = 15,
    String? search,
    String sortBy = 'score',
    String sortOrder = 'desc',
  }) async {
    final response = await _client.get(
      ApiUrls.teacherAssignmentOverview(assessmentId),
      query: {
        'page': page,
        'limit': limit,
        'search': (search ?? '').isEmpty ? null : search,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      },
      parse: (data) => AssignmentOverviewModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// Returns a bare array, not a paginated envelope.
  Future<List<QuestionStatModel>> getStatistics(String assessmentId) async {
    final response = await _client.get(
      ApiUrls.teacherAssignmentStatistics(assessmentId),
      parse: (data) => [
        for (final row in (data as List?) ?? const [])
          if (row is Map<String, dynamic>) QuestionStatModel.fromJson(row),
      ],
    );
    return response.data;
  }

  Future<ResultSheetModel> getResultSheet(String assessmentId) async {
    final response = await _client.get(
      ApiUrls.teacherAssignmentResults(assessmentId),
      parse: (data) => ResultSheetModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// The attempt in full. [SubmissionNote] rides in the same payload and is
  /// pulled out alongside, since only submission-type attempts use it.
  Future<({SubmissionDetailModel detail, SubmissionNote note})> getSubmission({
    required String assessmentId,
    required String submissionId,
  }) async {
    final response = await _client.get(
      ApiUrls.teacherAssignmentSubmission(assessmentId, submissionId),
      parse: (data) {
        final json = (data as Map<String, dynamic>?) ?? const {};
        return (
          detail: SubmissionDetailModel.fromJson(json),
          note: submissionNoteFromJson(json),
        );
      },
    );
    return response.data;
  }

  Future<void> evaluate({
    required String assessmentId,
    required String submissionId,
    required Map<String, dynamic> body,
  }) =>
      _client.patch(
        ApiUrls.teacherAssignmentEvaluate(assessmentId, submissionId),
        body: body,
        parse: (_) => null,
      );

  /// Clears the violations and reopens the attempt. Takes no body.
  Future<void> allowReattempt({
    required String assessmentId,
    required String submissionId,
  }) =>
      _client.patch(
        ApiUrls.teacherAssignmentReattempt(assessmentId, submissionId),
        parse: (_) => null,
      );
}
