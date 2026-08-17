import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/practice_attempt.dart';
import '../../domain/entities/practice_question.dart';

/// The answer surface for an objective question — one tap per option.
///
/// Options are lettered A, B, C… as they are on the web, because a question's
/// prose usually refers to them that way.
class PracticeObjectiveInput extends StatelessWidget {
  const PracticeObjectiveInput({
    super.key,
    required this.question,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final PracticeQuestion question;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final bool enabled;

  /// A true/false question often ships with no options of its own — the two
  /// choices are implied by the type.
  List<QuestionOption> get _options => question.options.isNotEmpty
      ? question.options
      : const [
          QuestionOption(id: 'true', text: 'True'),
          QuestionOption(id: 'false', text: 'False'),
        ];

  void _toggle(String id) {
    if (!enabled) return;
    if (!question.allowsMultiple) {
      onChanged([id]);
      return;
    }
    final next = [...selected];
    next.contains(id) ? next.remove(id) : next.add(id);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = _options;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question.allowsMultiple
              ? 'Select all that apply.'
              : 'Choose one answer.',
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 10),
        for (final (index, option) in options.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionTile(
              letter: String.fromCharCode(65 + index),
              option: option,
              isSelected: selected.contains(option.id),
              isMultiple: question.allowsMultiple,
              enabled: enabled,
              onTap: () => _toggle(option.id),
            ),
          ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.letter,
    required this.option,
    required this.isSelected,
    required this.isMultiple,
    required this.enabled,
    required this.onTap,
  });

  final String letter;
  final QuestionOption option;
  final bool isSelected;
  final bool isMultiple;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isMultiple
                  ? (isSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded)
                  : (isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded),
              size: 20,
              color: isSelected ? scheme.primary : scheme.mutedForeground,
            ),
            const SizedBox(width: 10),
            Text(
              '$letter.',
              style: theme.textTheme.labelMedium?.copyWith(
                color: isSelected ? scheme.primary : scheme.mutedForeground,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: InlineMarkdown(option.text)),
          ],
        ),
      ),
    );
  }
}

/// The coding surface: the editor, its language picker, and the buttons that
/// send code to the runner.
///
/// Per-language buffers live here rather than in the cubit because they are a
/// convenience of *this* screen — the server never sees them, and switching
/// back to a language you have already typed in should restore what you wrote
/// rather than the starter template.
class PracticeCodingInput extends StatefulWidget {
  const PracticeCodingInput({
    super.key,
    required this.question,
    required this.draft,
    required this.onChanged,
    required this.onRun,
    required this.onRunCustom,
    required this.isRunning,
    this.enabled = true,
  });

  final PracticeQuestion question;
  final PracticeAnswerDraft draft;
  final ValueChanged<PracticeAnswerDraft> onChanged;

  /// Runs against the sample cases.
  final VoidCallback onRun;

  /// Runs against whatever the student typed as stdin.
  final ValueChanged<String> onRunCustom;

  final bool isRunning;
  final bool enabled;

  @override
  State<PracticeCodingInput> createState() => _PracticeCodingInputState();
}

class _PracticeCodingInputState extends State<PracticeCodingInput> {
  late final CodeLineEditingController _code =
      CodeLineEditingController.fromText(widget.draft.code ?? '')
        ..addListener(_onCodeChanged);
  final _stdin = TextEditingController();

  /// What was typed in each language, so a switch never destroys work.
  final Map<String, String> _buffers = {};

  bool _customOpen = false;

  @override
  void dispose() {
    _code
      ..removeListener(_onCodeChanged)
      ..dispose();
    _stdin.dispose();
    super.dispose();
  }

  void _onCodeChanged() =>
      widget.onChanged(widget.draft.copyWith(code: _code.text));

  @override
  void didUpdateWidget(PracticeCodingInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The cubit re-seeds the draft on a retry or a language switch; adopt it
    // without clobbering what the student is typing the rest of the time.
    final incoming = widget.draft.code ?? '';
    if (incoming != _code.text && widget.draft.language != oldWidget.draft.language) {
      _code.text = incoming;
    }
  }

  void _switchLanguage(String language) {
    if (language == widget.draft.language) return;
    _buffers[widget.draft.language ?? ''] = _code.text;

    final restored = _buffers[language];
    final template = widget.question.languageTemplates
        .where((t) => t.language == language)
        .firstOrNull;
    final next = restored ?? template?.initialCode ?? '';

    _code.text = next;
    widget.onChanged(widget.draft.copyWith(language: language, code: next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final templates = widget.question.languageTemplates;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (templates.length > 1) ...[
          Row(
            children: [
              Text('Language', style: theme.textTheme.labelMedium),
              const SizedBox(width: 12),
              Expanded(
                child: AppSelect<String>(
                  value: widget.draft.language,
                  onChanged: (value) =>
                      value == null ? null : _switchLanguage(value),
                  items: [
                    for (final template in templates)
                      AppSelectItem(
                        value: template.language,
                        label: template.language,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        AppCodeEditor(
          controller: _code,
          language: widget.draft.language,
          readOnly: !widget.enabled,
          hint: 'Write your solution…',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: widget.isRunning ? 'Running…' : 'Run',
                icon: Icons.play_arrow_rounded,
                size: AppButtonSize.sm,
                variant: AppButtonVariant.outline,
                isLoading: widget.isRunning,
                expand: true,
                // The runner is synchronous and can take ~20s; a second tap
                // would just queue another wait.
                onPressed: widget.isRunning || !widget.enabled
                    ? null
                    : widget.onRun,
              ),
            ),
            const SizedBox(width: 8),
            AppButton(
              label: _customOpen ? 'Hide input' : 'Custom input',
              size: AppButtonSize.sm,
              variant: AppButtonVariant.ghost,
              onPressed: () => setState(() => _customOpen = !_customOpen),
            ),
          ],
        ),
        if (_customOpen) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _stdin,
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(fontFamily: AppTheme.mono, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Input to run your code against…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(
              label: 'Run with this input',
              size: AppButtonSize.sm,
              variant: AppButtonVariant.outline,
              onPressed: widget.isRunning || !widget.enabled
                  ? null
                  : () => widget.onRunCustom(_stdin.text),
            ),
          ),
        ],
      ],
    );
  }
}
