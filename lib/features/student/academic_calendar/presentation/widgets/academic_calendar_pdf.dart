import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/academic_calendar.dart';

const _bannerFrom = PdfColor.fromInt(0xFF6366F1);
const _bannerMuted = PdfColor.fromInt(0xFFD9D4FB);
const _ink = PdfColor.fromInt(0xFF11161F);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _rule = PdfColor.fromInt(0xFFE5E7EB);
const _stripe = PdfColor.fromInt(0xFFF9FAFB);

PdfColor _pdf(String type, String? colorCode) =>
    PdfColor.fromInt(AcademicCalendarMeta.pdfColor(type, colorCode).toARGB32());

/// A pale version of [base], mixed toward white up front.
///
/// The obvious spelling — a `PdfColor` with a low alpha — does not work: the
/// renderer paints it at full strength, which turned every type pill into a
/// solid block with its own label invisible inside it. Blending here means the
/// colour that reaches the page is already the one intended.
PdfColor _tint(PdfColor base, [double amount = 0.16]) => PdfColor(
      1 - amount * (1 - base.red),
      1 - amount * (1 - base.green),
      1 - amount * (1 - base.blue),
    );

String _plural(int count) => count == 1 ? '1 entry' : '$count entries';

/// Rewrites the typographic characters the printed sheet cannot draw.
///
/// The built-in Helvetica has no Unicode support: it warns and leaves a gap for
/// both the en dash in a date range (U+2013) and the bullet separating the scope
/// parts (U+2022), and the app bundles no font asset to fall back to. On screen
/// both render fine — only the PDF is rewritten.
String _printable(String text) =>
    text.replaceAll('–', '-').replaceAll('•', '-');

/// Builds the printable academic calendar, or null when there is nothing to
/// print.
///
/// Split from [shareAcademicCalendarPdf] so the document can be built and
/// inspected in a test — `save()` needs no platform channel, while the print
/// sheet does.
///
/// [now] is injectable for the same reason: the footer stamps a generation time,
/// and a test cannot assert against `DateTime.now()`.
pw.Document? buildAcademicCalendarDocument({
  required AcademicCalendar calendar,
  required String schoolName,
  DateTime? now,
}) {
  if (!calendar.hasEntries) return null;

  final months = calendar.months;
  final total = calendar.entries.length;
  final generated = now ?? DateTime.now();

  final document = pw.Document(
    title: 'Academic Calendar — ${calendar.displayTitle}',
  );

  document.addPage(
    // MultiPage, not Page: a term runs to dozens of entries across several
    // months and will not fit one sheet the way a Mon–Fri timetable does.
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(
        marginLeft: 12 * PdfPageFormat.mm,
        marginTop: 12 * PdfPageFormat.mm,
        marginRight: 12 * PdfPageFormat.mm,
        marginBottom: 12 * PdfPageFormat.mm,
      ),
      build: (context) => [
        _banner(calendar: calendar, schoolName: schoolName),
        pw.SizedBox(height: 16),
        for (final month in months) ...[
          _monthBar(month),
          _entriesTable(month),
          pw.SizedBox(height: 14),
        ],
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '$total total ${total == 1 ? 'entry' : 'entries'}',
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
            pw.Text(
              'Generated ${DateFormat('d MMM yyyy, h:mm a').format(generated)}',
              style: const pw.TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
      ],
    ),
  );

  return document;
}

pw.Widget _banner({
  required AcademicCalendar calendar,
  required String schoolName,
}) {
  final scope = calendar.scope;
  final termRange = calendar.termRange;

  // A single column with an explicit width. An earlier Row/Expanded version
  // sized unboundedly inside `MultiPage` and painted its fill across the whole
  // sheet, taking the title with it.
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(16),
    // Solid, not a gradient: `pw.LinearGradient` does not paint here, which
    // left the banner's white text on white paper.
    decoration: const pw.BoxDecoration(
      color: _bannerFrom,
      borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          'ACADEMIC CALENDAR',
          style: const pw.TextStyle(
            fontSize: 8,
            color: _bannerMuted,
            letterSpacing: 1.2,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          calendar.displayTitle,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
        if (scope.isNotEmpty) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            _printable(scope),
            style: const pw.TextStyle(fontSize: 10, color: _bannerMuted),
          ),
        ],
        if (termRange != null) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            _printable('Term: $termRange'),
            style: const pw.TextStyle(fontSize: 10, color: _bannerMuted),
          ),
        ],
        pw.SizedBox(height: 10),
        pw.Text(
          schoolName,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
          ),
        ),
      ],
    ),
  );
}

pw.Widget _monthBar(AcademicCalendarMonth month) => pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: const pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF3F4F6),
        borderRadius: pw.BorderRadius.only(
          topLeft: pw.Radius.circular(8),
          topRight: pw.Radius.circular(8),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            month.label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
              letterSpacing: 0.6,
            ),
          ),
          pw.Text(
            _plural(month.entries.length),
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ],
      ),
    );

pw.Widget _entriesTable(AcademicCalendarMonth month) => pw.Table(
      border: pw.TableBorder.all(color: _rule, width: 0.5),
      columnWidths: const {
        0: pw.FixedColumnWidth(110),
        1: pw.FixedColumnWidth(92),
        2: pw.FlexColumnWidth(),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFEEF0F3),
          ),
          children: [
            _headerCell('Date'),
            _headerCell('Type'),
            _headerCell('Title'),
          ],
        ),
        for (final (index, entry) in month.entries.indexed)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: index.isOdd ? _stripe : PdfColors.white,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(7),
                child: pw.Text(
                  _printable(entry.dateRange),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(7),
                // Aligned, or the pill stretches to fill the cell and reads as
                // a coloured band rather than a chip.
                // Wrap, not Align: a table cell hands down tight constraints,
                // and the pill would otherwise stretch into a coloured band.
                child: pw.Wrap(children: [_typePill(entry)]),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(7),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      entry.title,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    if (entry.description case final description?) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        description,
                        style: const pw.TextStyle(fontSize: 8.5, color: _muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
      ],
    );

pw.Widget _headerCell(String label) => pw.Padding(
      padding: const pw.EdgeInsets.all(7),
      child: pw.Text(
        label.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: _muted,
          letterSpacing: 0.6,
        ),
      ),
    );

pw.Widget _typePill(AcademicCalendarEntry entry) {
  // The entry's own colour wins over the type's — the only place `colorCode` is
  // read anywhere in the feature, matching the web.
  final color = _pdf(entry.type, entry.colorCode);

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: pw.BoxDecoration(
      color: _tint(color),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(999)),
    ),
    child: pw.Text(
      AcademicCalendarMeta.typeLabel(entry.type),
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: color,
      ),
    ),
  );
}

/// Hands the calendar to the system print/share sheet.
///
/// Returns false when there is nothing to print, so the caller can say so
/// instead of offering an empty sheet — the same contract
/// `shareWeekTimetablePdf` uses.
///
/// The web's success and popup-blocked toasts have no counterpart here: a
/// toast would sit under the system sheet, and nothing blocks it.
Future<bool> shareAcademicCalendarPdf({
  required AcademicCalendar calendar,
  required String schoolName,
}) async {
  final document = buildAcademicCalendarDocument(
    calendar: calendar,
    schoolName: schoolName,
  );
  if (document == null) return false;

  await Printing.layoutPdf(
    onLayout: (_) => document.save(),
    name: 'Academic Calendar',
  );
  return true;
}
