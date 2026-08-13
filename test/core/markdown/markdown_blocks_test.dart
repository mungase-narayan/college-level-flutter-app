import 'dart:convert';

import 'package:college_level/core/common/widgets/app_markdown.dart';
import 'package:college_level/core/config/theme/app_theme.dart';
import 'package:college_level/core/markdown/block_definitions.dart';
import 'package:college_level/core/markdown/code_block.dart';
import 'package:college_level/core/markdown/markdown_blocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `snippet` field of every entry in `src/lib/content/blocks.ts` is
/// documented as "inserted verbatim, so it must be a working example" — which
/// makes those snippets the right fixture for the Flutter renderers too. Each
/// body below is the JSON from its snippet.
///
/// Course content is author-controlled, so the contract these tests protect is:
/// a well-formed block builds, and a malformed one degrades to a code block
/// rather than throwing or leaving a gap.
const Map<String, String> _snippets = {
  'quiz': '''
{
  "title": "Check your understanding",
  "questions": [
    {
      "question": "What is the time complexity of binary search?",
      "options": ["O(n)", "O(log n)", "O(n log n)"],
      "answer": 1,
      "explanation": "The search space halves on every comparison."
    }
  ]
}''',
  'timeline': '''
{
  "items": [
    { "date": "Week 1", "title": "Arrays and strings", "description": "Two pointers." },
    { "date": "Week 2", "title": "Linked lists" }
  ]
}''',
  'video': '{"src": "https://example.com/lecture-01.mp4", "caption": "Lecture 1"}',
  'notice': '''
{
  "title": "Lab session rescheduled",
  "date": "12 July 2026",
  "body": "Thursday's lab moves to Friday.",
  "url": "/student/timetable",
  "linkLabel": "View timetable"
}''',
  'assignment': '''
{
  "title": "Sorting algorithms report",
  "due": "20 August 2026",
  "points": 20,
  "instructions": ["Implement merge sort.", "Compare runtimes."],
  "url": "/student/courses"
}''',
  'playground':
      '{"provider": "stackblitz", "id": "vitejs-vite-abc123", "title": "Try it", "height": 420}',
  'flashcards': '''
{
  "cards": [
    { "front": "What is a stack?", "back": "Last-in, first-out." },
    { "front": "What is a queue?", "back": "First-in, first-out." }
  ]
}''',
  'tabs': '''
{
  "tabs": [
    { "label": "Python", "content": "Use **print**." },
    { "label": "Java", "content": "Use **System.out.println** instead." }
  ]
}''',
  'cards': '''
[
  {
    "title": "Reading list",
    "description": "Chapters to cover.",
    "icon": "📚",
    "url": "https://example.com/reading",
    "button": "Open the list"
  },
  { "title": "Practice set", "description": "Twenty problems.", "badge": "Unit 3" }
]''',
  'stats': '''
{
  "items": [
    { "value": "40", "label": "Contact hours", "hint": "Per semester" },
    { "value": "4", "label": "Credits" }
  ]
}''',
  'faq': '''
{
  "items": [
    { "question": "Is the lab record graded?", "answer": "Yes, 10 internal marks." }
  ]
}''',
  'alert':
      '{"variant": "warning", "title": "Before you start", "body": "Install the toolchain."}',
  'button':
      '{"label": "Start the practice set", "url": "/student/practice", "variant": "primary", "align": "center"}',
  'gallery': '''
{
  "columns": 3,
  "images": [
    { "src": "https://example.com/setup.png", "alt": "Setup", "caption": "Breadboard" }
  ]
}''',
  'pdf':
      '{"src": "https://example.com/unit-3-notes.pdf", "title": "Unit 3 — notes", "height": 480}',
  'youtube': '{"id": "dQw4w9WgXcQ", "title": "Recap", "start": 0}',
  'leetcode':
      '{"slug": "two-sum", "title": "Two Sum", "difficulty": "Easy", "topics": ["Array"]}',
  'mermaid': 'flowchart LR\n  A[Read input] --> B{Valid?}',
  'accordion': '''
{
  "items": [
    { "title": "Prerequisites", "content": "Discrete maths.", "open": true },
    { "title": "Reference books", "content": "CLRS, chapters 1–4." }
  ]
}''',
};

/// The blocks that mount a `WebView`, directly (`mermaid`, `playground`, `pdf`)
/// or through `VideoPreview` (`video`, `youtube`). They cannot build in a unit
/// test — no platform WebView implementation is registered — so they are
/// covered by the dispatcher tests only, and excluded from the render sweep.
const Set<String> _webViewBlocks = {
  'mermaid',
  'playground',
  'pdf',
  'video',
  'youtube',
};

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );

Widget _noop(String source) => const SizedBox.shrink();

/// A fenced block, written the way an author would.
String _fence(String key, String body) => '```$key\n$body\n```';

/// Wraps [content] in an open accordion section, one nesting level deeper.
///
/// Built with `jsonEncode` rather than hand-escaped string literals: the
/// content of a nested block is a JSON string containing backticks, quotes, and
/// newlines, and getting that escaping wrong by hand produces a *malformed*
/// body — which also falls back to a code block, and would make these tests
/// pass for entirely the wrong reason.
String _accordionAround(String content, {required String title}) => _fence(
      'accordion',
      jsonEncode({
        'items': [
          {'title': title, 'content': content, 'open': true},
        ],
      }),
    );

void main() {
  group('buildMarkdownBlock', () {
    test('has a fixture for every declared block key', () {
      // Guards against a key being added to blocks.ts and ported without a
      // renderer — the fixture map is the checklist.
      expect(_snippets.keys.toSet(), kBlockKeys.toSet());
    });

    test('builds a widget for every snippet', () {
      for (final entry in _snippets.entries) {
        expect(
          buildMarkdownBlock(
            language: entry.key,
            body: entry.value,
            renderContent: _noop,
          ),
          isNotNull,
          reason: 'block "${entry.key}" should build from its own snippet',
        );
      }
    });

    test('returns null for malformed JSON so the caller can fall back', () {
      for (final key in kBlockKeys) {
        // Mermaid's body is diagram syntax, so nothing about it can be
        // "malformed JSON" — it is the one key that always builds.
        if (kRawBodyBlockKeys.contains(key)) continue;

        expect(
          buildMarkdownBlock(
            language: key,
            body: '{ not json',
            renderContent: _noop,
          ),
          isNull,
          reason: 'block "$key" should reject an unparseable body',
        );
      }
    });

    test('returns null for an unknown key or an empty body', () {
      expect(
        buildMarkdownBlock(
          language: 'nonsense',
          body: '{}',
          renderContent: _noop,
        ),
        isNull,
      );
      expect(
        buildMarkdownBlock(language: 'quiz', body: '  ', renderContent: _noop),
        isNull,
      );
    });

    test('mermaid skips the JSON parse and keeps its source', () {
      final widget = buildMarkdownBlock(
        language: 'mermaid',
        body: 'flowchart LR\n  A --> B',
        renderContent: _noop,
      );

      expect(widget, isA<MermaidBlock>());
      expect((widget! as MermaidBlock).source, 'flowchart LR\n  A --> B');
    });

    test('cards accepts a bare array and a single object', () {
      expect(
        buildMarkdownBlock(
          language: 'cards',
          body: '[{"title": "One"}]',
          renderContent: _noop,
        ),
        isA<CardsGrid>(),
      );
      expect(
        buildMarkdownBlock(
          language: 'cards',
          body: '{"title": "One"}',
          renderContent: _noop,
        ),
        isA<CardsGrid>(),
      );
    });
  });

  group('rendering through AppMarkdown', () {
    for (final entry in _snippets.entries) {
      if (_webViewBlocks.contains(entry.key)) continue;

      testWidgets('renders the ${entry.key} block', (tester) async {
        await tester.pumpWidget(
          _host(
            AppMarkdown('Intro line.\n\n```${entry.key}\n${entry.value}\n```'),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a malformed block degrades to a code block, not a gap',
        (tester) async {
      await tester.pumpWidget(
        _host(const AppMarkdown('```quiz\n{ not json\n```')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(MarkdownCodeBlock), findsOneWidget);
      // The author's own source is what they see.
      expect(find.textContaining('not json'), findsWidgets);
    });

    testWidgets('an unknown fence language renders as a code block',
        (tester) async {
      await tester.pumpWidget(
        _host(const AppMarkdown('```dart\nvoid main() {}\n```')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('void main()'), findsWidgets);
    });

    testWidgets('a block nested one level still renders as a block',
        (tester) async {
      // The web's `renderContent` re-enters `<Markdown>`, so a block inside an
      // accordion section is a real block there too.
      final source = _accordionAround(
        _fence('alert', '{"body": "nested"}'),
        title: 'L1',
      );

      await tester.pumpWidget(_host(AppMarkdown(source)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('nested'), findsOneWidget);
      expect(find.byType(MarkdownCodeBlock), findsNothing);
    });

    testWidgets('past the nesting limit a block degrades to source',
        (tester) async {
      // The bound is what stops a block that transitively contains itself from
      // recursing forever; at depth 2 the fence is shown as code instead.
      final source = _accordionAround(
        _accordionAround(_fence('alert', '{"body": "deep"}'), title: 'L2'),
        title: 'L1',
      );

      await tester.pumpWidget(_host(AppMarkdown(source)));
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Both accordions opened — so the one code block is the innermost alert
      // falling back to source, not a malformed outer body.
      expect(find.text('L1'), findsOneWidget);
      expect(find.text('L2'), findsOneWidget);
      expect(find.text('deep'), findsNothing);
      expect(find.byType(MarkdownCodeBlock), findsOneWidget);
    });
  });

  group('markdown extras', () {
    testWidgets('task lists, highlight, and inline HTML render', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppMarkdown(
            '- [x] Done\n'
            '- [ ] Pending\n\n'
            'Some ==highlighted== text with <kbd>Ctrl</kbd> and H<sub>2</sub>O.',
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('highlighted'), findsOneWidget);
      expect(find.text('Ctrl'), findsOneWidget);
    });

    testWidgets('display and inline math render', (tester) async {
      await tester.pumpWidget(
        _host(const AppMarkdown(r'Inline $a^2 + b^2$ and:' '\n\n' r'$$E = mc^2$$')),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
