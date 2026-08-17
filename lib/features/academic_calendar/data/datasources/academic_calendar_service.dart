import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';
import '../models/academic_calendar_model.dart';

/// Raw HTTP for the student academic calendar — the port of
/// `src/api/academic-calendar`.
///
/// One endpoint, no parameters: the whole published calendar for the student's
/// current semester arrives in a single response, entries included.
class AcademicCalendarService {
  const AcademicCalendarService(this._client);

  final DioClient _client;

  /// `GET /student/academic-calendar`.
  ///
  /// Null when the student has no current semester, or when nothing is
  /// published for their batch/department/semester — the server signals both
  /// with a `200` carrying `data: null`, so it must be read off the body.
  Future<AcademicCalendarModel?> getMyCalendar() async {
    final response = await _client.get(
      ApiUrls.studentAcademicCalendar,
      parse: AcademicCalendarModel.fromJsonOrNull,
    );
    return response.data;
  }
}
