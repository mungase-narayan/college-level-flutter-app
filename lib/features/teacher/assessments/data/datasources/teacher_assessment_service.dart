import '../../../../../core/constants/api_urls.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../../core/network/dio_client.dart';
import '../models/bank_question_model.dart';
import '../models/teacher_assessment_model.dart';

/// Raw HTTP for assessment authoring.
///
/// These paths sit on the `/assessments` router, **not** under `/teacher` —
/// only the grading endpoints do.
class TeacherAssessmentService {
  const TeacherAssessmentService(this._client);

  final DioClient _client;

  /// `GET /assessments` — one call feeds both the Assignments and Quiz tabs;
  /// the category split happens client-side.
  ///
  /// `courseMaterialId` narrows it to the assignments published against one
  /// material, which is what the Learning Plan panel shows.
  Future<List<TeacherAssessmentModel>> list({
    required String courseId,
    String? divisionId,
    String? courseMaterialId,
    int limit = 100,
  }) async {
    final response = await _client.get(
      ApiUrls.assessments,
      query: {
        'courseId': courseId,
        'divisionId': divisionId,
        'courseMaterialId': courseMaterialId,
        'limit': limit,
      },
      parse: (data) => Paginated<TeacherAssessmentModel>.fromJson(
        data,
        TeacherAssessmentModel.fromJson,
      ).items,
    );
    return response.data;
  }

  Future<TeacherAssessmentDetailModel> getDetail(String id) async {
    final response = await _client.get(
      ApiUrls.assessment(id),
      parse: (data) => TeacherAssessmentDetailModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  /// `POST /assessments` → the created assessment, whose id the caller needs
  /// to attach questions afterwards.
  Future<TeacherAssessmentModel> create(Map<String, dynamic> body) async {
    final response = await _client.post(
      ApiUrls.assessments,
      body: body,
      parse: (data) => TeacherAssessmentModel.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      ),
    );
    return response.data;
  }

  Future<void> update({
    required String id,
    required Map<String, dynamic> body,
  }) =>
      _client.patch(ApiUrls.assessment(id), body: body, parse: (_) => null);

  Future<void> delete(String id) =>
      _client.delete(ApiUrls.assessment(id), parse: (_) => null);

  /// Attaches one question from the bank.
  Future<void> addQuestion({
    required String assessmentId,
    required String questionId,
  }) =>
      _client.post(
        ApiUrls.assessmentQuestions(assessmentId),
        body: {'questionId': questionId},
        parse: (_) => null,
      );

  /// Detaches a question. [assessmentQuestionId] is the **join-row** id, not
  /// the question's own id — the wrong one fails quietly.
  Future<void> removeQuestion({
    required String assessmentId,
    required String assessmentQuestionId,
  }) =>
      _client.delete(
        ApiUrls.assessmentQuestion(assessmentId, assessmentQuestionId),
        parse: (_) => null,
      );

  /// The question source for the picker.
  ///
  /// With an [assessmentId] this is the bank endpoint, which already excludes
  /// the questions attached to that assessment. Without one — the create flow,
  /// where no id exists yet — it falls back to the teacher's own active
  /// questions, which exclude nothing; the picker dedupes those itself.
  Future<Paginated<BankQuestionModel>> listBankQuestions({
    String? assessmentId,
    int page = 1,
    int limit = 8,
    String? search,
    String? type,
    String? difficulty,
    String? category,
  }) async {
    final bank = assessmentId != null && assessmentId.isNotEmpty;
    final response = await _client.get(
      bank ? ApiUrls.assessmentQuestionBank(assessmentId) : ApiUrls.teacherQuestions,
      query: {
        'page': page,
        'limit': limit,
        'search': (search ?? '').isEmpty ? null : search,
        'type': type,
        'difficulty': difficulty,
        'category': category,
        // Only the fallback endpoint needs the filter; the bank is active-only
        // already.
        if (!bank) 'status': 'active',
      },
      parse: (data) => Paginated<BankQuestionModel>.fromJson(
        data,
        BankQuestionModel.fromJson,
      ),
    );
    return response.data;
  }

  /// `PATCH /assessments/:id/publish-results` — releases scores, or withdraws
  /// them when [publish] is false.
  Future<void> publishResults({
    required String id,
    required bool publish,
  }) =>
      _client.patch(
        ApiUrls.assessmentPublishResults(id),
        body: {'publish': publish},
        parse: (_) => null,
      );
}
