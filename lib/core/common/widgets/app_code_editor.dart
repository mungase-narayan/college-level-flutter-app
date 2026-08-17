import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import '../../config/theme/app_theme.dart';
import '../../markdown/code_languages.dart';
import 'app_toast.dart';

/// The app's code editor — syntax highlighting, a line-number gutter, and the
/// two controls that matter on a phone: font size and copy.
///
/// Used wherever a student writes code: the practice solve screen and the
/// coding questions inside a quiz or an assignment. Before this, those two
/// places disagreed — the attempt runner offered a bare monospace `TextField`,
/// which is fine for a sentence and miserable for forty lines of Python.
///
/// The highlighting engine and its grammars are the same ones the read-only
/// markdown code block uses ([codeLanguages]), so a snippet in a question's
/// statement and the answer typed underneath it are coloured identically.
class AppCodeEditor extends StatefulWidget {
  const AppCodeEditor({
    super.key,
    required this.controller,
    this.language,
    this.readOnly = false,
    this.minHeight = 220,
    this.maxHeight = 420,
    this.showToolbar = true,
    this.hint,
  });

  /// Owned by the caller — the editor's contents outlive any one build, and a
  /// language switch has to be able to swap the text without losing focus.
  final CodeLineEditingController controller;

  /// `python`, `cpp`, `java` … Unknown or null renders unhighlighted rather
  /// than failing, exactly as the markdown block does.
  final String? language;

  final bool readOnly;
  final double minHeight;
  final double maxHeight;

  /// The language chip, font-size controls and copy button above the code.
  final bool showToolbar;

  final String? hint;

  @override
  State<AppCodeEditor> createState() => _AppCodeEditorState();
}

class _AppCodeEditorState extends State<AppCodeEditor> {
  /// Deliberately generous by phone standards and clamped at both ends: below
  /// 10 the gutter and the code stop being legible, above 24 barely a
  /// statement fits on a line.
  double _fontSize = 13;
  static const _minFont = 10.0;
  static const _maxFont = 22.0;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.controller.text));
    if (mounted) AppToast.success(context, 'Code copied');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final isDark = theme.brightness == Brightness.dark;
    final language = (widget.language ?? '').toLowerCase();

    final textStyle = TextStyle(
      fontFamily: AppTheme.mono,
      fontSize: _fontSize,
      height: 1.5,
      color: scheme.foreground,
    );

    return Container(
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showToolbar)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 2),
              child: Row(
                children: [
                  Text(
                    language.isEmpty ? 'code' : language,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontFamily: AppTheme.mono,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  _ToolbarButton(
                    icon: Icons.text_decrease_rounded,
                    tooltip: 'Smaller text',
                    onPressed: _fontSize <= _minFont
                        ? null
                        : () => setState(() => _fontSize -= 1),
                  ),
                  _ToolbarButton(
                    icon: Icons.text_increase_rounded,
                    tooltip: 'Larger text',
                    onPressed: _fontSize >= _maxFont
                        ? null
                        : () => setState(() => _fontSize += 1),
                  ),
                  _ToolbarButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Copy code',
                    onPressed: _copy,
                  ),
                ],
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: widget.minHeight,
              maxHeight: widget.maxHeight,
            ),
            child: CodeEditor(
              controller: widget.controller,
              readOnly: widget.readOnly,
              hint: widget.hint,
              // Off, deliberately: code indentation carries meaning, and
              // wrapping a long line into the gutter makes it unreadable. The
              // editor scrolls horizontally instead.
              wordWrap: false,
              padding: const EdgeInsets.symmetric(vertical: 10),
              style: CodeEditorStyle(
                fontFamily: AppTheme.mono,
                fontSize: _fontSize,
                textColor: scheme.foreground,
                codeTheme: CodeHighlightTheme(
                  languages: {
                    if (codeLanguages.containsKey(language))
                      language: CodeHighlightThemeMode(
                        mode: codeLanguages[language]!,
                      ),
                  },
                  theme: isDark ? atomOneDarkTheme : atomOneLightTheme,
                ),
              ),
              indicatorBuilder:
                  (context, editingController, chunkController, notifier) =>
                      Row(
                children: [
                  DefaultCodeLineNumber(
                    controller: editingController,
                    notifier: notifier,
                    textStyle: textStyle.copyWith(
                      color: scheme.mutedForeground,
                      fontSize: _fontSize - 1,
                    ),
                    focusedTextStyle: textStyle.copyWith(
                      color: scheme.primary,
                      fontSize: _fontSize - 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 17, color: context.scheme.mutedForeground),
      );
}
