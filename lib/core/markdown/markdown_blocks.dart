import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../common/widgets/app_badge.dart';
import '../common/widgets/app_button.dart';
import '../common/widgets/app_toast.dart';
import '../common/widgets/video_preview.dart';
import '../config/theme/app_colors.dart';
import '../config/theme/app_theme.dart';
import 'block_definitions.dart';
import 'web_frame.dart';

/// Flutter renderers for the rich blocks the markdown composer can insert —
/// the port of `src/components/shared/markdown-blocks.tsx`.
///
/// Each takes the already-parsed JSON body of its fence. Nothing here throws on
/// bad input: a block with missing fields renders what it can, and
/// [buildMarkdownBlock] returns null when the JSON itself won't parse so the
/// caller falls back to a plain code block — a malformed block always shows the
/// author their own source instead of a gap.

/// Renders a nested markdown body (tab panels, accordion sections).
///
/// Passed in rather than imported so this file never depends on `AppMarkdown`,
/// which depends on it — the same reason the web passes `renderContent` down.
typedef MarkdownChildBuilder = Widget Function(String source);

/// Builds the widget for a recognised block, or null when the body cannot be
/// used — mirroring `renderBlock` in `src/components/shared/markdown.tsx`.
Widget? buildMarkdownBlock({
  required String language,
  required String body,
  required MarkdownChildBuilder renderContent,
}) {
  if (!isBlockKey(language) || body.trim().isEmpty) return null;

  // Mermaid's body is diagram syntax, not JSON, so it skips the parse step.
  if (kRawBodyBlockKeys.contains(language)) {
    return MermaidBlock(source: body);
  }

  final Object? parsed;
  try {
    parsed = jsonDecode(body);
  } catch (_) {
    return null;
  }

  // `cards` is the one block whose body may be a bare array.
  if (language == 'cards') {
    final cards = _cardList(parsed);
    return cards.isEmpty ? null : CardsGrid(cards: cards);
  }

  if (parsed is! Map<String, dynamic>) return null;
  final data = parsed;

  return switch (language) {
    'quiz' => QuizBlock(data: data),
    'timeline' => TimelineBlock(data: data),
    'video' => VideoBlock(data: data),
    'notice' => NoticeBlock(data: data),
    'assignment' => AssignmentBlock(data: data),
    'playground' => PlaygroundBlock(data: data),
    'flashcards' => FlashcardsBlock(data: data),
    'tabs' => TabsBlock(data: data, renderContent: renderContent),
    'stats' => StatsBlock(data: data),
    'faq' => FaqBlock(data: data),
    'alert' => AlertBlock(data: data),
    'button' => ButtonBlock(data: data),
    'gallery' => GalleryBlock(data: data),
    'pdf' => PdfBlock(data: data),
    'youtube' => YouTubeBlock(data: data),
    'leetcode' => LeetCodeBlock(data: data),
    'accordion' => AccordionBlock(data: data, renderContent: renderContent),
    _ => null,
  };
}

/* -------------------------------------------------------------------------- */
/*                              JSON accessors                                 */
/* -------------------------------------------------------------------------- */

/// Every accessor is total: a wrong type reads as absent rather than throwing,
/// so one bad field never costs the whole block.
String? _str(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

int? _int(Object? value) => value is num ? value.toInt() : null;

bool _bool(Object? value) => value is bool && value;

List<Map<String, dynamic>> _objects(Object? value) =>
    (value as List?)?.whereType<Map<String, dynamic>>().toList(growable: false) ??
    const [];

List<String> _strings(Object? value) =>
    (value as List?)
        ?.whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList(growable: false) ??
    const [];

/// The body of a ```cards fence: a JSON array or a single JSON object, matching
/// `parseCards` on the web.
List<Map<String, dynamic>> _cardList(Object? parsed) {
  if (parsed is List) return _objects(parsed);
  if (parsed is Map<String, dynamic>) return [parsed];
  return const [];
}

Future<void> _open(BuildContext context, String? raw) async {
  final url = (raw ?? '').trim();
  if (url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null) return;

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    AppToast.error(context, 'Could not open this link.');
  }
}

/* -------------------------------------------------------------------------- */
/*                                  Chrome                                     */
/* -------------------------------------------------------------------------- */

/// Shared frame so every block sits the same distance from the prose — the
/// `not-prose my-6` wrapper on the web.
class _Block extends StatelessWidget {
  const _Block({required this.child, this.decorated = false, this.padding});

  final Widget child;

  /// Draws the outlined card the web's `OUTLINE` class gives a block.
  final bool decorated;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: decorated
          ? Container(
              padding: padding ?? const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: scheme.border.withValues(alpha: 0.7)),
              ),
              child: child,
            )
          : child,
    );
  }
}

class _BlockHeading extends StatelessWidget {
  const _BlockHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

/// A small rounded pill — due dates, points, difficulty, tags.
class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.shade});

  final String label;
  final TwShade? shade;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final tone = shade == null ? null : tokens.tone(shade!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: tone?.background ?? tokens.scheme.muted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: tone?.foreground ?? tokens.scheme.mutedForeground,
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                    Quiz                                     */
/* -------------------------------------------------------------------------- */

class QuizBlock extends StatelessWidget {
  const QuizBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = _str(data['title']);
    final questions = _objects(data['questions']);
    if (questions.isEmpty) return const SizedBox.shrink();

    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) _BlockHeading(title),
          for (var i = 0; i < questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _QuizQuestion(item: questions[i], index: i),
            ),
        ],
      ),
    );
  }
}

class _QuizQuestion extends StatefulWidget {
  const _QuizQuestion({required this.item, required this.index});

  final Map<String, dynamic> item;
  final int index;

  @override
  State<_QuizQuestion> createState() => _QuizQuestionState();
}

class _QuizQuestionState extends State<_QuizQuestion> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    final question = _str(widget.item['question']) ?? '';
    final options = _strings(widget.item['options']);
    final answer = _int(widget.item['answer']);
    final explanation = _str(widget.item['explanation']);
    final answered = _picked != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.index + 1}. $question',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < options.length; i++) ...[
            _QuizOption(
              label: options[i],
              // Once answered the correct row is always revealed, the wrong
              // pick is called out, and the rest dim — as on the web.
              state: !answered
                  ? _OptionState.idle
                  : i == answer
                      ? _OptionState.correct
                      : i == _picked
                          ? _OptionState.wrong
                          : _OptionState.dimmed,
              onTap: answered ? null : () => setState(() => _picked = i),
            ),
            const SizedBox(height: 6),
          ],
          if (answered) ...[
            const SizedBox(height: 4),
            Text(
              '${_picked == answer ? 'Correct. ' : 'Not quite. '}'
              '${explanation ?? ''}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _QuizOption extends StatelessWidget {
  const _QuizOption({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    final tone = switch (state) {
      _OptionState.correct => tokens.success,
      _OptionState.wrong => tokens.danger,
      _ => null,
    };

    return Opacity(
      opacity: state == _OptionState.dimmed ? 0.6 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tone?.background,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: tone?.foreground.withValues(alpha: 0.4) ?? scheme.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tone?.foreground,
                  ),
                ),
              ),
              if (state == _OptionState.correct)
                Icon(Icons.check_rounded, size: 16, color: tone!.foreground),
              if (state == _OptionState.wrong)
                Icon(Icons.close_rounded, size: 16, color: tone!.foreground),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                  Timeline                                   */
/* -------------------------------------------------------------------------- */

class TimelineBlock extends StatelessWidget {
  const TimelineBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final items = _objects(data['items']);
    if (items.isEmpty) return const SizedBox.shrink();

    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The rail: a dot on the item's own line, with the connector
                  // running on past it for every entry but the last.
                  SizedBox(
                    width: 22,
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        if (i != items.length - 1)
                          Expanded(
                            child: Container(
                              width: 1.5,
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              color: scheme.border,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i == items.length - 1 ? 0 : 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_str(items[i]['date']) case final date?)
                            Text(
                              date,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          Text(
                            _str(items[i]['title']) ?? '',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_str(items[i]['description']) case final body?)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                body,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                    Video                                    */
/* -------------------------------------------------------------------------- */

class VideoBlock extends StatelessWidget {
  const VideoBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final src = _str(data['src']);
    if (src == null) return const SizedBox.shrink();

    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // `poster` is not forwarded: the platform player draws its own first
          // frame, and a poster would only be visible for the instant before it.
          VideoPreview(url: src),
          if (_str(data['caption']) case final caption?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                caption,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                   Notice                                    */
/* -------------------------------------------------------------------------- */

class NoticeBlock extends StatelessWidget {
  const NoticeBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final url = _str(data['url']);

    return _Block(
      // Clipped rather than `borderRadius` on the decoration itself: Flutter
      // refuses to paint a non-uniform border under a radius, and the throw
      // lands after the background fill, so the notice would render empty.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 12, 14, 12),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            border: BorderDirectional(
              start: BorderSide(color: scheme.primary, width: 4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 2,
                children: [
                  Text(
                    _str(data['title']) ?? '',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_str(data['date']) case final date?)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 13,
                          color: scheme.mutedForeground,
                        ),
                        const SizedBox(width: 4),
                        Text(date, style: theme.textTheme.labelSmall),
                      ],
                    ),
                ],
              ),
              if (_str(data['body']) case final body?)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(body, style: theme.textTheme.bodyMedium),
                ),
              if (url != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InkWell(
                    onTap: () => _open(context, url),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _str(data['linkLabel']) ?? 'Read more',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 14,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                 Assignment                                  */
/* -------------------------------------------------------------------------- */

class AssignmentBlock extends StatelessWidget {
  const AssignmentBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final instructions = _strings(data['instructions']);
    final points = _int(data['points']);
    final url = _str(data['url']);

    return _Block(
      decorated: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _str(data['title']) ?? 'Assignment',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                children: [
                  if (_str(data['due']) case final due?)
                    _Pill('Due $due', shade: TwColors.amber),
                  if (points != null) _Pill('$points marks'),
                ],
              ),
            ],
          ),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final step in instructions)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_circle_outline_rounded,
                        size: 15,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(step, style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
          ],
          if (url != null) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'Submit',
              size: AppButtonSize.sm,
              onPressed: () => _open(context, url),
            ),
          ],
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                               Code playground                               */
/* -------------------------------------------------------------------------- */

/// The same provider map the web uses in `PLAYGROUND_SRC`.
const Map<String, String> _playgroundBase = {
  'codesandbox': 'https://codesandbox.io/embed/',
  'stackblitz': 'https://stackblitz.com/edit/',
  'codepen': 'https://codepen.io/pen/embed/',
};

class PlaygroundBlock extends StatelessWidget {
  const PlaygroundBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final provider = _str(data['provider'])?.toLowerCase();
    final id = _str(data['id']);
    final base = _playgroundBase[provider ?? ''];
    if (base == null || id == null) return const SizedBox.shrink();

    final url = provider == 'stackblitz' ? '$base$id?embed=1' : '$base$id';

    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_str(data['title']) case final title?) _BlockHeading(title),
          WebFrame(
            url: url,
            height: (_int(data['height']) ?? 420).toDouble(),
          ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                 Flashcards                                  */
/* -------------------------------------------------------------------------- */

class FlashcardsBlock extends StatelessWidget {
  const FlashcardsBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final cards = _objects(data['cards']);
    if (cards.isEmpty) return const SizedBox.shrink();

    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final card in cards)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Flashcard(
                front: _str(card['front']) ?? '',
                back: _str(card['back']) ?? '',
              ),
            ),
        ],
      ),
    );
  }
}

class _Flashcard extends StatefulWidget {
  const _Flashcard({required this.front, required this.back});

  final String front;
  final String back;

  @override
  State<_Flashcard> createState() => _FlashcardState();
}

class _FlashcardState extends State<_Flashcard> {
  bool _flipped = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return InkWell(
      onTap: () => setState(() => _flipped = !_flipped),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: scheme.border.withValues(alpha: 0.7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                _flipped ? widget.back : widget.front,
                key: ValueKey(_flipped),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.refresh_rounded,
                    size: 13,
                    color: scheme.mutedForeground,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _flipped ? 'Show question' : 'Show answer',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                    Tabs                                     */
/* -------------------------------------------------------------------------- */

class TabsBlock extends StatefulWidget {
  const TabsBlock({super.key, required this.data, required this.renderContent});

  final Map<String, dynamic> data;
  final MarkdownChildBuilder renderContent;

  @override
  State<TabsBlock> createState() => _TabsBlockState();
}

class _TabsBlockState extends State<TabsBlock> {
  int _active = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final tabs = _objects(widget.data['tabs']);
    if (tabs.isEmpty) return const SizedBox.shrink();

    final active = _active.clamp(0, tabs.length - 1);

    return _Block(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: scheme.border.withValues(alpha: 0.7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: scheme.muted,
              padding: const EdgeInsets.all(6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: InkWell(
                          onTap: () => setState(() => _active = i),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: i == active ? scheme.card : null,
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              _str(tabs[i]['label']) ?? 'Tab ${i + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: i == active
                                    ? scheme.foreground
                                    : scheme.mutedForeground,
                                fontWeight: i == active
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: widget.renderContent(_str(tabs[active]['content']) ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                    Cards                                    */
/* -------------------------------------------------------------------------- */

class CardsGrid extends StatelessWidget {
  const CardsGrid({super.key, required this.cards});

  final List<Map<String, dynamic>> cards;

  @override
  Widget build(BuildContext context) => _Block(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final card in cards)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _MarkdownCard(card: card),
              ),
          ],
        ),
      );
}

class _MarkdownCard extends StatelessWidget {
  const _MarkdownCard({required this.card});

  final Map<String, dynamic> card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final url = _str(card['url']);
    final image = _str(card['image']);
    final icon = _str(card['icon']);
    final badge = _str(card['badge']);

    return InkWell(
      onTap: url == null ? null : () => _open(context, url),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.muted.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: image,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => ColoredBox(color: scheme.muted),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (icon != null || badge != null) ...[
                    Row(
                      children: [
                        if (icon != null) ...[
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                            ),
                            child: Text(
                              icon,
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (badge != null) _Pill(badge),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_str(card['title']) case final title?)
                    Text(title, style: theme.textTheme.titleSmall),
                  if (_str(card['description']) case final description?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        description,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (url != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Text(
                            _str(card['button']) ?? 'Learn more',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: scheme.primary,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                    Stats                                    */
/* -------------------------------------------------------------------------- */

class StatsBlock extends StatelessWidget {
  const StatsBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final items = _objects(data['items']);
    if (items.isEmpty) return const SizedBox.shrink();

    return _Block(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Two across on a phone, matching `sm:grid-cols-2` as the narrowest
          // breakpoint the web grid settles on.
          final columns = constraints.maxWidth > 520 ? 3 : 2;
          const gap = 8.0;
          final width =
              (constraints.maxWidth - gap * (columns - 1)) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: scheme.border.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _str(item['value']) ?? '',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _str(item['label']) ?? '',
                          style: theme.textTheme.labelMedium,
                        ),
                        if (_str(item['hint']) case final hint?)
                          Text(hint, style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                     FAQ                                     */
/* -------------------------------------------------------------------------- */

class FaqBlock extends StatelessWidget {
  const FaqBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _objects(data['items']);
    if (items.isEmpty) return const SizedBox.shrink();

    return _Block(
      decorated: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            _Disclosure(
              title: _str(items[i]['question']) ?? '',
              divided: i != items.length - 1,
              child: Text(
                _str(items[i]['answer']) ?? '',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// The shared collapsible row behind the FAQ and accordion blocks, and behind
/// a raw `<details>` element lifted out of the source.
class _Disclosure extends StatefulWidget {
  const _Disclosure({
    required this.title,
    required this.child,
    this.divided = false,
    this.initiallyOpen = false,
  });

  final String title;
  final Widget child;
  final bool divided;
  final bool initiallyOpen;

  @override
  State<_Disclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<_Disclosure> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      decoration: widget.divided
          ? BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: scheme.border.withValues(alpha: 0.7),
                ),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: _open ? 0.25 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: scheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                    Alert                                    */
/* -------------------------------------------------------------------------- */

class AlertBlock extends StatelessWidget {
  const AlertBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    // The four web tones map straight onto the app's own status tones.
    final (tone, icon) = switch (_str(data['variant'])?.toLowerCase()) {
      'success' => (tokens.success, Icons.check_circle_outline_rounded),
      'warning' => (tokens.warning, Icons.warning_amber_rounded),
      'danger' => (tokens.danger, Icons.error_outline_rounded),
      _ => (tokens.info, Icons.info_outline_rounded),
    };

    final title = _str(data['title']);

    return _Block(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: tone.foreground.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 17, color: tone.foreground),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null)
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tone.foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(top: title != null ? 2 : 0),
                    child: Text(
                      _str(data['body']) ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: tone.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                   Button                                    */
/* -------------------------------------------------------------------------- */

class ButtonBlock extends StatelessWidget {
  const ButtonBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final label = _str(data['label']);
    final url = _str(data['url']);
    if (label == null || url == null) return const SizedBox.shrink();

    final alignment = switch (_str(data['align'])) {
      'center' => Alignment.center,
      'right' => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };

    return _Block(
      child: Align(
        alignment: alignment,
        child: AppButton(
          label: label,
          variant: _str(data['variant']) == 'outline'
              ? AppButtonVariant.outline
              : AppButtonVariant.primary,
          onPressed: () => _open(context, url),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                   Gallery                                   */
/* -------------------------------------------------------------------------- */

class GalleryBlock extends StatelessWidget {
  const GalleryBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final images = _objects(data['images']);
    if (images.isEmpty) return const SizedBox.shrink();

    // The web accepts 2, 3, or 4 and defaults to 3. Four thumbnails across a
    // phone are unreadable, so a declared 4 is capped to 3 rather than ignored.
    final declared = _int(data['columns']);
    final columns = (declared == 2 || declared == 4 ? declared! : 3).clamp(2, 3);

    return _Block(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 8.0;
          final width =
              (constraints.maxWidth - gap * (columns - 1)) / columns;

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final image in images)
                SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _openLightbox(
                          context,
                          _str(image['src']),
                          _str(image['alt']),
                        ),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: CachedNetworkImage(
                              imageUrl: _str(image['src']) ?? '',
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => ColoredBox(
                                color: scheme.muted,
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  size: 18,
                                  color: scheme.mutedForeground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_str(image['caption']) case final caption?)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            caption,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _openLightbox(BuildContext context, String? src, String? alt) {
    if (src == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _Lightbox(src: src, alt: alt),
      ),
    );
  }
}

class _Lightbox extends StatelessWidget {
  const _Lightbox({required this.src, this.alt});

  final String src;
  final String? alt;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(alt ?? 'Image'),
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: CachedNetworkImage(imageUrl: src),
          ),
        ),
      );
}

/* -------------------------------------------------------------------------- */
/*                                     PDF                                     */
/* -------------------------------------------------------------------------- */

class PdfBlock extends StatelessWidget {
  const PdfBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final src = _str(data['src']);
    if (src == null) return const SizedBox.shrink();

    final title = _str(data['title']) ?? 'Document';

    return _Block(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: scheme.border.withValues(alpha: 0.7)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: scheme.muted,
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 15,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.labelMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Kept alongside the inline pane: the Android viewer only
                  // works for a publicly reachable URL, so there must always be
                  // a way out to a real PDF app.
                  TextButton.icon(
                    onPressed: () => _open(context, src),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: scheme.mutedForeground,
                      textStyle: const TextStyle(fontSize: 11),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 13),
                    label: const Text('Open'),
                  ),
                ],
              ),
            ),
            WebFrame(
              url: pdfFrameUrl(src),
              height: (_int(data['height']) ?? 480).toDouble(),
              background: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                   YouTube                                   */
/* -------------------------------------------------------------------------- */

/// Accepts a bare id or any of the usual watch/share/embed URLs — the port of
/// `youtubeId` in `markdown-blocks.tsx`.
String youtubeId(String raw) {
  final match = RegExp(r'(?:youtu\.be/|v=|/embed/|/shorts/)([A-Za-z0-9_-]{11})')
      .firstMatch(raw);
  return match?.group(1) ?? raw;
}

class YouTubeBlock extends StatelessWidget {
  const YouTubeBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final raw = _str(data['id']);
    if (raw == null) return const SizedBox.shrink();

    final id = youtubeId(raw);
    final start = _int(data['start']);
    // Handed to `VideoPreview` as a watch URL so its own parser normalises it
    // to the embed player — one code path for every video in the app.
    final url = 'https://www.youtube.com/watch?v=$id'
        '${start != null && start > 0 ? '&start=$start' : ''}';

    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VideoPreview(url: url),
          if (_str(data['title']) case final title?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                  LeetCode                                   */
/* -------------------------------------------------------------------------- */

class LeetCodeBlock extends StatelessWidget {
  const LeetCodeBlock({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final slug = _str(data['slug']);
    if (slug == null) return const SizedBox.shrink();

    final difficulty = _str(data['difficulty']);
    final topics = _strings(data['topics']);

    return _Block(
      child: InkWell(
        onTap: () => _open(context, 'https://leetcode.com/problems/$slug/'),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: scheme.border.withValues(alpha: 0.7)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          _str(data['title']) ?? slug,
                          style: theme.textTheme.titleSmall,
                        ),
                        if (difficulty != null)
                          // `statusShade` already maps easy/medium/hard onto
                          // teal/amber/red, so the pill needs no local table.
                          AppBadge(
                            difficulty,
                            shade: AppBadge.statusShade(difficulty),
                            dense: true,
                          ),
                      ],
                    ),
                    if (topics.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          topics.join(' · '),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.open_in_new_rounded,
                size: 15,
                color: scheme.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                   Mermaid                                   */
/* -------------------------------------------------------------------------- */

/// Renders a mermaid diagram in a WebView.
///
/// There is no Dart mermaid implementation, so the grammar is handed to the
/// real library. It is loaded from a CDN rather than bundled — the module is
/// ~1MB, the same reason the web app imports it lazily — which means a diagram
/// needs network the first time it is shown.
class MermaidBlock extends StatefulWidget {
  const MermaidBlock({super.key, required this.source});

  final String source;

  @override
  State<MermaidBlock> createState() => _MermaidBlockState();
}

class _MermaidBlockState extends State<MermaidBlock> {
  double _height = 200;
  bool _failed = false;

  void _onMessage(String channel, String message) {
    if (!mounted) return;
    if (channel == 'MermaidFail') {
      setState(() => _failed = true);
      return;
    }
    final measured = double.tryParse(message);
    if (measured != null && measured > 0) {
      setState(() => _height = measured.clamp(80, 900));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final scheme = tokens.scheme;

    if (_failed) {
      return _Block(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.muted,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Text(
            'This diagram could not be rendered. Check the mermaid syntax.',
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    return _Block(
      child: WebFrame(
        // Keyed on the theme so a light/dark switch re-renders the diagram with
        // the matching mermaid theme instead of leaving stale colours.
        key: ValueKey('mermaid-${tokens.isDark}-${widget.source.hashCode}'),
        html: _document(tokens.isDark, scheme.background, scheme.foreground),
        baseUrl: 'https://cdn.jsdelivr.net',
        height: _height,
        channels: const {'MermaidHeight', 'MermaidFail'},
        onMessage: _onMessage,
      ),
    );
  }

  String _document(bool isDark, Color background, Color foreground) {
    // Encoded as JSON so quotes, backslashes and newlines in the diagram
    // survive being embedded in the script.
    final source = jsonEncode(widget.source);
    final css = _hex(background);

    return '''
<!doctype html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
      html, body { margin: 0; padding: 8px; background: $css; }
      #diagram { display: flex; justify-content: center; overflow-x: auto; }
      svg { max-width: 100%; height: auto; }
    </style>
  </head>
  <body>
    <div id="diagram"></div>
    <script type="module">
      const report = () => MermaidHeight.postMessage(
        String(document.documentElement.scrollHeight)
      );
      try {
        const { default: mermaid } = await import(
          'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs'
        );
        mermaid.initialize({
          startOnLoad: false,
          theme: '${isDark ? 'dark' : 'neutral'}',
          securityLevel: 'strict',
        });
        const { svg } = await mermaid.render('diagram-svg', $source);
        document.getElementById('diagram').innerHTML = svg;
        report();
      } catch (error) {
        MermaidFail.postMessage(String(error));
      }
    </script>
  </body>
</html>
''';
  }

  String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}

/* -------------------------------------------------------------------------- */
/*                                  Accordion                                  */
/* -------------------------------------------------------------------------- */

class AccordionBlock extends StatelessWidget {
  const AccordionBlock({
    super.key,
    required this.data,
    required this.renderContent,
  });

  final Map<String, dynamic> data;
  final MarkdownChildBuilder renderContent;

  @override
  Widget build(BuildContext context) {
    final items = _objects(data['items']);
    if (items.isEmpty) return const SizedBox.shrink();

    return _Block(
      decorated: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++)
            _Disclosure(
              title: _str(items[i]['title']) ?? '',
              divided: i != items.length - 1,
              initiallyOpen: _bool(items[i]['open']),
              child: renderContent(_str(items[i]['content']) ?? ''),
            ),
        ],
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                          Raw `<details>` from source                        */
/* -------------------------------------------------------------------------- */

/// Renders a `<details>` element the parser lifted out of the markdown.
/// `flutter_markdown` drops raw HTML, so without this the whole element — and
/// everything inside it — would silently vanish.
class DetailsBlock extends StatelessWidget {
  const DetailsBlock({
    super.key,
    required this.title,
    required this.body,
    required this.open,
    required this.renderContent,
  });

  final String title;
  final String body;
  final bool open;
  final MarkdownChildBuilder renderContent;

  @override
  Widget build(BuildContext context) => _Block(
        decorated: true,
        padding: EdgeInsets.zero,
        child: _Disclosure(
          title: title,
          initiallyOpen: open,
          child: renderContent(body),
        ),
      );
}
