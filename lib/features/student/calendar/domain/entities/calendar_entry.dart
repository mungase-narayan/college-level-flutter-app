import 'package:equatable/equatable.dart';

/// Which table an entry came from. Timetable rows are recurring weekly class
/// slots expanded server-side; event rows are `calendar_events`.
enum CalendarSource { timetable, event }

/// The four kinds the combined endpoint can return.
///
/// `class` is a Dart keyword, hence [lesson] — the wire value is still
/// `'class'`.
enum CalendarEntryType { lesson, event, meeting, task }

extension CalendarEntryTypeX on CalendarEntryType {
  String get wire => switch (this) {
        CalendarEntryType.lesson => 'class',
        CalendarEntryType.event => 'event',
        CalendarEntryType.meeting => 'meeting',
        CalendarEntryType.task => 'task',
      };

  /// `TYPE_LABEL` in `event-details-dialog.tsx`.
  String get label => switch (this) {
        CalendarEntryType.lesson => 'Class',
        CalendarEntryType.event => 'Event',
        CalendarEntryType.meeting => 'Meeting',
        CalendarEntryType.task => 'Task Reminder',
      };

  /// `TYPE_HEX` in `components/calendar/constants.ts` — the accent used when an
  /// entry carries no usable `colorCode` of its own.
  String get accentHex => switch (this) {
        CalendarEntryType.lesson => '#3b82f6',
        CalendarEntryType.event => '#8b5cf6',
        CalendarEntryType.meeting => '#0ea5e9',
        CalendarEntryType.task => '#10b981',
      };

  static CalendarEntryType fromWire(String? value) => switch (value) {
        'class' => CalendarEntryType.lesson,
        'meeting' => CalendarEntryType.meeting,
        'task' => CalendarEntryType.task,
        _ => CalendarEntryType.event,
      };
}

/// Normalises the two datetime formats `GET /student/calendar` mixes into one
/// array.
///
/// Timetable rows are naive local wall-clock strings (`2026-08-17T09:00:00`,
/// no offset, no `Z`); event rows are real UTC instants (`...Z`). `DateTime`
/// keeps that distinction in `isUtc`, and `toLocal()` is exactly the right
/// operation for both: it converts a genuine instant into device time and
/// leaves a floating wall clock untouched.
///
/// Getting this wrong shifts every class by the UTC offset, which is why it
/// lives in one place rather than at each call site.
DateTime? parseCalendarTime(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  return DateTime.tryParse(iso)?.toLocal();
}

const _hexPattern = r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$';

/// Expands `#abc` to `#aabbcc` and rejects anything that isn't a hex colour —
/// the `HEX_RE` guard in `event-block.tsx`.
String? normaliseHex(String? value) {
  final hex = value?.trim();
  if (hex == null || !RegExp(_hexPattern).hasMatch(hex)) return null;
  if (hex.length == 7) return hex.toLowerCase();
  final body = hex.substring(1).toLowerCase();
  return '#${body[0] * 2}${body[1] * 2}${body[2] * 2}';
}

class CalendarPersonRef extends Equatable {
  const CalendarPersonRef({required this.id, this.name});

  final String id;
  final String? name;

  @override
  List<Object?> get props => [id, name];
}

/// A room, course or division reference — all three share `{id, code, name}`
/// on the wire (a course calls them `name`/`code` too).
class CalendarLabelRef extends Equatable {
  const CalendarLabelRef({required this.id, this.name, this.code});

  final String id;
  final String? name;
  final String? code;

  /// `Physics Lab (L-204)` — the shape the detail rows use.
  String get display {
    final name = this.name?.trim();
    final code = this.code?.trim();
    if (name == null || name.isEmpty) return code ?? '';
    if (code == null || code.isEmpty) return name;
    return '$name ($code)';
  }

  @override
  List<Object?> get props => [id, name, code];
}

/// Who an event was addressed to. `scope` is the deepest level set; the names
/// above it resolve the ancestor chain, and all four are null school-wide.
class CalendarAudience extends Equatable {
  const CalendarAudience({
    required this.scope,
    this.batch,
    this.department,
    this.semester,
    this.division,
  });

  final String scope;
  final String? batch;
  final String? department;
  final String? semester;
  final String? division;

  bool get isSchoolWide => scope == 'school';

  /// The chips the web renders, in its order, skipping empty levels.
  List<String> get chips => [
        if (batch != null && batch!.isNotEmpty) batch!,
        if (department != null && department!.isNotEmpty) department!,
        if (semester != null && semester!.isNotEmpty) semester!,
        if (division != null && division!.isNotEmpty) 'Div ${division!}',
      ];

  @override
  List<Object?> get props => [scope, batch, department, semester, division];
}

/// One occurrence on the calendar — a single class on a single day, or one
/// occurrence of an event.
///
/// Note what is *not* here: events arrive with `course`, `room` and `division`
/// hardcoded null server-side and never carry an assessment id, so an event
/// cannot deep-link anywhere. Only classes carry a course, a room and a
/// teacher name.
class CalendarEntry extends Equatable {
  const CalendarEntry({
    required this.id,
    required this.parentId,
    required this.source,
    required this.type,
    required this.title,
    required this.start,
    required this.end,
    this.description,
    this.isAllDay = false,
    this.colorCode,
    this.recurrenceRule,
    this.location,
    this.meetingLink,
    this.teacher,
    this.room,
    this.course,
    this.division,
    this.audience,
  });

  /// Per-occurrence, and stable: `"{slotId}:{yyyy-MM-dd}"` for a class.
  final String id;

  /// The master record — the timetable slot or the calendar event.
  final String parentId;

  final CalendarSource source;
  final CalendarEntryType type;
  final String title;

  /// Already normalised to device-local time by [parseCalendarTime].
  final DateTime start;
  final DateTime end;

  final String? description;
  final bool isAllDay;
  final String? colorCode;
  final String? recurrenceRule;
  final String? location;
  final String? meetingLink;
  final CalendarPersonRef? teacher;
  final CalendarLabelRef? room;
  final CalendarLabelRef? course;
  final CalendarLabelRef? division;
  final CalendarAudience? audience;

  bool get isClass => source == CalendarSource.timetable;

  /// The entry's own colour when it is a usable hex, else its type accent.
  String get accentHex => normaliseHex(colorCode) ?? type.accentHex;

  /// `L-204 · Dr Rao` — the second line inside a timeline block.
  String? get subtitle {
    final parts = [
      room?.code?.trim(),
      teacher?.name?.trim(),
    ].where((p) => p != null && p.isNotEmpty).cast<String>();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Minutes from midnight, clamped into the day — used to place the block on
  /// the timeline. Entries starting before the visible day (a multi-day event)
  /// clamp to its top.
  int startMinutesOn(DateTime day) =>
      _isSameDay(start, day) ? start.hour * 60 + start.minute : 0;

  int endMinutesOn(DateTime day) =>
      _isSameDay(end, day) ? end.hour * 60 + end.minute : 24 * 60;

  bool startsOn(DateTime day) => _isSameDay(start, day);

  @override
  List<Object?> get props => [
        id,
        parentId,
        source,
        type,
        title,
        start,
        end,
        description,
        isAllDay,
        colorCode,
        recurrenceRule,
        location,
        meetingLink,
        teacher,
        room,
        course,
        division,
        audience,
      ];
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
