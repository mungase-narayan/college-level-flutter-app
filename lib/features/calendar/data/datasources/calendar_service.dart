import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/calendar_entry.dart';
import '../../domain/entities/calendar_view.dart';
import '../models/calendar_entry_model.dart';

/// Raw HTTP for the combined student calendar — the port of
/// `src/api/calendar`. Read-only: students cannot create or edit entries.
class CalendarService {
  const CalendarService(this._client);

  final DioClient _client;

  /// `GET /student/calendar?from&to&view` → a flat, unpaginated array of
  /// occurrences merging timetable classes and calendar events.
  ///
  /// `type` is deliberately never sent. The validator rejects `class` with a
  /// 422, and the controller includes the timetable only when no `type` is
  /// present — so any value at all would silently empty the grid of classes.
  /// The filter strip therefore filters what is already here, client-side.
  ///
  /// The scope ids the query accepts are ignored for students: the server
  /// derives batch/department/semester/division from the profile.
  Future<List<CalendarEntry>> getCalendar({
    required CalendarRange range,
    required CalendarViewMode view,
  }) async {
    final response = await _client.get(
      ApiUrls.studentCalendar,
      query: {
        // The web sends `.toISOString()`; matching it keeps both clients
        // bucketing the same days.
        'from': range.from.toUtc().toIso8601String(),
        'to': range.to.toUtc().toIso8601String(),
        'view': view.wire,
      },
      parse: CalendarEntryModel.listFromJson,
    );
    return response.data;
  }
}
