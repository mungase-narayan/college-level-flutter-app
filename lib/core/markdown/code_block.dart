import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_highlight/re_highlight.dart';

import 'code_languages.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../config/theme/app_theme.dart';

/// Port of the `CodeBlock` component in `src/components/shared/markdown.tsx`:
/// a language chip, a copy button, and the code itself in a scrollable pane
/// capped at roughly the same height the web version uses (`26rem`).
///
/// The web app highlights with Prism's `oneDark` / `oneLight`; `re_highlight`
/// ships `atom-one-dark` / `atom-one-light`, which are the same two themes.
class MarkdownCodeBlock extends StatefulWidget {
  const MarkdownCodeBlock({super.key, required this.code, this.language});

  final String code;
  final String? language;

  @override
  State<MarkdownCodeBlock> createState() => _MarkdownCodeBlockState();
}

class _MarkdownCodeBlockState extends State<MarkdownCodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    // Matches the web's 1.5s revert on the copy affordance.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    final base = TextStyle(
      fontFamily: AppTheme.mono,
      fontSize: 13,
      height: 1.7,
      color: scheme.foreground,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 4),
            child: Row(
              children: [
                Text(
                  (widget.language ?? '').isEmpty ? 'code' : widget.language!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontFamily: AppTheme.mono,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  // No toast — the label itself reverts after 1.5s, exactly as
                  // the web button does.
                  onPressed: _copy,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: _copied
                        ? tokens.success.foreground
                        : scheme.mutedForeground,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 13,
                  ),
                  label: Text(_copied ? 'Copied' : 'Copy'),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            // `maxHeight: 26rem` on the web.
            constraints: const BoxConstraints(maxHeight: 416),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text.rich(_span(base, tokens.isDark)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Highlights when the language is one we registered; otherwise returns the
  /// code as a single plain span rather than failing.
  TextSpan _span(TextStyle base, bool isDark) {
    final language = (widget.language ?? '').toLowerCase();
    if (!hasHighlighting(language)) {
      return TextSpan(text: widget.code, style: base);
    }

    try {
      final result = codeHighlight.highlight(code: widget.code, language: language);
      final renderer = TextSpanRenderer(
        base,
        // The themes carry their own `root` background; the surface here is the
        // card's `muted`, so the background is dropped by only reading colours.
        isDark ? atomOneDarkTheme : atomOneLightTheme,
      );
      result.render(renderer);
      return renderer.span ?? TextSpan(text: widget.code, style: base);
    } catch (_) {
      // A grammar that throws on odd input must never take the page down.
      return TextSpan(text: widget.code, style: base);
    }
  }
}
