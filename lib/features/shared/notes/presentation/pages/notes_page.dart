import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/design/extensions/glass_context.dart';
import '../../../../../core/network/api_response.dart';
import '../../../shell/presentation/pages/app_shell.dart';
import '../../../shell/presentation/widgets/student_nav.dart';
import '../../domain/entities/note.dart';
import '../../domain/usecases/notes_usecases.dart';
import '../bloc/my_notes_stats_cubit.dart';
import '../bloc/notes_hub_cubit.dart';
import '../widgets/note_card.dart';
import '../widgets/note_composer_sheet.dart';
import '../widgets/notes_stats_row.dart';

/// Port of `src/components/notes/notes-list-page.tsx`.
///
/// The three tabs are the same list under a different server filter, so they
/// are filter chips over one feed rather than a `TabBar` — a `TabBar` would
/// promise three independently scrolling surfaces and force the shared search
/// and filter row outside them.
class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _filterDraft = ValueNotifier(const _NoteFilters());

  /// Bumped to remount the search field — it builds its controller once and
  /// never re-reads `initialValue`, so clearing the query would otherwise leave
  /// dead text in a field that no longer filters anything.
  int _searchEpoch = 0;

  @override
  void initState() {
    super.initState();
    context.read<NotesHubCubit>().load();
  }

  @override
  void dispose() {
    _filterDraft.dispose();
    super.dispose();
  }

  Future<void> _apply(Future<void> Function() change) async {
    await change();
    if (mounted) setState(() {});
  }

  /// The stats endpoint is only worth calling once the student is looking at
  /// their own notes.
  void _ensureStats() {
    final stats = context.read<MyNotesStatsCubit>();
    if (stats.state.data == null) stats.load();
  }

  Future<void> _setTab(NotesHubCubit cubit, NotesTab tab) async {
    await _apply(() => cubit.setTab(tab));
    if (tab == NotesTab.mine && mounted) _ensureStats();
  }

  Future<void> _openFilters(NotesHubCubit cubit) async {
    _filterDraft.value = _NoteFilters(
      sort: cubit.query.sort,
      visibility: cubit.query.visibility,
    );

    final applied = await showAppSheet<_NoteFilters>(
      context,
      title: 'Filters',
      builder: (context) => _FilterSheet(
        draft: _filterDraft,
        // Access only narrows your own notes; elsewhere the server already
        // hides everyone else's private ones.
        showVisibility: cubit.tab == NotesTab.mine,
      ),
    );
    if (applied == null || !mounted) return;

    await _apply(() async {
      await cubit.setSort(applied.sort);
      await cubit.setVisibility(applied.visibility);
    });
  }

  Future<void> _clearFilters(NotesHubCubit cubit) async {
    await _apply(cubit.clearFilters);
    if (mounted) setState(() => _searchEpoch++);
  }

  Future<void> _compose(NotesHubCubit cubit) async {
    String? created;

    await showNoteComposer(
      context,
      subtitle: 'Share notes, guides, or explanations with your school.',
      onSubmit: (draft) async {
        final result = await cubit.create(
          CreateNoteInput(
            title: draft.title,
            content: draft.content,
            link: const NoteLinkContext(),
            tags: draft.tags,
            visibility: draft.visibility,
          ),
        );
        return result.fold((failure) => failure, (id) {
          created = id;
          return null;
        });
      },
    );

    if (!mounted || created == null) return;
    AppToast.success(context, 'Note created.');
    await _open(cubit, created!);
  }

  /// Opens a note, then refetches.
  ///
  /// Unconditionally, and not gated on a pop result: a back-swipe returns null,
  /// and the row is stale regardless — reading a note bumps its view count for
  /// anyone but its author, and an edit, a like or a delete in there all change
  /// what the card shows.
  Future<void> _open(NotesHubCubit cubit, String id) async {
    await context.push(StudentRoutes.note(id));
    if (mounted) await _apply(() => cubit.load(refresh: true));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotesHubCubit>();
    final glassInsets = context.glassContentInsets;
    final query = cubit.query;
    final tab = cubit.tab;

    return ShellScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    dense: true,
                    key: ValueKey(_searchEpoch),
                    // Not "by title": this endpoint really does match the body.
                    hint: 'Search notes…',
                    debounce: const Duration(milliseconds: 400),
                    onChanged: (value) => _apply(() => cubit.setSearch(value)),
                  ),
                ),
                const SizedBox(width: 4),
                _FilterButton(
                  activeCount: query.visibility == null ? 0 : 1,
                  onPressed: () => _openFilters(cubit),
                ),
                IconButton(
                  tooltip: 'New note',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _compose(cubit),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: AppFilterChips<NotesTab>(
              selected: tab,
              onSelected: (value) => _setTab(cubit, value),
              options: const [
                AppFilterChipOption(value: NotesTab.all, label: 'All notes'),
                AppFilterChipOption(value: NotesTab.mine, label: 'My notes'),
                AppFilterChipOption(
                  value: NotesTab.shared,
                  label: 'Shared with me',
                ),
              ],
            ),
          ),
          if (tab == NotesTab.mine)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _StatsSlot(),
            ),
          if (query.tag case final tag?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: _TagFilterChip(
                tag: tag,
                onClear: () => _apply(() => cubit.setTag(null)),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final stats = context.read<MyNotesStatsCubit>();
                await cubit.load(refresh: true);
                if (tab == NotesTab.mine) await stats.load(refresh: true);
              },
              child: InfiniteScroll(
                onLoadMore: cubit.loadMore,
                child: BlocBuilder<NotesHubCubit,
                    RemoteState<Paginated<NoteListItem>>>(
                  builder: (context, state) => AnimatedOpacity(
                    // The web dims its grid while refetching; here it is the
                    // only sign a search did anything, since the old rows stay.
                    opacity: state.status == RemoteStatus.loading &&
                            state.data != null
                        ? 0.6
                        : 1,
                    duration: const Duration(milliseconds: 150),
                    child: RemoteView<NotesHubCubit, Paginated<NoteListItem>>(
                      onRetry: cubit.load,
                      loading: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: AppListSkeleton(rows: 3),
                      ),
                      isEmpty: (page) => page.items.isEmpty,
                      emptyTitle: _emptyTitle(tab, query),
                      emptyDescription: _emptyDescription(tab, query),
                      emptyIcon: Icons.sticky_note_2_outlined,
                      emptyAction: query.hasFilters
                          ? AppButton(
                              label: 'Clear filters',
                              variant: AppButtonVariant.outline,
                              size: AppButtonSize.sm,
                              onPressed: () => _clearFilters(cubit),
                            )
                          : null,
                      builder: (context, page) => ListView.separated(
                        // No controller: the list stays on the
                        // PrimaryScrollController so the shell's collapsing
                        // header keeps working.
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          24 + glassInsets.bottom,
                        ),
                        itemCount: page.items.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index == page.items.length) {
                            return AppLoadMoreFooter(
                              isLoading: cubit.isLoadingMore || cubit.hasMore,
                              hasMore: cubit.hasMore,
                              endLabel: 'No more notes',
                            );
                          }
                          final note = page.items[index];
                          return NoteCard(
                            // `most_liked` sorts with no id tiebreaker, so
                            // equally-liked rows can swap between pages.
                            key: ValueKey(note.id),
                            note: note,
                            onTap: () => _open(cubit, note.id),
                            onLike: () async {
                              final failure = await cubit.toggleLike(note.id);
                              if (failure != null && context.mounted) {
                                AppToast.failure(context, failure);
                              }
                            },
                            onTagTap: (tag) =>
                                _apply(() => cubit.setTag(tag)),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _emptyTitle(NotesTab tab, ListNotesParams query) {
    if (tab == NotesTab.shared) return 'No notes shared with you yet';
    if (query.hasFilters) return 'No notes match your filters';
    return 'No notes yet';
  }

  static String _emptyDescription(NotesTab tab, ListNotesParams query) {
    if (tab == NotesTab.shared) {
      return 'Notes your friends share with you will show up here.';
    }
    if (query.hasFilters) return 'Try adjusting your search or filters.';
    return 'Write the first note for your school.';
  }
}

/// The stats row, in its own builder so a stats failure shows zeroes rather
/// than an error over the feed — the web falls back the same way.
class _StatsSlot extends StatelessWidget {
  const _StatsSlot();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<MyNotesStatsCubit, RemoteState<MyNotesStats>>(
        builder: (context, state) =>
            NotesStatsRow(stats: state.data ?? MyNotesStats.empty),
      );
}

class _TagFilterChip extends StatelessWidget {
  const _TagFilterChip({required this.tag, required this.onClear});

  final String tag;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Row(
      children: [
        Text('Filtered by', style: theme.textTheme.labelSmall),
        const SizedBox(width: 8),
        InkWell(
          onTap: onClear,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#$tag',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.close_rounded, size: 14, color: scheme.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.activeCount, required this.onPressed});

  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final theme = Theme.of(context);
    final isActive = activeCount > 0;

    return IconButton(
      tooltip: isActive ? 'Filters ($activeCount applied)' : 'Filters',
      onPressed: onPressed,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.tune_rounded,
            color: isActive ? scheme.primary : null,
          ),
          if (isActive)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                width: 15,
                height: 15,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$activeCount',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primaryForeground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

@immutable
class _NoteFilters {
  const _NoteFilters({this.sort = 'recent', this.visibility});

  final String sort;
  final String? visibility;
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.draft, required this.showVisibility});

  final ValueNotifier<_NoteFilters> draft;
  final bool showVisibility;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_NoteFilters>(
      valueListenable: draft,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppOptionGroup<String>(
            header: 'Sort',
            selected: value.sort,
            onSelected: (sort) =>
                draft.value = _NoteFilters(sort: sort, visibility: value.visibility),
            options: [
              for (final sort in NoteMeta.sorts)
                AppOptionItem(
                  value: sort,
                  label: NoteMeta.sortLabel(sort),
                  icon: switch (sort) {
                    'most_liked' => Icons.favorite_border_rounded,
                    'oldest' => Icons.history_rounded,
                    _ => Icons.schedule_rounded,
                  },
                ),
            ],
          ),
          if (showVisibility)
            AppOptionGroup<String?>(
              header: 'Access',
              selected: value.visibility,
              onSelected: (visibility) => draft.value =
                  _NoteFilters(sort: value.sort, visibility: visibility),
              options: const [
                AppOptionItem(
                  value: null,
                  label: 'All access',
                  icon: Icons.apps_rounded,
                ),
                AppOptionItem(
                  value: 'private',
                  label: 'Private',
                  icon: Icons.lock_outline_rounded,
                ),
                AppOptionItem(
                  value: 'published',
                  label: 'Published',
                  icon: Icons.public_rounded,
                ),
              ],
            ),
          AppFilterActions(
            onReset: value.sort == 'recent' && value.visibility == null
                ? null
                : () => draft.value = const _NoteFilters(),
            onApply: () => Navigator.of(context).pop(value),
          ),
        ],
      ),
    );
  }
}
