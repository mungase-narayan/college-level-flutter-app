import 'package:flutter/material.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/error/failures.dart';
import '../../domain/entities/note.dart';

/// What the composer collects.
@immutable
class NoteDraft {
  const NoteDraft({
    required this.title,
    required this.content,
    this.tags = const [],
    this.visibility = 'published',
  });

  final String title;
  final String content;
  final List<String> tags;
  final String visibility;
}

/// Opens the note composer. Resolves true when something was saved.
///
/// The sheet **submits for itself** rather than popping a draft for the caller
/// to write. The server caps a title at 250 characters and a body at 50 000 and
/// answers a breach with a 422, and popping first would throw away a long
/// markdown body to show a toast. Submitting here keeps the draft on screen and
/// shows the failure against it.
Future<bool?> showNoteComposer(
  BuildContext context, {
  NoteDraft? initial,
  String? subtitle,
  required Future<Failure?> Function(NoteDraft draft) onSubmit,
}) =>
    showAppSheet<bool>(
      context,
      title: initial == null ? 'Write a note' : 'Edit note',
      subtitle: subtitle,
      builder: (_) => _NoteComposer(initial: initial, onSubmit: onSubmit),
    );

class _NoteComposer extends StatefulWidget {
  const _NoteComposer({required this.initial, required this.onSubmit});

  final NoteDraft? initial;
  final Future<Failure?> Function(NoteDraft draft) onSubmit;

  @override
  State<_NoteComposer> createState() => _NoteComposerState();
}

enum _Pane { write, preview }

class _NoteComposerState extends State<_NoteComposer> {
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _content =
      TextEditingController(text: widget.initial?.content ?? '');
  final _tagInput = TextEditingController();
  final _tagFocus = FocusNode();

  late final List<String> _tags = [...?widget.initial?.tags];
  late String _visibility = widget.initial?.visibility ?? 'published';

  _Pane _pane = _Pane.write;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    // Blur commits whatever is half-typed, so a tag is never lost to a stray
    // tap outside the field.
    _tagFocus.addListener(() {
      if (!_tagFocus.hasFocus) _commitTag(_tagInput.text);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _tagInput.dispose();
    _tagFocus.dispose();
    super.dispose();
  }

  void _commitTag(String raw) {
    final value = NoteMeta.normaliseTag(raw);
    _tagInput.clear();
    if (value == null || _tags.length >= NoteMeta.tagsMax) {
      setState(() {});
      return;
    }
    // Case-insensitive dedupe, keeping the casing already stored — the server
    // normalises the same way.
    final exists =
        _tags.any((tag) => tag.toLowerCase() == value.toLowerCase());
    setState(() {
      if (!exists) _tags.add(value);
    });
  }

  void _onTagChanged(String value) {
    if (!value.contains(',')) return;
    final parts = value.split(',');
    // Everything before the last comma is committed; the tail stays as typed.
    for (final part in parts.take(parts.length - 1)) {
      _commitTag(part);
    }
    _tagInput.text = parts.last.trim();
    _tagInput.selection =
        TextSelection.collapsed(offset: _tagInput.text.length);
  }

  Future<void> _submit() async {
    if (_busy) return;

    // Commit anything sitting unconfirmed in the tag field first.
    _commitTag(_tagInput.text);

    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty || content.isEmpty) {
      setState(() => _error = 'A title and some content are required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final failure = await widget.onSubmit(
      NoteDraft(
        title: title,
        // Untrimmed on purpose: trailing markdown whitespace can be meaningful.
        content: _content.text,
        tags: List.unmodifiable(_tags),
        visibility: _visibility,
      ),
    );

    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      // A 422 carries the per-field detail — which field was too long is
      // exactly what the student needs here.
      _error = failure is ValidationFailure
          ? failure.detailedMessage
          : failure.message;
    });
  }

  String get _submitLabel {
    if (_busy) return 'Saving…';
    if (_isEdit) return 'Save changes';
    return _visibility == 'published' ? 'Publish' : 'Save';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          label: 'Title',
          hint: 'e.g. How TCP handshake works',
          controller: _title,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Text('Content', style: theme.textTheme.labelMedium),
            const Spacer(),
            AppFilterChips<_Pane>(
              // Wrapped, not the scrolling strip: a non-flex child of a Row is
              // laid out with unbounded width, and a horizontal viewport in
              // there asserts. Two short chips never need a second line anyway.
              wrap: true,
              selected: _pane,
              onSelected: (pane) {
                // Drop the keyboard on the way to the preview, or an offstage
                // field keeps focus and the sheet stays short.
                if (pane == _Pane.preview) FocusScope.of(context).unfocus();
                setState(() => _pane = pane);
              },
              options: const [
                AppFilterChipOption(value: _Pane.write, label: 'Write'),
                AppFilterChipOption(value: _Pane.preview, label: 'Preview'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // IndexedStack, not a ternary: the field stays mounted, so the cursor
        // position and the undo history survive a look at the preview.
        IndexedStack(
          index: _pane.index,
          sizing: StackFit.loose,
          children: [
            AppInput(
              hint: 'Write your note… markdown is supported.',
              controller: _content,
              minLines: 6,
              maxLines: 10,
            ),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 140),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.border),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _content,
                builder: (context, value, _) => value.text.trim().isEmpty
                    ? Text(
                        'Nothing to preview yet — switch to Write and add some '
                        'content.',
                        style: theme.textTheme.labelSmall,
                      )
                    : AppMarkdown(value.text),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Tags (${_tags.length}/${NoteMeta.tagsMax})',
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        if (_tags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in _tags)
                _EditableTag(
                  tag: tag,
                  onRemove: () => setState(() => _tags.remove(tag)),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (_tags.length < NoteMeta.tagsMax)
          AppInput(
            hint: _tags.isEmpty ? 'e.g. dsa, algorithms' : 'Add tag…',
            controller: _tagInput,
            focusNode: _tagFocus,
            onChanged: _onTagChanged,
            onSubmitted: _commitTag,
          ),
        const SizedBox(height: 6),
        Text(
          'Press enter or a comma to add a tag.',
          style: theme.textTheme.labelSmall,
        ),
        const SizedBox(height: 14),
        Text('Visibility', style: theme.textTheme.labelMedium),
        const SizedBox(height: 8),
        AppOptionGroup<String>(
          selected: _visibility,
          onSelected: (value) => setState(() => _visibility = value),
          options: const [
            AppOptionItem(
              value: 'private',
              label: 'Private',
              description: 'Only you can see it',
              icon: Icons.lock_outline_rounded,
            ),
            AppOptionItem(
              value: 'published',
              label: 'Published',
              description: 'Visible to your school',
              icon: Icons.public_rounded,
            ),
          ],
        ),
        if (_error case final error?) ...[
          const SizedBox(height: 12),
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.destructive,
            ),
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: _submitLabel,
          expand: true,
          isLoading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _EditableTag extends StatelessWidget {
  const _EditableTag({required this.tag, required this.onRemove});

  final String tag;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 4, 5, 4),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('#$tag', style: theme.textTheme.labelSmall),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Semantics(
              button: true,
              label: 'Remove $tag',
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: scheme.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
