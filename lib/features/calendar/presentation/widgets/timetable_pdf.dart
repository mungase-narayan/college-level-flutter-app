import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/calendar_entry.dart';

/// The web's fallback accent when a class carries no colour of its own.
const _defaultColor = PdfColor.fromInt(0xFF6E41DB);

/// One period: a start/end pair and what sits in it on each weekday.
class TimetableSlot {
  TimetableSlot(this.label, this.startMinutes);

  final String label;
  final int startMinutes;
  final Map<int, CalendarEntry> byWeekday = {};
}

/// Groups a week's classes into printable rows — one per distinct period,
/// ordered by start time.
///
/// Events, meetings and tasks are dropped (this is a *class* timetable), as is
/// anything on a weekend: the printed grid is five columns wide, matching the
/// web.
List<TimetableSlot> timetableSlots(List<CalendarEntry> entries) {
  final slots = <String, TimetableSlot>{};

  for (final entry in entries) {
    if (!entry.isClass && entry.type != CalendarEntryType.lesson) continue;
    if (entry.start.weekday > DateTime.friday) continue;

    final label = '${DateFormat('h:mm a').format(entry.start)} – '
        '${DateFormat('h:mm a').format(entry.end)}';
    final slot = slots.putIfAbsent(
      label,
      () => TimetableSlot(label, entry.start.hour * 60 + entry.start.minute),
    );
    slot.byWeekday[entry.start.weekday] = entry;
  }

  return slots.values.toList()
    ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
}

/// Builds the student's weekly class timetable as a printable document —
/// the port of `downloadWeekTimetablePdf` in
/// `src/components/calendar/timetable-pdf.ts`.
///
/// The web opens an HTML window and calls `window.print()`, which has no
/// meaning on a phone; here the same document goes to the system print/share
/// sheet, where it can be saved to Files or AirPrinted.
///
/// Returns false when the week holds no classes, so the caller can say so
/// instead of handing over an empty sheet.
Future<bool> shareWeekTimetablePdf({
  required List<CalendarEntry> entries,
  required List<DateTime> weekDays,
  required String schoolName,
  required String personName,
}) async {
  // Monday–Friday only, matching the web. A Saturday class is rare enough that
  // the printed grid is better off staying five columns wide.
  final days = weekDays.take(5).toList(growable: false);
  final ordered = timetableSlots(entries);
  if (ordered.isEmpty) return false;

  final document = pw.Document(title: 'Weekly Timetable');
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4.landscape.copyWith(
        marginLeft: 12 * PdfPageFormat.mm,
        marginTop: 12 * PdfPageFormat.mm,
        marginRight: 12 * PdfPageFormat.mm,
        marginBottom: 12 * PdfPageFormat.mm,
      ),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    schoolName,
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Weekly Class Timetable',
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    personName.isEmpty ? '—' : personName,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Mon – Fri',
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.1),
              for (var i = 1; i <= days.length; i++)
                i: const pw.FlexColumnWidth(1.6),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                children: [
                  _headerCell('Time'),
                  for (final day in days)
                    _headerCell(DateFormat('EEEE').format(day)),
                ],
              ),
              for (final slot in ordered)
                pw.TableRow(
                  children: [
                    _timeCell(slot.label),
                    for (final day in days) _entryCell(slot.byWeekday[day.weekday]),
                  ],
                ),
            ],
          ),
          pw.Spacer(),
          pw.Text(
            'Generated from the Student Portal',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) => document.save(),
    name: 'Weekly Timetable',
  );
  return true;
}

pw.Widget _headerCell(String text) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );

pw.Widget _timeCell(String label) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
    );

pw.Widget _entryCell(CalendarEntry? entry) {
  if (entry == null) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.SizedBox(height: 22),
    );
  }

  final accent = _pdfColor(entry.accentHex);
  final meta = [entry.room?.code, entry.teacher?.name]
      .where((part) => part != null && part.isNotEmpty)
      .join(' · ');

  return pw.Padding(
    padding: const pw.EdgeInsets.all(4),
    child: pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(6, 4, 4, 4),
      decoration: pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: accent, width: 3)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            entry.title,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
          if (meta.isNotEmpty)
            pw.Text(
              meta,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
        ],
      ),
    ),
  );
}

PdfColor _pdfColor(String hex) {
  final value = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
  return value == null ? _defaultColor : PdfColor.fromInt(0xFF000000 | value);
}
