/// Splits a markdown document into the pieces that need different renderers.
///
/// The web app dispatches rich blocks from inside its markdown pipeline
/// (`renderBlock` in `src/components/shared/markdown.tsx`). `flutter_markdown`
/// has no equivalent seam for a fenced block, so the split happens one level
/// earlier — on the source itself — and the caller renders a column of
/// alternating prose and block widgets.
///
/// The scanner is deliberately conservative: anything it does not positively
/// recognise stays in the prose buffer verbatim, so a malformed block shows the
/// author their own source instead of a gap. That is the same guarantee
/// `renderBlock` gives by returning null.
library;

import 'block_definitions.dart';

enum MarkdownSegmentKind {
  /// Plain markdown, handed to `MarkdownBody` untouched.
  prose,

  /// A recognised rich block. [MarkdownSegment.language] is its key and
  /// [MarkdownSegment.text] its raw body (JSON for all keys but `mermaid`).
  block,

  /// Display math from a `$$ … $$` run.
  math,

  /// A raw-HTML `<details>` element, lifted out because the markdown renderer
  /// drops HTML entirely.
  details,
}

class MarkdownSegment {
  const MarkdownSegment.prose(this.text)
      : kind = MarkdownSegmentKind.prose,
        language = null,
        title = null,
        open = false;

  const MarkdownSegment.block(this.language, this.text)
      : kind = MarkdownSegmentKind.block,
        title = null,
        open = false;

  const MarkdownSegment.math(this.text)
      : kind = MarkdownSegmentKind.math,
        language = null,
        title = null,
        open = false;

  const MarkdownSegment.details({
    required this.title,
    required this.text,
    required this.open,
  })  : kind = MarkdownSegmentKind.details,
        language = null;

  final MarkdownSegmentKind kind;

  /// Block key for [MarkdownSegmentKind.block], null otherwise.
  final String? language;

  /// Prose source, block body, TeX, or the `<details>` body.
  final String text;

  /// The `<summary>` text of a [MarkdownSegmentKind.details] segment.
  final String? title;

  /// Whether a `<details>` element carried the `open` attribute.
  final bool open;

  @override
  String toString() => 'MarkdownSegment(${kind.name}'
      '${language != null ? ', $language' : ''})';
}

/// Opens a fence: up to three spaces of indent, then three or more backticks
/// or tildes, then an optional info string.
final _fenceOpen = RegExp(r'^( {0,3})(`{3,}|~{3,})\s*(.*)$');

/// `<details>` / `</details>` and `<summary>…</summary>`, matched loosely
/// because the sanitizer on the web only ever emits the simple forms.
final _detailsOpen = RegExp(r'^\s*<details(\s[^>]*)?>\s*$', caseSensitive: false);
final _detailsClose = RegExp(r'^\s*</details>\s*$', caseSensitive: false);
final _summaryLine =
    RegExp(r'^\s*<summary(?:\s[^>]*)?>(.*?)</summary>\s*$', caseSensitive: false);

/// A `$$…$$` display-math run written on one line.
final _mathInline = RegExp(r'^\s*\$\$(.+)\$\$\s*$');
final _mathFence = RegExp(r'^\s*\$\$\s*$');

/// Splits [source] into renderable segments.
///
/// Only a fence whose language is one of [kBlockKeys] becomes a block segment;
/// every other fence — including ordinary ```dart code — is left inside the
/// prose so the markdown renderer still sees a well-formed document.
List<MarkdownSegment> parseMarkdownSegments(String source) {
  final text = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (text.trim().isEmpty) return const [];

  final lines = text.split('\n');
  final segments = <MarkdownSegment>[];
  final prose = <String>[];

  void flushProse() {
    if (prose.isEmpty) return;
    final body = prose.join('\n');
    prose.clear();
    if (body.trim().isNotEmpty) segments.add(MarkdownSegment.prose(body));
  }

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];

    final fence = _fenceOpen.firstMatch(line);
    if (fence != null) {
      final indent = fence.group(1)!.length;
      final marker = fence.group(2)!;
      final info = fence.group(3)!.trim();
      // A backtick fence's info string may not contain a backtick — that would
      // be an inline code span, not a fence.
      final validInfo = marker.startsWith('~') || !info.contains('`');
      final language = info.split(RegExp(r'\s+')).first.toLowerCase();

      final close = _findFenceClose(lines, i + 1, marker);

      if (validInfo && close != null && isBlockKey(language)) {
        flushProse();
        segments.add(
          MarkdownSegment.block(
            language,
            _dedent(lines.sublist(i + 1, close), indent).join('\n'),
          ),
        );
        i = close + 1;
        continue;
      }

      // Not a block — copy the whole fence across untouched so the markdown
      // renderer sees it intact, and so nothing inside it is scanned for math
      // or HTML.
      final end = close ?? lines.length - 1;
      for (var j = i; j <= end; j++) {
        prose.add(lines[j]);
      }
      i = end + 1;
      continue;
    }

    if (_detailsOpen.hasMatch(line)) {
      final close = _findLine(lines, i + 1, _detailsClose);
      if (close != null) {
        flushProse();
        segments.add(_readDetails(lines, i, close));
        i = close + 1;
        continue;
      }
    }

    final oneLineMath = _mathInline.firstMatch(line);
    if (oneLineMath != null) {
      flushProse();
      segments.add(MarkdownSegment.math(oneLineMath.group(1)!.trim()));
      i += 1;
      continue;
    }

    if (_mathFence.hasMatch(line)) {
      final close = _findLine(lines, i + 1, _mathFence);
      if (close != null) {
        flushProse();
        segments.add(
          MarkdownSegment.math(lines.sublist(i + 1, close).join('\n').trim()),
        );
        i = close + 1;
        continue;
      }
    }

    prose.add(line);
    i += 1;
  }

  flushProse();
  return segments;
}

/// The index of the line closing a fence opened with [marker], or null when the
/// document ends first.
int? _findFenceClose(List<String> lines, int from, String marker) {
  final char = marker[0];
  final closing = RegExp('^ {0,3}\\$char{${marker.length},}\\s*\$');
  for (var i = from; i < lines.length; i++) {
    if (closing.hasMatch(lines[i])) return i;
  }
  return null;
}

int? _findLine(List<String> lines, int from, RegExp pattern) {
  for (var i = from; i < lines.length; i++) {
    if (pattern.hasMatch(lines[i])) return i;
  }
  return null;
}

/// Removes up to [indent] leading spaces from each line, matching how a fenced
/// block's body is de-indented by its opening fence.
List<String> _dedent(List<String> lines, int indent) {
  if (indent == 0) return lines;
  return lines.map((line) {
    var strip = 0;
    while (strip < indent && strip < line.length && line[strip] == ' ') {
      strip++;
    }
    return line.substring(strip);
  }).toList(growable: false);
}

/// Pulls the summary out of a `<details>` run and returns the rest as its body.
MarkdownSegment _readDetails(List<String> lines, int open, int close) {
  final isOpen = RegExp(r'\bopen\b', caseSensitive: false)
      .hasMatch(lines[open]);

  var title = 'Details';
  final body = <String>[];

  for (var i = open + 1; i < close; i++) {
    final summary = _summaryLine.firstMatch(lines[i]);
    if (summary != null && body.isEmpty) {
      title = summary.group(1)!.trim();
      continue;
    }
    body.add(lines[i]);
  }

  return MarkdownSegment.details(
    title: title,
    text: body.join('\n').trim(),
    open: isOpen,
  );
}
