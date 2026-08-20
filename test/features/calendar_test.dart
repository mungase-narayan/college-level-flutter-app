import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/core/network/dio_client.dart';
import 'package:college_level/features/student/calendar/data/datasources/calendar_service.dart';
import 'package:college_level/features/student/calendar/data/models/calendar_entry_model.dart';
import 'package:college_level/features/student/calendar/domain/entities/calendar_entry.dart';
import 'package:college_level/features/student/calendar/domain/entities/calendar_view.dart';
import 'package:college_level/features/student/calendar/domain/usecases/calendar_usecases.dart';
import 'package:college_level/features/student/calendar/presentation/bloc/calendar_cubit.dart';
import 'package:college_level/features/student/calendar/presentation/bloc/today_sessions_cubit.dart';
import 'package:college_level/features/student/calendar/presentation/widgets/calendar_timeline.dart';
import 'package:college_level/features/student/calendar/presentation/widgets/timetable_pdf.dart';

class _MockGetCalendar extends Mock implements GetCalendarUseCase {}

/// Records what the service asked for and replays a canned payload, so the
/// query the endpoint actually receives can be asserted on.
class _RecordingClient extends Mock implements DioClient {
  String? path;
  Map<String, dynamic>? query;
  Object? payload = const <Object>[];

  @override
  Future<ApiResponse<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? data) parse,
  }) async {
    this.path = path;
    this.query = query;
    return ApiResponse<T>(
      statusCode: 200,
      data: parse(payload),
      message: 'ok',
      success: true,
    );
  }
}

Map<String, dynamic> _classJson({
  String id = 'slot-1:2026-08-17',
  String start = '2026-08-17T09:00:00',
  String end = '2026-08-17T10:00:00',
  String title = 'Data Structures',
}) =>
    {
      'id': id,
      'parentId': 'slot-1',
      'source': 'timetable',
      'type': 'class',
      'title': title,
      'start': start,
      'end': end,
      'isAllDay': false,
      'colorCode': null,
      'teacher': {'id': 't1', 'name': 'Dr Rao'},
      'room': {'id': 'r1', 'code': 'L-204', 'name': 'Lab 2'},
      'course': {'id': 'c1', 'name': 'DS', 'code': 'CS201'},
      'division': {'id': 'd1', 'name': 'A', 'code': 'A'},
    };

Map<String, dynamic> _eventJson({
  String id = 'evt-1',
  required String start,
  required String end,
  String type = 'event',
  String title = 'Orientation',
  String? colorCode,
}) =>
    {
      'id': id,
      'parentId': id,
      'source': 'event',
      'type': type,
      'title': title,
      'start': start,
      'end': end,
      'isAllDay': false,
      'colorCode': colorCode,
      'teacher': {'id': 't9', 'name': null},
      'room': null,
      'course': null,
      'division': null,
      'audience': {
        'scope': 'division',
        'batch': '2026',
        'department': 'CSE',
        'semester': 'S5',
        'division': 'A',
      },
    };

CalendarEntry _entry({
  required DateTime start,
  Duration length = const Duration(hours: 1),
  CalendarSource source = CalendarSource.event,
  CalendarEntryType type = CalendarEntryType.event,
  String title = 'Entry',
}) =>
    CalendarEntry(
      id: '$title-$start',
      parentId: title,
      source: source,
      type: type,
      title: title,
      start: start,
      end: start.add(length),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(
      CalendarQueryParams.of(CalendarViewMode.day, DateTime(2026)),
    );
  });

  group('datetime normalisation', () {
    // The endpoint mixes two formats in one array. Reading a naive timetable
    // stamp as UTC would shift every class by the device's offset.
    test('a naive timetable stamp keeps its wall clock', () {
      final parsed = parseCalendarTime('2026-08-17T09:00:00');

      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse);
      expect(parsed.hour, 9);
      expect(parsed.minute, 0);
      expect(parsed.day, 17);
    });

    test('a UTC event stamp is converted to local time', () {
      final local = DateTime(2026, 8, 17, 15, 30);
      final parsed = parseCalendarTime(local.toUtc().toIso8601String());

      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse);
      expect(parsed, local);
    });

    test('returns null rather than throwing on junk', () {
      expect(parseCalendarTime(null), isNull);
      expect(parseCalendarTime(''), isNull);
      expect(parseCalendarTime('not-a-date'), isNull);
    });
  });

  group('CalendarEntryModel', () {
    test('re-sorts by resolved local start, not by the raw string', () {
      // The server sorts these as strings, which compares a naive stamp
      // against a UTC one and can interleave them wrongly. Feed them in that
      // (wrong) order and expect the client to fix it.
      final entries = CalendarEntryModel.listFromJson([
        _eventJson(
          start: DateTime(2026, 8, 17, 10).toUtc().toIso8601String(),
          end: DateTime(2026, 8, 17, 11).toUtc().toIso8601String(),
        ),
        _classJson(),
      ]);

      expect(entries.map((e) => e.title), ['Data Structures', 'Orientation']);
      expect(entries.first.start.hour, 9);
      expect(entries.last.start.hour, 10);
    });

    test('drops a row with no usable start instead of drawing it at midnight', () {
      final entries = CalendarEntryModel.listFromJson([
        _classJson(),
        {'id': 'broken', 'source': 'event', 'type': 'event', 'title': 'X'},
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.title, 'Data Structures');
    });

    test('maps the class row in full', () {
      final entry = CalendarEntryModel.listFromJson([_classJson()]).single;

      expect(entry.source, CalendarSource.timetable);
      expect(entry.type, CalendarEntryType.lesson);
      expect(entry.isClass, isTrue);
      expect(entry.teacher?.name, 'Dr Rao');
      expect(entry.room?.code, 'L-204');
      expect(entry.course?.name, 'DS');
      expect(entry.subtitle, 'L-204 · Dr Rao');
    });

    test('keeps the audience chain and skips empty levels', () {
      final entry = CalendarEntryModel.listFromJson([
        _eventJson(
          start: DateTime(2026, 8, 17, 10).toUtc().toIso8601String(),
          end: DateTime(2026, 8, 17, 11).toUtc().toIso8601String(),
        ),
      ]).single;

      expect(entry.audience?.isSchoolWide, isFalse);
      expect(entry.audience?.chips, ['2026', 'CSE', 'S5', 'Div A']);
    });

    test('an end before the start never yields a negative span', () {
      final entry = CalendarEntryModel.listFromJson([
        _classJson(start: '2026-08-17T09:00:00', end: '2026-08-17T08:00:00'),
      ]).single;

      expect(entry.end.isBefore(entry.start), isFalse);
    });
  });

  group('accent colour', () {
    test('a valid colorCode wins over the type accent', () {
      final entry = CalendarEntryModel.listFromJson([
        _eventJson(
          start: DateTime(2026, 8, 17, 10).toUtc().toIso8601String(),
          end: DateTime(2026, 8, 17, 11).toUtc().toIso8601String(),
          colorCode: '#FF8800',
        ),
      ]).single;

      expect(entry.accentHex, '#ff8800');
    });

    test('a three-digit hex expands', () {
      expect(normaliseHex('#f80'), '#ff8800');
    });

    test('a malformed colorCode falls back to the type accent', () {
      final entry = CalendarEntryModel.listFromJson([
        _eventJson(
          start: DateTime(2026, 8, 17, 10).toUtc().toIso8601String(),
          end: DateTime(2026, 8, 17, 11).toUtc().toIso8601String(),
          type: 'task',
          colorCode: 'purple',
        ),
      ]).single;

      expect(entry.accentHex, '#10b981');
    });

    test('each type has its own accent', () {
      expect(CalendarEntryType.lesson.accentHex, '#3b82f6');
      expect(CalendarEntryType.event.accentHex, '#8b5cf6');
      expect(CalendarEntryType.meeting.accentHex, '#0ea5e9');
      expect(CalendarEntryType.task.accentHex, '#10b981');
    });
  });

  group('CalendarDates.rangeFor', () {
    test('day covers one whole day', () {
      final range = CalendarDates.rangeFor(
        CalendarViewMode.day,
        DateTime(2026, 8, 16, 13, 45),
      );

      expect(range.from, DateTime(2026, 8, 16));
      expect(range.to.day, 16);
      expect(range.to.hour, 23);
      expect(range.days, hasLength(1));
    });

    test('week runs Monday to Sunday', () {
      // 2026-08-16 is a Sunday, so its week starts on the 10th.
      final range =
          CalendarDates.rangeFor(CalendarViewMode.week, DateTime(2026, 8, 16));

      expect(range.from, DateTime(2026, 8, 10));
      expect(range.from.weekday, DateTime.monday);
      expect(range.to.weekday, DateTime.sunday);
      expect(range.days, hasLength(7));
    });

    test('month pads out to whole weeks so the grid has no blanks', () {
      final range =
          CalendarDates.rangeFor(CalendarViewMode.month, DateTime(2026, 8, 16));

      expect(range.from.weekday, DateTime.monday);
      expect(range.to.weekday, DateTime.sunday);
      // Padding reaches back into July and on into September.
      expect(range.from.month, 7);
      expect(range.to.month, 9);
      expect(range.days.length % 7, 0);
    });

    test('year covers Jan 1 to Dec 31', () {
      final range =
          CalendarDates.rangeFor(CalendarViewMode.year, DateTime(2026, 8, 16));

      expect(range.from, DateTime(2026));
      expect(range.to.month, 12);
      expect(range.to.day, 31);
    });
  });

  group('CalendarDates.shift', () {
    test('steps by the unit of the current view', () {
      final date = DateTime(2026, 8, 16);

      expect(CalendarDates.shift(CalendarViewMode.day, date, 1).day, 17);
      expect(CalendarDates.shift(CalendarViewMode.week, date, 1).day, 23);
      expect(CalendarDates.shift(CalendarViewMode.month, date, 1).month, 9);
      expect(CalendarDates.shift(CalendarViewMode.year, date, -1).year, 2025);
    });

    test('a month step from the 31st clamps instead of skipping February', () {
      final next =
          CalendarDates.shift(CalendarViewMode.month, DateTime(2026, 1, 31), 1);

      expect(next.month, 2);
      expect(next.day, 28);
    });
  });

  group('CalendarFilter', () {
    final lesson = _entry(
      start: DateTime(2026, 8, 17, 9),
      source: CalendarSource.timetable,
      type: CalendarEntryType.lesson,
      title: 'Class',
    );
    final meeting = _entry(
      start: DateTime(2026, 8, 17, 11),
      type: CalendarEntryType.meeting,
      title: 'Meeting',
    );

    test('Classes matches on the source, not the type string', () {
      expect(CalendarFilter.classes.matches(lesson), isTrue);
      expect(CalendarFilter.classes.matches(meeting), isFalse);
    });

    test('a type filter matches only that type', () {
      expect(CalendarFilter.meeting.matches(meeting), isTrue);
      expect(CalendarFilter.meeting.matches(lesson), isFalse);
      expect(CalendarFilter.all.matches(lesson), isTrue);
    });
  });

  group('CalendarService', () {
    test('never sends type — doing so would empty the grid of classes', () async {
      final client = _RecordingClient()..payload = [_classJson()];
      final service = CalendarService(client);

      await service.getCalendar(
        range: CalendarDates.rangeFor(CalendarViewMode.week, DateTime(2026, 8, 16)),
        view: CalendarViewMode.week,
      );

      expect(client.path, '/student/calendar');
      expect(client.query, isNot(contains('type')));
      expect(client.query!['view'], 'week');
    });

    test('sends from/to as UTC instants, as the web does', () async {
      final client = _RecordingClient();
      final service = CalendarService(client);
      final range =
          CalendarDates.rangeFor(CalendarViewMode.day, DateTime(2026, 8, 16));

      await service.getCalendar(range: range, view: CalendarViewMode.day);

      expect(client.query!['from'], endsWith('Z'));
      expect(client.query!['to'], endsWith('Z'));
      expect(
        DateTime.parse(client.query!['from'] as String).toLocal(),
        range.from,
      );
    });

    test('parses the flat array the endpoint returns', () async {
      final client = _RecordingClient()..payload = [_classJson()];
      final entries = await CalendarService(client).getCalendar(
        range: CalendarDates.rangeFor(CalendarViewMode.day, DateTime(2026, 8, 17)),
        view: CalendarViewMode.day,
      );

      expect(entries, hasLength(1));
      expect(entries.single.title, 'Data Structures');
    });
  });

  group('CalendarCubit', () {
    late _MockGetCalendar getCalendar;

    CalendarCubit build({
      CalendarViewMode view = CalendarViewMode.day,
      DateTime? today,
    }) =>
        CalendarCubit(
          getCalendar: getCalendar,
          initialView: view,
          today: today ?? DateTime(2026, 8, 16),
        );

    setUp(() {
      getCalendar = _MockGetCalendar();
      when(() => getCalendar(any())).thenAnswer(
        (_) async => Right<Failure, List<CalendarEntry>>([
          _entry(start: DateTime(2026, 8, 16, 9), title: 'Standup'),
        ]),
      );
    });

    test('loads the anchored range and publishes the entries', () async {
      final cubit = build();
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.entries, hasLength(1));
      expect(cubit.state.isFetching, isFalse);

      final params =
          verify(() => getCalendar(captureAny())).captured.single as CalendarQueryParams;
      expect(params.view, CalendarViewMode.day);
      expect(params.range.from, DateTime(2026, 8, 16));
    });

    test('a failed fetch keeps the entries already on screen', () async {
      final cubit = build();
      await cubit.load();

      when(() => getCalendar(any())).thenAnswer(
        (_) async => const Left(ServerFailure('offline')),
      );
      await cubit.shift(1);

      expect(cubit.state.status, RemoteStatus.failure);
      expect(cubit.state.entries, hasLength(1));
    });

    test('changing the filter does not refetch', () async {
      final cubit = build();
      await cubit.load();
      clearInteractions(getCalendar);

      cubit.setFilter(CalendarFilter.classes);

      expect(cubit.state.filter, CalendarFilter.classes);
      // The one entry is an event, so filtering to classes empties the view
      // without touching the cached list.
      expect(cubit.state.entries, hasLength(1));
      expect(cubit.state.visibleEntries, isEmpty);
      verifyNever(() => getCalendar(any()));
    });

    test('switching view refetches with the new window', () async {
      final cubit = build();
      await cubit.load();

      await cubit.setView(CalendarViewMode.week);

      expect(cubit.state.view, CalendarViewMode.week);
      final params = verify(() => getCalendar(captureAny())).captured.last
          as CalendarQueryParams;
      expect(params.view, CalendarViewMode.week);
      expect(params.range.from.weekday, DateTime.monday);
    });

    test('tapping a day in the month grid drills into that day', () async {
      final cubit = build(view: CalendarViewMode.month);
      await cubit.load();

      await cubit.openDay(DateTime(2026, 8, 20));

      expect(cubit.state.view, CalendarViewMode.day);
      expect(cubit.state.date, DateTime(2026, 8, 20));
    });

    test('tapping a month in the year grid opens that month', () async {
      final cubit = build(view: CalendarViewMode.year);
      await cubit.load();

      await cubit.openMonth(DateTime(2026, 3));

      expect(cubit.state.view, CalendarViewMode.month);
      expect(cubit.state.date.month, 3);
    });

    test('entriesOn returns only the entries starting that day', () async {
      when(() => getCalendar(any())).thenAnswer(
        (_) async => Right<Failure, List<CalendarEntry>>([
          _entry(start: DateTime(2026, 8, 16, 9), title: 'Today'),
          _entry(start: DateTime(2026, 8, 17, 9), title: 'Tomorrow'),
        ]),
      );
      final cubit = build();
      await cubit.load();

      expect(
        cubit.state.entriesOn(DateTime(2026, 8, 16)).map((e) => e.title),
        ['Today'],
      );
    });
  });

  group('timetable PDF', () {
    // 2026-08-17 is a Monday, so this week runs Mon 17 – Sun 23.
    test('groups classes into one row per period, in time order', () {
      final slots = timetableSlots([
        _entry(
          start: DateTime(2026, 8, 18, 9),
          source: CalendarSource.timetable,
          type: CalendarEntryType.lesson,
          title: 'Tue 9am',
        ),
        _entry(
          start: DateTime(2026, 8, 17, 14),
          source: CalendarSource.timetable,
          type: CalendarEntryType.lesson,
          title: 'Mon 2pm',
        ),
        _entry(
          start: DateTime(2026, 8, 17, 9),
          source: CalendarSource.timetable,
          type: CalendarEntryType.lesson,
          title: 'Mon 9am',
        ),
      ]);

      expect(slots, hasLength(2));
      expect(slots.first.startMinutes, 9 * 60);
      expect(slots.last.startMinutes, 14 * 60);
      // The 9 AM period holds both Monday's and Tuesday's class.
      expect(slots.first.byWeekday[DateTime.monday]?.title, 'Mon 9am');
      expect(slots.first.byWeekday[DateTime.tuesday]?.title, 'Tue 9am');
    });

    test('drops events, meetings and tasks — it is a class timetable', () {
      final slots = timetableSlots([
        _entry(
          start: DateTime(2026, 8, 17, 9),
          type: CalendarEntryType.meeting,
          title: 'Mentor sync',
        ),
        _entry(
          start: DateTime(2026, 8, 17, 11),
          source: CalendarSource.timetable,
          type: CalendarEntryType.lesson,
          title: 'Physics',
        ),
      ]);

      expect(slots, hasLength(1));
      expect(slots.single.byWeekday[DateTime.monday]?.title, 'Physics');
    });

    test('drops weekend classes — the printed grid is Mon–Fri', () {
      final slots = timetableSlots([
        _entry(
          start: DateTime(2026, 8, 22, 9), // Saturday
          source: CalendarSource.timetable,
          type: CalendarEntryType.lesson,
          title: 'Saturday lab',
        ),
      ]);

      expect(slots, isEmpty);
    });
  });

  group('timeline layout', () {
    final day = DateTime(2026, 8, 17);

    test('non-overlapping entries each take the full width', () {
      final placements = layoutDay([
        _entry(start: DateTime(2026, 8, 17, 9), title: 'A'),
        _entry(start: DateTime(2026, 8, 17, 11), title: 'B'),
      ], day);

      expect(placements.every((p) => p.lanes == 1), isTrue);
      expect(placements.every((p) => p.lane == 0), isTrue);
    });

    test('two overlapping entries split into two lanes', () {
      final placements = layoutDay([
        _entry(start: DateTime(2026, 8, 17, 9), title: 'A'),
        _entry(start: DateTime(2026, 8, 17, 9, 30), title: 'B'),
      ], day);

      expect(placements.map((p) => p.lanes), [2, 2]);
      expect(placements.map((p) => p.lane), [0, 1]);
    });

    test('a later, separate cluster starts again at one lane', () {
      final placements = layoutDay([
        _entry(start: DateTime(2026, 8, 17, 9), title: 'A'),
        _entry(start: DateTime(2026, 8, 17, 9, 30), title: 'B'),
        _entry(start: DateTime(2026, 8, 17, 14), title: 'C'),
      ], day);

      expect(placements.last.lanes, 1);
    });

    test('minutes are measured from midnight on the rendered day', () {
      final entry = _entry(start: DateTime(2026, 8, 17, 9, 15));

      expect(entry.startMinutesOn(day), 9 * 60 + 15);
      expect(entry.endMinutesOn(day), 10 * 60 + 15);
    });

    test('an entry running past midnight clamps to the end of the day', () {
      final entry = _entry(
        start: DateTime(2026, 8, 17, 23),
        length: const Duration(hours: 3),
      );

      expect(entry.endMinutesOn(day), 24 * 60);
    });
  });

  group("today's sessions", () {
    final today = DateTime(2026, 8, 17);

    CalendarEntry lesson({
      required int hour,
      String title = 'Class',
      String? id,
      int day = 17,
    }) =>
        CalendarEntry(
          id: id ?? 'slot-$title:$day',
          parentId: 'slot-$title',
          source: CalendarSource.timetable,
          type: CalendarEntryType.lesson,
          title: title,
          start: DateTime(2026, 8, day, hour),
          end: DateTime(2026, 8, day, hour + 1),
        );

    test('keeps only classes that start today, in time order', () {
      final sessions = todaySessions([
        lesson(hour: 14, title: 'Maths'),
        _entry(
          start: DateTime(2026, 8, 17, 9),
          type: CalendarEntryType.meeting,
          title: 'Mentor sync',
        ),
        lesson(hour: 9, title: 'Physics'),
        lesson(hour: 9, title: 'Yesterday', day: 16),
      ], today);

      expect(sessions.map((s) => s.title), ['Physics', 'Maths']);
    });

    test('de-duplicates an occurrence the server expanded twice', () {
      final sessions = todaySessions([
        lesson(hour: 9, title: 'Physics', id: 'slot-1:2026-08-17'),
        lesson(hour: 9, title: 'Physics', id: 'slot-1:2026-08-17'),
      ], today);

      expect(sessions, hasLength(1));
    });

    test('phases split on the start and end instants', () {
      final session = lesson(hour: 10);

      expect(phaseOf(session, DateTime(2026, 8, 17, 9, 59)),
          SessionPhase.upcoming);
      // The start instant is already live, and the end instant is already done.
      expect(phaseOf(session, DateTime(2026, 8, 17, 10)), SessionPhase.live);
      expect(phaseOf(session, DateTime(2026, 8, 17, 10, 30)), SessionPhase.live);
      expect(phaseOf(session, DateTime(2026, 8, 17, 11)), SessionPhase.done);
    });
  });
}
