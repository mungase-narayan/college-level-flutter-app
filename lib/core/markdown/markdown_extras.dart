import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../config/theme/app_theme.dart';

/// The inline pieces `src/components/shared/markdown.tsx` gained alongside the
/// block system: `==highlight==`, KaTeX math, and the small allow-list of raw
/// HTML tags its sanitizer lets through.
///
/// `flutter_markdown` renders neither raw HTML nor math, so each is recognised
/// with an inline syntax that emits a private element, then drawn by a matching
/// [MarkdownElementBuilder]. Anything outside the allow-list stays literal text
/// — the same outcome the web's sanitizer produces.

/// `==text==` → a `mark` element. The web adds this with a remark plugin; the
/// negative-lookahead on whitespace keeps `== ` from opening a highlight.
class HighlightSyntax extends md.InlineSyntax {
  HighlightSyntax() : super(r'==(?=\S)([\s\S]*?\S)==');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('mark', match[1]!));
    return true;
  }
}

/// `$…$` → an `inlineMath` element carrying the TeX as its text.
///
/// Requires a non-space immediately inside the delimiters so a bare `$5` or a
/// price range never opens math, and rejects an escaped `\$`.
class InlineMathSyntax extends md.InlineSyntax {
  InlineMathSyntax() : super(r'(?<!\\)\$(?!\s)((?:\\.|[^$\\])+?)(?<!\s)\$');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text('inlineMath', match[1]!));
    return true;
  }
}

/// One of the raw inline tags the web sanitizer keeps. Written as a syntax
/// rather than relying on the markdown package's HTML passthrough so the
/// contents can be styled instead of printed with their angle brackets.
class InlineHtmlTagSyntax extends md.InlineSyntax {
  InlineHtmlTagSyntax(this.tag)
      : super('<$tag(?:\\s[^>]*)?>([\\s\\S]*?)</$tag>');

  final String tag;

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text(tag, match[1]!));
    return true;
  }
}

/// The tags rendered with a builder below. `del` is left out: GFM's `~~…~~`
/// already produces it and the style sheet already styles it.
const List<String> kInlineHtmlTags = [
  'mark',
  'kbd',
  'u',
  'ins',
  'sub',
  'sup',
  'abbr',
];

List<md.InlineSyntax> markdownInlineSyntaxes() => [
      // Math first: a `$…$` run must not be chewed up by another syntax.
      InlineMathSyntax(),
      HighlightSyntax(),
      for (final tag in kInlineHtmlTags) InlineHtmlTagSyntax(tag),
    ];

Map<String, MarkdownElementBuilder> markdownBuilders(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = context.scheme;
  final body = theme.textTheme.bodyMedium ?? const TextStyle();

  return {
    'inlineMath': _MathBuilder(body),
    'mark': _ChipBuilder(
      style: body.copyWith(color: scheme.foreground),
      background: scheme.primary.withValues(alpha: 0.2),
    ),
    'kbd': _ChipBuilder(
      style: body.copyWith(
        fontFamily: AppTheme.mono,
        fontSize: (body.fontSize ?? 15) * 0.82,
        fontWeight: FontWeight.w500,
      ),
      background: scheme.muted,
      border: scheme.border,
    ),
    'u': _StyledTextBuilder(
      body.copyWith(decoration: TextDecoration.underline),
    ),
    'ins': _StyledTextBuilder(
      body.copyWith(
        decoration: TextDecoration.underline,
        decorationColor: scheme.primary,
      ),
    ),
    'sub': _StyledTextBuilder(
      body.copyWith(fontSize: (body.fontSize ?? 15) * 0.72),
      offsetY: 3,
    ),
    'sup': _StyledTextBuilder(
      body.copyWith(fontSize: (body.fontSize ?? 15) * 0.72),
      offsetY: -4,
    ),
    // `title` is where the expansion lives, but there is no hover on a phone,
    // so an abbreviation just renders as dotted-underlined text.
    'abbr': _StyledTextBuilder(
      body.copyWith(
        decoration: TextDecoration.underline,
        decorationStyle: TextDecorationStyle.dotted,
      ),
    ),
  };
}

class _MathBuilder extends MarkdownElementBuilder {
  _MathBuilder(this.style);

  final TextStyle style;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return Math.tex(
      element.textContent,
      mathStyle: MathStyle.text,
      textStyle: parentStyle ?? style,
      // Bad TeX shows as its own source rather than an error widget, matching
      // how an unparseable block degrades to a code block.
      onErrorFallback: (_) => Text(
        '\$${element.textContent}\$',
        style: (parentStyle ?? style).copyWith(fontFamily: AppTheme.mono),
      ),
    );
  }
}

/// Displays `$$…$$` math the parser lifted into its own segment.
class DisplayMath extends StatelessWidget {
  const DisplayMath(this.tex, {super.key});

  final String tex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          tex,
          mathStyle: MathStyle.display,
          textStyle: theme.textTheme.bodyLarge,
          onErrorFallback: (_) => Text(
            tex,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: AppTheme.mono,
            ),
          ),
        ),
      ),
    );
  }
}

/// A small filled chip — `mark` and `kbd`.
class _ChipBuilder extends MarkdownElementBuilder {
  _ChipBuilder({required this.style, required this.background, this.border});

  final TextStyle style;
  final Color background;
  final Color? border;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Text(element.textContent, style: style),
    );
  }
}

class _StyledTextBuilder extends MarkdownElementBuilder {
  _StyledTextBuilder(this.style, {this.offsetY = 0});

  final TextStyle style;

  /// Vertical nudge, used to seat `sub` and `sup` off the baseline.
  final double offsetY;

  @override
  Widget visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final text = Text(element.textContent, style: style);
    if (offsetY == 0) return text;
    return Transform.translate(offset: Offset(0, offsetY), child: text);
  }
}
