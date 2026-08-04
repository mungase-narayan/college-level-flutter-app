import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_theme.dart';

/// Port of the shared `Markdown` renderer. Question statements, contest rules,
/// announcements, and notes are all authored as GitHub-flavoured markdown.
///
/// KaTeX math (`remark-math` + `rehype-katex` on the web) is not rendered here
/// yet — `flutter_math_fork` is available for that once a question with inline
/// math is on hand to verify the delimiters against.
class AppMarkdown extends StatelessWidget {
  const AppMarkdown(this.data, {super.key, this.selectable = true, this.shrinkWrap = true});

  final String? data;
  final bool selectable;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final body = data?.trim() ?? '';
    if (body.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = context.scheme;
    final code = TextStyle(
      fontFamily: AppTheme.mono,
      fontSize: 13.5,
      color: scheme.foreground,
    );

    final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium,
      h1: theme.textTheme.headlineSmall,
      h2: theme.textTheme.titleLarge,
      h3: theme.textTheme.titleMedium,
      h4: theme.textTheme.titleSmall,
      listBullet: theme.textTheme.bodyMedium,
      blockquote: theme.textTheme.bodyMedium?.copyWith(color: scheme.mutedForeground),
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
    );

    return MarkdownBody(
      data: body,
      selectable: selectable,
      shrinkWrap: shrinkWrap,
      styleSheet: styleSheet,
      onTapLink: (_, href, _) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
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
