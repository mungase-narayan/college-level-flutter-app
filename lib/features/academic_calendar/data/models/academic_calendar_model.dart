import '../../domain/entities/academic_calendar.dart';

String _string(Object? value) => value is String ? value : '';

String? _stringOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// JSON → [AcademicCalendar].
class AcademicCalendarModel extends AcademicCalendar {
  const AcademicCalendarModel({
    required super.id,
    required super.title,
    super.description,
    super.startDate,
    super.endDate,
    super.batchName,
    super.departmentName,
    super.semesterCode,
    super.entries,
  });

  /// The endpoint answers `200` with `data: null` when the student has no
  /// current semester, or when nothing is published for their scope. That is
  /// neither an error nor an empty list, so it has to survive parsing as a null
  /// rather than becoming an empty calendar.
  static AcademicCalendarModel? fromJsonOrNull(Object? data) {
    // `is Map` rather than `is Map<String, dynamic>`: a decoder that hands back
    // a `Map<dynamic, dynamic>` is still a payload, and rejecting it here would
    // look identical to "nothing published".
    if (data is! Map) return null;
    return AcademicCalendarModel.fromJson(Map<String, dynamic>.from(data));
  }

  factory AcademicCalendarModel.fromJson(Map<String, dynamic> json) =>
      AcademicCalendarModel(
        id: _string(json['id']),
        title: _string(json['title']),
        description: _stringOrNull(json['description']),
        startDate: _stringOrNull(json['startDate']),
        endDate: _stringOrNull(json['endDate']),
        batchName: _stringOrNull(json['batchName']),
        departmentName: _stringOrNull(json['departmentName']),
        // No `?? 0`: zero is a legal code, and the web renders `Semester 0`
        // for it. Defaulting would invent a semester that was never sent.
        semesterCode: (json['semesterCode'] as num?)?.toInt(),
        entries: ((json['entries'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AcademicCalendarEntryModel.fromJson)
            .toList(growable: false),
      );
}

/// JSON → [AcademicCalendarEntry].
class AcademicCalendarEntryModel extends AcademicCalendarEntry {
  const AcademicCalendarEntryModel({
    required super.id,
    required super.type,
    required super.title,
    required super.startDate,
    super.description,
    super.endDate,
    super.colorCode,
  });

  factory AcademicCalendarEntryModel.fromJson(Map<String, dynamic> json) =>
      AcademicCalendarEntryModel(
        id: _string(json['id']),
        type: json['type'] as String? ?? 'event',
        title: _string(json['title']),
        description: _stringOrNull(json['description']),
        startDate: _string(json['startDate']),
        endDate: _stringOrNull(json['endDate']),
        colorCode: _stringOrNull(json['colorCode']),
      );
}
