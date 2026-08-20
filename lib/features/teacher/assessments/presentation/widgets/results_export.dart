import 'dart:convert';
import 'dart:typed_data';

import 'package:printing/printing.dart';

import '../../../../../core/utils/formatters.dart';
import '../../domain/entities/submission.dart';

/// The web's CSV column set, kept verbatim so a teacher's existing sheet
/// keeps working.
const csvColumns = [
  'rank',
  'roll_number',
  'student_name',
  'status',
  'score',
  'total_marks',
  'percentage',
  'time_taken',
  'submitted_at',
];

/// Ranks the attempted rows, ties sharing a place, and leaves non-attempters
/// unranked.
///
/// The sheet arrives best-first, so a row ties with the one before it when
/// both the score and the time match.
List<int?> rankResults(List<ResultRow> rows) {
  final ranks = <int?>[];
  int rank = 0;
  int attemptedSeen = 0;
  ({int score, int time})? previous;

  for (final row in rows) {
    if (!row.attempted) {
      ranks.add(null);
      continue;
    }
    final tied = previous != null &&
        previous.score == row.totalScore &&
        previous.time == row.timeSpentSeconds;
    if (!tied) rank = attemptedSeen + 1;
    previous = (score: row.totalScore, time: row.timeSpentSeconds);
    attemptedSeen += 1;
    ranks.add(rank);
  }
  return ranks;
}

/// Everything a non-attempter would contribute is left blank rather than
/// zeroed, so an average taken in a spreadsheet stays honest.
List<String> csvRowFor(ResultRow row, int? rank) {
  final max = row.maxScore ?? 0;
  return [
    rank?.toString() ?? '',
    row.rollNumber ?? '',
    row.fullName,
    AssignmentOutcome.label(row.outcome),
    row.attempted ? '${row.totalScore}' : '',
    '$max',
    row.attempted && max > 0
        ? '${(row.totalScore / max * 100).round()}%'
        : '',
    row.attempted ? Fmt.duration(row.timeSpentSeconds) : '',
    row.submittedAt == null ? '' : Fmt.dateTime(row.submittedAt),
  ];
}

/// Quotes every field, doubling any quote inside — the same shape Papa Parse
/// emits on the web with `quotes: true`.
String buildResultsCsv(ResultSheet sheet) {
  final ranks = rankResults(sheet.rows);
  final lines = <String>[
    csvColumns.map(_quote).join(','),
    for (var i = 0; i < sheet.rows.length; i++)
      csvRowFor(sheet.rows[i], ranks[i]).map(_quote).join(','),
  ];
  return lines.join('\r\n');
}

String _quote(String value) => '"${value.replaceAll('"', '""')}"';

/// `Assessment Title` → `assessment-title-results.csv`.
String csvFileName(String title) {
  final slug = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return '${slug.isEmpty ? 'assessment' : slug}-results.csv';
}

/// Hands the sheet to the OS share sheet.
///
/// The web triggers a browser download, which a phone has no equivalent for.
/// `Printing.sharePdf` is misnamed — it writes the bytes to a temp file and
/// opens the share sheet with whatever name it is given, so no extra
/// dependency is needed for this.
Future<void> shareResultsCsv(ResultSheet sheet) => Printing.sharePdf(
      bytes: Uint8List.fromList(utf8.encode(buildResultsCsv(sheet))),
      filename: csvFileName(sheet.title),
    );
