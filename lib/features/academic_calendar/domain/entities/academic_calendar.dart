import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/theme/app_colors.dart';

const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const _monthsLong = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// 1-based month from a `YYYY-MM-DD` string, or null when it cannot be read.
int? _month(String iso) {
  if (iso.length < 10) return null;
  final month = int.tryParse(iso.substring(5, 7));
  if (month == null || month < 1 || month > 12) return null;
  return month;
}

/// `2025-08-02` → `2`. Unpadded, matching the web's `format(d, 'd')`.
String _day(String iso) => int.parse(iso.substring(8, 10)).toString();

/// The date range shown against an entry, and against the calendar's own term.
///
/// Ported from the web's `formatEntryRange`. Every branch works on **substrings**
/// — `DateTime.parse` is never called — because `startDate` and `endDate` are
/// bare Postgres `date` columns. Parsing them would shift the day for anyone
/// west of UTC, which is the same reason `Fmt.dmy` slices.
///
/// Note the two different dashes, both from the web: a same-month span closes up
/// (`12–16 Aug 2025`) while a cross-month one breathes (`28 Aug – 2 Sep 2025`).
///
/// [Fmt.dmyLong] cannot stand in for this: it pads the day to two digits, and
/// this needs `2 Sep 2025`, not `02 Sep 2025`.
String formatEntryRange(String startDate, String? endDate) {
  final startMonth = _month(startDate);
  if (startMonth == null) return '—';

  final start = '${_day(startDate)} ${_monthsShort[startMonth - 1]} '
      '${startDate.substring(0, 4)}';

  if (endDate == null || endDate == startDate) return start;

  final endMonth = _month(endDate);
  if (endMonth == null) return start;

  final end = '${_day(endDate)} ${_monthsShort[endMonth - 1]} '
      '${endDate.substring(0, 4)}';

  // Same month and year: only the tail carries the month and year.
  if (startDate.substring(0, 7) == endDate.substring(0, 7)) {
    return '${_day(startDate)}–$end';
  }

  // Same year: the head drops the year but keeps its month.
  if (startDate.substring(0, 4) == endDate.substring(0, 4)) {
    return '${_day(startDate)} ${_monthsShort[startMonth - 1]} – $end';
  }

  return '$start – $end';
}

/// `CSE • Batch 2024 • Semester 5`.
///
/// Empty strings are dropped as well as nulls — the web's `.filter(Boolean)`
/// treats them the same, and a blank department would otherwise open the line
/// with a stray separator.
String formatScope({
  String? departmentName,
  String? batchName,
  int? semesterCode,
}) =>
    [
      departmentName,
      batchName,
      if (semesterCode != null) 'Semester $semesterCode',
    ]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(' • ');

/// Buckets entries under `August 2025` headings.
///
/// Insertion-ordered and deliberately **not** sorted: the server returns entries
/// by `startDate ASC, createdAt ASC`, and re-sorting here would quietly diverge
/// from that order the moment two entries share a date.
List<AcademicCalendarMonth> groupEntriesByMonth(
  List<AcademicCalendarEntry> entries,
) {
  final groups = <AcademicCalendarMonth>[];
  final indexOf = <String, int>{};
  final buckets = <List<AcademicCalendarEntry>>[];

  for (final entry in entries) {
    final month = _month(entry.startDate);
    // A row whose date cannot be read still has to appear somewhere.
    final label = month == null
        ? '—'
        : '${_monthsLong[month - 1]} ${entry.startDate.substring(0, 4)}';

    var index = indexOf[label];
    if (index == null) {
      index = groups.length;
      indexOf[label] = index;
      buckets.add([]);
      groups.add(AcademicCalendarMonth(label: label, entries: buckets[index]));
    }
    buckets[index].add(entry);
  }

  return groups;
}

/// `GET /student/academic-calendar` — the published calendar for the student's
/// current semester.
///
/// Carries only what the screen renders. The payload also has `schoolId`, the
/// three scope ids, `status` (always `published` on this projection), the
/// batch/department codes and `publishedAt`; none reach the UI. The student
/// projection additionally omits `createdAt`, `updatedAt` and `entryCount`
/// despite the web's type declaring them required, so nothing reads them.
class AcademicCalendar extends Equatable {
  const AcademicCalendar({
    required this.id,
    required this.title,
    this.description,
    this.startDate,
    this.endDate,
    this.batchName,
    this.departmentName,
    this.semesterCode,
    this.entries = const [],
  });

  final String id;
  final String title;
  final String? description;

  /// The term span. Both are nullable, and the schema defaults them from the
  /// semester rather than requiring them.
  final String? startDate;
  final String? endDate;

  final String? batchName;
  final String? departmentName;
  final int? semesterCode;

  final List<AcademicCalendarEntry> entries;

  String get scope => formatScope(
        departmentName: departmentName,
        batchName: batchName,
        semesterCode: semesterCode,
      );

  /// Null unless **both** ends are known — the web hides the whole `Term:` line
  /// for a calendar that only has a start.
  String? get termRange {
    final start = startDate;
    final end = endDate;
    if (start == null || end == null) return null;
    return formatEntryRange(start, end);
  }

  /// The heading falls back rather than rendering blank: on a phone this is the
  /// only thing naming the card. The web leaves its `<h2>` empty.
  String get displayTitle => title.isEmpty ? 'Academic calendar' : title;

  bool get hasEntries => entries.isNotEmpty;

  List<AcademicCalendarMonth> get months => groupEntriesByMonth(entries);

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        startDate,
        endDate,
        batchName,
        departmentName,
        semesterCode,
        entries,
      ];
}

/// One dated item inside a calendar.
class AcademicCalendarEntry extends Equatable {
  const AcademicCalendarEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.startDate,
    this.description,
    this.endDate,
    this.colorCode,
  });

  final String id;

  /// One of [AcademicCalendarMeta.entryTypes] — treated as open, since an enum
  /// added server-side must render rather than throw.
  final String type;

  final String title;
  final String? description;

  /// `YYYY-MM-DD`. Null [endDate] means a single day.
  final String startDate;
  final String? endDate;

  /// Used **only** by the PDF export. The on-screen badge takes its colour from
  /// [type] alone, exactly as the web does.
  final String? colorCode;

  String get dateRange => formatEntryRange(startDate, endDate);

  @override
  List<Object?> get props =>
      [id, type, title, description, startDate, endDate, colorCode];
}

/// Entries sharing a month heading.
class AcademicCalendarMonth extends Equatable {
  const AcademicCalendarMonth({required this.label, required this.entries});

  /// Title case (`August 2025`) — the widget uppercases it, the way the web
  /// keeps the value in JS and the transform in CSS.
  final String label;

  final List<AcademicCalendarEntry> entries;

  @override
  List<Object?> get props => [label, entries];
}

/// Labels and tints for the four entry types.
class AcademicCalendarMeta {
  const AcademicCalendarMeta._();

  /// In the web's declaration order.
  static const entryTypes = ['event', 'holiday', 'exam', 'pl'];

  static String typeLabel(String type) => switch (type) {
        'event' => 'Event',
        'holiday' => 'Holiday',
        'exam' => 'Exam',
        'pl' => 'Preparation Leave',
        _ => type,
      };

  /// The compact form the web uses in legends.
  static String typeShortLabel(String type) => switch (type) {
        'pl' => 'PL',
        _ => typeLabel(type),
      };

  /// These map onto Tailwind exactly: each shade's `s400` is the web's dot
  /// colour and its `s500` is the web's PDF hex, so the screen and the printed
  /// sheet cannot drift apart.
  static TwShade typeShade(String type) => switch (type) {
        'event' => TwColors.indigo,
        'holiday' => TwColors.emerald,
        'exam' => TwColors.rose,
        'pl' => TwColors.amber,
        _ => TwColors.slate,
      };

  /// The colour the PDF prints an entry in — the entry's own override first.
  static Color pdfColor(String type, String? colorCode) =>
      parseHexColor(colorCode) ?? typeShade(type).s500;
}
