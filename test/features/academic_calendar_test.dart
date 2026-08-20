import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/config/theme/app_colors.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/student/academic_calendar/data/models/academic_calendar_model.dart';
import 'package:college_level/features/student/academic_calendar/domain/entities/academic_calendar.dart';
import 'package:college_level/features/student/academic_calendar/domain/usecases/academic_calendar_usecases.dart';
import 'package:college_level/features/student/academic_calendar/presentation/bloc/academic_calendar_cubit.dart';
import 'package:college_level/features/student/academic_calendar/presentation/widgets/academic_calendar_pdf.dart';

class _MockGetCalendar extends Mock implements GetMyAcademicCalendarUseCase {}

AcademicCalendarEntry _entry({
  String id = 'e1',
  String type = 'event',
  String title = 'Independence Day',
  String startDate = '2025-08-12',
  String? endDate,
  String? description,
}) =>
    AcademicCalendarEntry(
      id: id,
      type: type,
      title: title,
      startDate: startDate,
      endDate: endDate,
      description: description,
    );

void main() {
  setUpAll(() => registerFallbackValue(const NoParams()));

  group('formatEntryRange', () {
    test('a single day', () {
      expect(formatEntryRange('2025-08-12', null), '12 Aug 2025');
    });

    test('an end equal to the start collapses to one day', () {
      expect(formatEntryRange('2025-08-12', '2025-08-12'), '12 Aug 2025');
    });

    /// The web closes up a same-month span and breathes across months. The two
    /// dashes are different characters' worth of spacing, which is the kind of
    /// detail an eyeball review will not catch.
    test('a same-month span uses an unspaced en dash', () {
      final range = formatEntryRange('2025-08-12', '2025-08-16');

      expect(range, '12–16 Aug 2025');
      expect(range, contains('–'));
      expect(range, isNot(contains(' – ')));
    });

    test('a cross-month span in one year spaces the dash', () {
      expect(formatEntryRange('2025-08-28', '2025-09-02'), '28 Aug – 2 Sep 2025');
    });

    test('a cross-year span carries both years', () {
      expect(
        formatEntryRange('2025-12-28', '2026-01-02'),
        '28 Dec 2025 – 2 Jan 2026',
      );
    });

    /// The guard against reaching for `Fmt.dmyLong`, which pads to `02 Sep`.
    test('the day is not zero-padded', () {
      expect(formatEntryRange('2025-09-02', null), '2 Sep 2025');
    });

    /// Sliced, never parsed — these are bare `date` columns, and parsing one
    /// with a Z suffix would render the previous day west of UTC.
    test('a timestamp suffix does not shift the date', () {
      expect(formatEntryRange('2025-08-12T00:00:00.000Z', null), '12 Aug 2025');
    });

    test('a reversed range is rendered as given, not swapped', () {
      expect(formatEntryRange('2025-08-16', '2025-08-12'), '16–12 Aug 2025');
    });

    test('unusable input degrades to an em dash', () {
      expect(formatEntryRange('', null), '—');
      expect(formatEntryRange('2025', null), '—');
      expect(formatEntryRange('2025-13-40', null), '—');
    });
  });

  group('groupEntriesByMonth', () {
    /// Insertion order, not sorted: the server returns entries by startDate,
    /// and re-sorting here would diverge the moment two share a date. Feeding
    /// September before August is what proves no sort slipped in.
    test('keeps the order the entries arrived in', () {
      final groups = groupEntriesByMonth([
        _entry(id: 'a', startDate: '2025-09-03'),
        _entry(id: 'b', startDate: '2025-08-12'),
        _entry(id: 'c', startDate: '2025-09-20'),
      ]);

      expect(
        groups.map((group) => group.label),
        ['September 2025', 'August 2025'],
      );
      expect(groups.first.entries.map((e) => e.id), ['a', 'c']);
      expect(groups.last.entries.single.id, 'b');
    });

    test('one month yields one group', () {
      final groups = groupEntriesByMonth([
        _entry(id: 'a', startDate: '2025-08-01'),
        _entry(id: 'b', startDate: '2025-08-30'),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.entries, hasLength(2));
    });

    test('no entries yields no groups', () {
      expect(groupEntriesByMonth(const []), isEmpty);
    });

    test('an unreadable date buckets rather than throwing', () {
      final groups = groupEntriesByMonth([_entry(startDate: 'not-a-date')]);

      expect(groups.single.label, '—');
    });

    /// The entity holds the label title case; the widget uppercases it.
    test('the label is title case', () {
      expect(
        groupEntriesByMonth([_entry(startDate: '2025-08-12')]).single.label,
        'August 2025',
      );
    });
  });

  group('formatScope', () {
    test('joins all three parts', () {
      expect(
        formatScope(
          departmentName: 'CSE',
          batchName: 'Batch 2024',
          semesterCode: 5,
        ),
        'CSE • Batch 2024 • Semester 5',
      );
    });

    /// Zero is a legal semester code, so it must not be treated as absent.
    test('semester zero still renders', () {
      expect(formatScope(semesterCode: 0), 'Semester 0');
    });

    test('a null semester is dropped', () {
      expect(formatScope(departmentName: 'CSE'), 'CSE');
    });

    /// JS drops `''` as well as null; without that a blank department opens
    /// the line with a stray separator.
    test('a blank part is dropped, leaving no stray separator', () {
      expect(formatScope(departmentName: '', batchName: 'Batch 2024'),
          'Batch 2024');
    });

    test('nothing known yields an empty string', () {
      expect(formatScope(), '');
    });
  });

  group('AcademicCalendarModel', () {
    /// The endpoint answers 200 with `data: null` when nothing is published.
    test('a null payload parses to null, not an empty calendar', () {
      expect(AcademicCalendarModel.fromJsonOrNull(null), isNull);
      expect(AcademicCalendarModel.fromJsonOrNull('nonsense'), isNull);
    });

    test('a full payload parses, entries included', () {
      final calendar = AcademicCalendarModel.fromJsonOrNull(const {
        'id': 'c1',
        'title': 'Odd Semester 2025-26',
        'description': 'Term plan',
        'startDate': '2025-07-01',
        'endDate': '2025-11-30',
        'batchName': 'Batch 2024',
        'departmentName': 'CSE',
        'semesterCode': 5,
        'entries': [
          {
            'id': 'e1',
            'type': 'pl',
            'title': 'Preparation leave',
            'startDate': '2025-08-12',
            'endDate': '2025-08-16',
            'colorCode': '#ff0000',
          },
        ],
      })!;

      expect(calendar.title, 'Odd Semester 2025-26');
      expect(calendar.scope, 'CSE • Batch 2024 • Semester 5');
      expect(calendar.termRange, '1 Jul – 30 Nov 2025');
      expect(calendar.entries.single.dateRange, '12–16 Aug 2025');
      expect(calendar.entries.single.colorCode, '#ff0000');
    });

    test('a bare payload parses with no entries', () {
      final calendar = AcademicCalendarModel.fromJsonOrNull(const {})!;

      expect(calendar.entries, isEmpty);
      expect(calendar.hasEntries, isFalse);
      expect(calendar.semesterCode, isNull);
      expect(calendar.termRange, isNull);
    });

    test('an empty description reads as absent', () {
      final calendar =
          AcademicCalendarModel.fromJsonOrNull(const {'description': ''})!;

      expect(calendar.description, isNull);
    });

    /// The student projection omits these even though the web's type declares
    /// them required, so nothing may read them.
    test('a payload without timestamps parses', () {
      expect(
        AcademicCalendarModel.fromJsonOrNull(const {'id': 'c1'}),
        isNotNull,
      );
    });

    test('a term needs both ends to render', () {
      final startOnly =
          AcademicCalendarModel.fromJsonOrNull(const {'startDate': '2025-07-01'})!;

      expect(startOnly.termRange, isNull);
    });

    test('a blank title falls back for the heading', () {
      expect(
        AcademicCalendarModel.fromJsonOrNull(const {'title': ''})!.displayTitle,
        'Academic calendar',
      );
    });
  });

  group('AcademicCalendarMeta', () {
    test('carries the four types in the web order', () {
      expect(AcademicCalendarMeta.entryTypes,
          ['event', 'holiday', 'exam', 'pl']);
    });

    test('labels the long and short forms', () {
      expect(AcademicCalendarMeta.typeLabel('pl'), 'Preparation Leave');
      expect(AcademicCalendarMeta.typeShortLabel('pl'), 'PL');
      expect(AcademicCalendarMeta.typeLabel('holiday'), 'Holiday');
    });

    /// Pins screen and print against a palette edit: `s400` is the web's dot
    /// colour, `s500` its PDF hex.
    test('the shades match the web exactly', () {
      expect(AcademicCalendarMeta.typeShade('event').s400.toARGB32(),
          0xFF818CF8);
      expect(AcademicCalendarMeta.typeShade('holiday').s400.toARGB32(),
          0xFF34D399);
      expect(AcademicCalendarMeta.typeShade('exam').s400.toARGB32(), 0xFFFB7185);
      expect(AcademicCalendarMeta.typeShade('pl').s400.toARGB32(), 0xFFFBBF24);

      expect(AcademicCalendarMeta.typeShade('event').s500.toARGB32(),
          0xFF6366F1);
      expect(AcademicCalendarMeta.typeShade('holiday').s500.toARGB32(),
          0xFF10B981);
      expect(AcademicCalendarMeta.typeShade('exam').s500.toARGB32(), 0xFFF43F5E);
      expect(AcademicCalendarMeta.typeShade('pl').s500.toARGB32(), 0xFFF59E0B);
    });

    test('an unknown type degrades instead of throwing', () {
      expect(AcademicCalendarMeta.typeLabel('convocation'), 'convocation');
      expect(AcademicCalendarMeta.typeShade('convocation'), TwColors.slate);
    });

    test('an entry colour overrides the type colour, but only when valid', () {
      expect(
        AcademicCalendarMeta.pdfColor('exam', '#123456').toARGB32(),
        0xFF123456,
      );
      expect(
        AcademicCalendarMeta.pdfColor('exam', 'nonsense').toARGB32(),
        0xFFF43F5E,
      );
    });
  });

  group('AcademicCalendarCubit', () {
    late _MockGetCalendar getCalendar;
    late AcademicCalendarCubit cubit;

    AcademicCalendar calendar({List<AcademicCalendarEntry> entries = const []}) =>
        AcademicCalendar(id: 'c1', title: 'Odd Semester', entries: entries);

    setUp(() {
      getCalendar = _MockGetCalendar();
      cubit = AcademicCalendarCubit(getMyCalendar: getCalendar);
    });

    tearDown(() => cubit.close());

    /// The distinction the whole screen rests on: "nothing published" is a
    /// successful answer, not a failure and not an empty list.
    test('a null calendar is a success, not a failure', () async {
      when(() => getCalendar(any()))
          .thenAnswer((_) async => const Right<Failure, AcademicCalendar?>(null));

      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data, isNull);
      expect(cubit.state.failure, isNull);
    });

    test('a calendar arrives as data', () async {
      when(() => getCalendar(any())).thenAnswer(
        (_) async => Right<Failure, AcademicCalendar?>(calendar()),
      );

      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data!.title, 'Odd Semester');
    });

    test('a transport error is a failure', () async {
      when(() => getCalendar(any())).thenAnswer(
        (_) async =>
            const Left<Failure, AcademicCalendar?>(NetworkFailure('offline')),
      );

      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      expect(cubit.state.failure, isNotNull);
      expect(cubit.state.data, isNull);
    });

    /// `load` re-emits rather than merging, so a calendar that was unpublished
    /// between refreshes actually disappears.
    test('a refresh returning null clears the previous calendar', () async {
      when(() => getCalendar(any())).thenAnswer(
        (_) async => Right<Failure, AcademicCalendar?>(calendar()),
      );
      await cubit.load();
      expect(cubit.state.data, isNotNull);

      when(() => getCalendar(any()))
          .thenAnswer((_) async => const Right<Failure, AcademicCalendar?>(null));
      await cubit.load(refresh: true);

      expect(cubit.state.data, isNull);
      expect(cubit.state.status, RemoteStatus.success);
    });
  });

  group('academic calendar PDF', () {
    AcademicCalendar calendar({List<AcademicCalendarEntry> entries = const []}) =>
        AcademicCalendar(
          id: 'c1',
          title: 'Odd Semester 2025-26',
          startDate: '2025-07-01',
          endDate: '2025-11-30',
          departmentName: 'CSE',
          batchName: 'Batch 2024',
          semesterCode: 5,
          entries: entries,
        );

    test('there is nothing to print without entries', () {
      expect(
        buildAcademicCalendarDocument(
          calendar: calendar(),
          schoolName: 'MIT',
        ),
        isNull,
      );
    });

    test('a calendar with entries produces a document', () async {
      final document = buildAcademicCalendarDocument(
        calendar: calendar(
          entries: [
            _entry(description: 'National holiday'),
            _entry(id: 'e2', type: 'pl', startDate: '2025-09-01'),
          ],
        ),
        schoolName: 'MIT',
        now: DateTime(2026, 8, 17, 15, 4),
      );

      expect(document, isNotNull);
      // `save()` needs no platform channel, unlike the print sheet.
      expect(await document!.save(), isNotEmpty);
    });
  });

  group('endpoint', () {
    test('points at the student academic calendar', () {
      expect(ApiUrls.studentAcademicCalendar, '/student/academic-calendar');
    });
  });
}
