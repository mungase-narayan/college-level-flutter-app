import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_theme.dart';
import '../../markdown/block_parser.dart';
import '../../markdown/code_block.dart';
import '../../markdown/markdown_blocks.dart';
import '../../markdown/markdown_extras.dart';

/// Port of the shared `Markdown` renderer in
/// `src/components/shared/markdown.tsx`. Material content, question statements,
/// contest rules, announcements, notes, and comments are all authored as
/// GitHub-flavoured markdown, so everything the web renderer gained lands here
/// at every one of those call sites at once.
///
/// The document is split by [parseMarkdownSegments] before rendering: rich
/// blocks and display math are drawn by native widgets, and everything between
/// them goes through [MarkdownBody] untouched.
class AppMarkdown extends StatelessWidget {
  const AppMarkdown(
    this.data, {
    super.key,
    this.selectable = true,
    this.shrinkWrap = true,
    this.depth = 0,
  });

  final String? data;
  final bool selectable;
  final bool shrinkWrap;

  /// How many block bodies deep this instance is. 0 at the top level, 1 inside
  /// a tab panel or accordion section.
  ///
  /// A block nested past [_maxDepth] renders as a code block instead. The web's
  /// `renderContent` re-enters `<Markdown>` with no bound at all; the limit here
  /// is what stops a block that transitively contains itself from recursing
  /// forever, and one level of nesting is all the authoring UI can produce.
  final int depth;

  static const _maxDepth = 1;

  @override
  Widget build(BuildContext context) {
    final body = data?.trim() ?? '';
    if (body.isEmpty) return const SizedBox.shrink();

    final segments = parseMarkdownSegments(body);
    if (segments.isEmpty) return const SizedBox.shrink();

    // The overwhelmingly common case — plain prose with no blocks — stays a
    // single MarkdownBody with no wrapping Column.
    if (segments.length == 1 &&
        segments.first.kind == MarkdownSegmentKind.prose) {
      return _prose(context, segments.first.text);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final segment in segments) _segment(context, segment),
      ],
    );
  }

  Widget _segment(BuildContext context, MarkdownSegment segment) {
    switch (segment.kind) {
      case MarkdownSegmentKind.prose:
        return _prose(context, segment.text);

      case MarkdownSegmentKind.math:
        return DisplayMath(segment.text);

      case MarkdownSegmentKind.details:
        return DetailsBlock(
          title: segment.title ?? 'Details',
          body: segment.text,
          open: segment.open,
          renderContent: _child,
        );

      case MarkdownSegmentKind.block:
        final block = depth > _maxDepth
            ? null
            : buildMarkdownBlock(
                language: segment.language!,
                body: segment.text,
                renderContent: _child,
              );
        // Null means an unusable body — fall through to a plain code block so
        // the author sees what they typed instead of a gap.
        return block ??
            MarkdownCodeBlock(
              code: segment.text,
              language: segment.language,
            );
    }
  }

  /// Renderer handed to the blocks that carry markdown of their own.
  Widget _child(String source) =>
      AppMarkdown(source, selectable: selectable, depth: depth + 1);

  Widget _prose(BuildContext context, String source) {
    return MarkdownBody(
      data: source,
      selectable: selectable,
      shrinkWrap: shrinkWrap,
      styleSheet: _styleSheet(context),
      // `remark-breaks` on the web: a single newline is a line break.
      softLineBreak: true,
      inlineSyntaxes: markdownInlineSyntaxes(),
      builders: markdownBuilders(context),
      checkboxBuilder: (checked) => _TaskCheckbox(checked: checked),
      onTapLink: (_, href, _) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
    );
  }

  MarkdownStyleSheet _styleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final code = TextStyle(
      fontFamily: AppTheme.mono,
      fontSize: 13.5,
      color: scheme.foreground,
    );

    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium,
      h1: theme.textTheme.headlineSmall,
      h2: theme.textTheme.titleLarge,
      h3: theme.textTheme.titleMedium,
      h4: theme.textTheme.titleSmall,
      listBullet: theme.textTheme.bodyMedium,
      blockquote:
          theme.textTheme.bodyMedium?.copyWith(color: scheme.mutedForeground),
      blockquoteDecoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      code: code.copyWith(backgroundColor: scheme.muted),
      codeblockDecoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.border),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      tableBorder: TableBorder.all(color: scheme.border),
      tableHead: theme.textTheme.labelMedium,
      tableBody: theme.textTheme.bodySmall?.copyWith(color: scheme.foreground),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.border)),
      ),
      a: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.primary,
        decoration: TextDecoration.underline,
      ),
      del: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.mutedForeground,
        decoration: TextDecoration.lineThrough,
      ),
    );
  }
}

/// GFM task-list box. Read-only, as on the web — the state lives in the source,
/// not in the reader's session.
class _TaskCheckbox extends StatelessWidget {
  const _TaskCheckbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(top: 3, right: 6),
      child: Icon(
        checked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
        size: 16,
        color: checked ? tokens.scheme.primary : tokens.scheme.mutedForeground,
      ),
    );
  }
}

/// Single-line markdown for table cells and list rows — the React
/// `InlineMarkdown`. Strips block syntax so a long statement collapses to one
/// readable line.
class InlineMarkdown extends StatelessWidget {
  const InlineMarkdown(this.data, {super.key, this.style, this.maxLines = 2});

  final String? data;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final plain = (data ?? '')
        .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
        .replaceAll(RegExp(r'[*_`>#~]'), '')
        .replaceAll(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return Text(
      plain,
      style: style ?? Theme.of(context).textTheme.bodySmall,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
