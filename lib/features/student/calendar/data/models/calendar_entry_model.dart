import '../../domain/entities/calendar_entry.dart';

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

String _string(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

String? _stringOrNull(Object? value) {
  final text = value is String ? value.trim() : null;
  return (text == null || text.isEmpty) ? null : text;
}

CalendarPersonRef? _person(Object? value) {
  final json = _map(value);
  final id = _stringOrNull(json['id']);
  if (id == null) return null;
  return CalendarPersonRef(id: id, name: _stringOrNull(json['name']));
}

CalendarLabelRef? _label(Object? value) {
  final json = _map(value);
  final id = _stringOrNull(json['id']);
  if (id == null) return null;
  return CalendarLabelRef(
    id: id,
    name: _stringOrNull(json['name']),
    code: _stringOrNull(json['code']),
  );
}

CalendarAudience? _audience(Object? value) {
  final json = _map(value);
  final scope = _stringOrNull(json['scope']);
  if (scope == null) return null;
  return CalendarAudience(
    scope: scope,
    batch: _stringOrNull(json['batch']),
    department: _stringOrNull(json['department']),
    semester: _stringOrNull(json['semester']),
    division: _stringOrNull(json['division']),
  );
}

class CalendarEntryModel extends CalendarEntry {
  const CalendarEntryModel({
    required super.id,
    required super.parentId,
    required super.source,
    required super.type,
    required super.title,
    required super.start,
    required super.end,
    super.description,
    super.isAllDay,
    super.colorCode,
    super.recurrenceRule,
    super.location,
    super.meetingLink,
    super.teacher,
    super.room,
    super.course,
    super.division,
    super.audience,
  });

  /// Returns null for a row with no usable start — a broken entry is better
  /// dropped than drawn at midnight on the wrong day.
  static CalendarEntryModel? fromJson(Map<String, dynamic> json) {
    final start = parseCalendarTime(_stringOrNull(json['start']));
    if (start == null) return null;
    // An event that somehow ends before it starts still needs a positive
    // height; the timeline enforces a minimum anyway.
    final end = parseCalendarTime(_stringOrNull(json['end'])) ??
        start.add(const Duration(minutes: 30));

    final id = _stringOrNull(json['id']);
    final parentId = _stringOrNull(json['parentId']);

    return CalendarEntryModel(
      id: id ?? parentId ?? start.toIso8601String(),
      parentId: parentId ?? id ?? '',
      source: _string(json['source']) == 'timetable'
          ? CalendarSource.timetable
          : CalendarSource.event,
      type: CalendarEntryTypeX.fromWire(_stringOrNull(json['type'])),
      title: _string(json['title'], 'Untitled'),
      start: start,
      end: end.isBefore(start) ? start : end,
      description: _stringOrNull(json['description']),
      isAllDay: json['isAllDay'] == true,
      colorCode: _stringOrNull(json['colorCode']),
      recurrenceRule: _stringOrNull(json['recurrenceRule']),
      location: _stringOrNull(json['location']),
      meetingLink: _stringOrNull(json['meetingLink']),
      teacher: _person(json['teacher']),
      room: _label(json['room']),
      course: _label(json['course']),
      division: _label(json['division']),
      audience: _audience(json['audience']),
    );
  }

  /// Parses the endpoint's flat array, dropping unusable rows and re-sorting.
  ///
  /// The server sorts `start` as a *string*, which compares a naive timetable
  /// stamp against a UTC event stamp lexicographically and interleaves the two
  /// wrongly. Sorting on the resolved local time is the fix.
  static List<CalendarEntry> listFromJson(Object? data) {
    final rows = (data as List?) ?? const [];
    final entries = <CalendarEntry>[];
    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final entry = CalendarEntryModel.fromJson(row);
      if (entry != null) entries.add(entry);
    }
    entries.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.title.compareTo(b.title);
    });
    return entries;
  }
}
