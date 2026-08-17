import 'package:college_level/core/markdown/block_definitions.dart';
import 'package:college_level/core/markdown/block_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// The parser is the seam the whole rich-block system hangs off: everything it
/// fails to recognise degrades to prose, and everything it recognises wrongly
/// swallows the author's text. These lock down both directions.
void main() {
  List<MarkdownSegment> parse(String source) => parseMarkdownSegments(source);

  group('block fences', () {
    test('every declared block key is lifted out of the prose', () {
      for (final key in kBlockKeys) {
        final segments = parse('Before\n\n```$key\n{}\n```\n\nAfter');

        expect(
          segments.map((s) => s.kind),
          [
            MarkdownSegmentKind.prose,
            MarkdownSegmentKind.block,
            MarkdownSegmentKind.prose,
          ],
          reason: 'block "$key" should split the document in three',
        );
        expect(segments[1].language, key);
        expect(segments[1].text, '{}');
      }
    });

    test('an unknown language stays prose', () {
      final segments = parse('```dart\nvoid main() {}\n```');

      expect(segments, hasLength(1));
      expect(segments.single.kind, MarkdownSegmentKind.prose);
      // The fence must survive intact so the markdown renderer still sees a
      // well-formed code block.
      expect(segments.single.text, contains('```dart'));
      expect(segments.single.text, contains('void main() {}'));
    });

    test('a block body is handed over raw, valid JSON or not', () {
      // The renderer, not the parser, decides a body is unusable — that is what
      // makes a malformed block fall back to a code block instead of a gap.
      final segments = parse('```quiz\n{ not json\n```');

      expect(segments.single.kind, MarkdownSegmentKind.block);
      expect(segments.single.text, '{ not json');
    });

    test('tilde fences and long fences parse', () {
      expect(parse('~~~alert\n{}\n~~~').single.language, 'alert');
      expect(parse('````stats\n{}\n````').single.language, 'stats');
    });

    test('an indented fence parses and its body is de-indented', () {
      final segments = parse('   ```alert\n   {"body": "hi"}\n   ```');

      expect(segments.single.kind, MarkdownSegmentKind.block);
      expect(segments.single.text, '{"body": "hi"}');
    });

    test('an unterminated fence does not hang, and stays prose', () {
      final segments = parse('```quiz\n{"title": "Never closed"}');

      expect(segments, hasLength(1));
      expect(segments.single.kind, MarkdownSegmentKind.prose);
    });

    test('a fence inside a JSON string is not a top-level fence', () {
      // The `tabs` snippet in blocks.ts embeds an escaped ```python fence in
      // its JSON. Escaped, it is one physical line and must not open a fence.
      const source = '```tabs\n'
          r'{"tabs": [{"label": "Python", "content": "```python\nprint()\n```"}]}'
          '\n```';

      final segments = parse(source);

      expect(segments, hasLength(1));
      expect(segments.single.kind, MarkdownSegmentKind.block);
      expect(segments.single.language, 'tabs');
    });

    test('consecutive blocks each get their own segment', () {
      final segments = parse('```alert\n{}\n```\n```stats\n{}\n```');

      expect(segments.map((s) => s.language), ['alert', 'stats']);
    });

    test('mermaid keeps its diagram body verbatim', () {
      final segments = parse('```mermaid\nflowchart LR\n  A --> B\n```');

      expect(segments.single.language, 'mermaid');
      expect(segments.single.text, 'flowchart LR\n  A --> B');
    });
  });

  group('display math', () {
    test(r'a one-line $$…$$ becomes a math segment', () {
      final segments = parse(r'$$E = mc^2$$');

      expect(segments.single.kind, MarkdownSegmentKind.math);
      expect(segments.single.text, 'E = mc^2');
    });

    test(r'a fenced $$ run spans lines', () {
      final segments = parse('\$\$\n\\frac{a}{b}\n\$\$');

      expect(segments.single.kind, MarkdownSegmentKind.math);
      expect(segments.single.text, r'\frac{a}{b}');
    });

    test(r'$$ inside a code fence is left alone', () {
      final segments = parse('```dart\n\$\$\nnot math\n\$\$\n```');

      expect(segments.single.kind, MarkdownSegmentKind.prose);
    });
  });

  group('raw <details>', () {
    test('summary becomes the title and the rest the body', () {
      final segments = parse(
        '<details open>\n<summary>Prerequisites</summary>\n\nDiscrete maths.\n</details>',
      );

      expect(segments.single.kind, MarkdownSegmentKind.details);
      expect(segments.single.title, 'Prerequisites');
      expect(segments.single.open, isTrue);
      expect(segments.single.text, 'Discrete maths.');
    });

    test('without `open` it starts collapsed', () {
      final segments = parse('<details>\n<summary>More</summary>\nBody\n</details>');

      expect(segments.single.open, isFalse);
    });

    test('an unclosed <details> stays prose', () {
      final segments = parse('<details>\n<summary>Oops</summary>');

      expect(segments.single.kind, MarkdownSegmentKind.prose);
    });
  });

  group('plain documents', () {
    test('prose with no blocks is a single segment', () {
      final segments = parse('# Heading\n\nA paragraph with **bold** text.');

      expect(segments, hasLength(1));
      expect(segments.single.kind, MarkdownSegmentKind.prose);
    });

    test('empty and whitespace-only sources yield nothing', () {
      expect(parse(''), isEmpty);
      expect(parse('   \n\n  '), isEmpty);
    });

    test('CRLF line endings are normalised', () {
      final segments = parse('Intro\r\n\r\n```alert\r\n{}\r\n```');

      expect(segments.map((s) => s.kind), [
        MarkdownSegmentKind.prose,
        MarkdownSegmentKind.block,
      ]);
      expect(segments.last.text, '{}');
    });
  });
}
