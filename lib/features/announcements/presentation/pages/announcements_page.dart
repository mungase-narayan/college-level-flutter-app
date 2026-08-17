import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/extensions/glass_context.dart';
import '../../../../core/network/api_response.dart';
import '../../../shell/presentation/pages/student_shell.dart';
import '../../../shell/presentation/widgets/student_nav.dart';
import '../../domain/entities/announcement.dart';
import '../bloc/announcements_cubit.dart';
import '../widgets/announcement_card.dart';

/// Port of `src/pages/student/announcements/index.tsx`.
///
/// The web lays this out as a responsive card grid and — because `page` is
/// pinned at 1 with `limit: 24` and nothing ever advances it — cannot show a
/// twenty-fifth announcement at all. Here it is one column with infinite scroll,
/// matching the app's other feeds and reaching the whole archive.
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final _filterDraft = ValueNotifier<String?>(null);

  /// Bumped to remount the search field.
  ///
  /// `AppSearchField` builds its controller once in `createState` and never
  /// re-reads `initialValue`, so clearing the cubit's query would otherwise
  /// leave the typed text sitting in a field that no longer filters anything.
  int _searchEpoch = 0;

  @override
  void initState() {
    super.initState();
    context.read<AnnouncementsCubit>().load();
  }

  @override
  void dispose() {
    _filterDraft.dispose();
    super.dispose();
  }

  /// Runs a query change, then rebuilds — the filter badge and the empty copy
  /// read off `cubit.query`, which is deliberately not part of the state.
  Future<void> _apply(Future<void> Function() change) async {
    await change();
    if (mounted) setState(() {});
  }

  Future<void> _openFilters(AnnouncementsCubit cubit) async {
    _filterDraft.value = cubit.query.type;

    final applied = await showAppSheet<_TypeChoice>(
      context,
      title: 'Filters',
      builder: (context) => _FilterSheet(draft: _filterDraft),
    );
    if (applied == null || !mounted) return;

    await _apply(() => cubit.setType(applied.type));
  }

  Future<void> _clearFilters(AnnouncementsCubit cubit) async {
    await _apply(cubit.clearFilters);
    if (mounted) setState(() => _searchEpoch++);
  }

  void _open(Announcement announcement) =>
      context.push(StudentRoutes.announcement(announcement.id));

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AnnouncementsCubit>();
    final glassInsets = context.glassContentInsets;
    final hasFilters = cubit.query.hasFilters;

    return StudentScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    key: ValueKey(_searchEpoch),
                    // Named honestly: the server matches the title only, so
                    // "Search announcements" would promise a body search that
                    // silently returns nothing.
                    hint: 'Search by title',
                    // The web's SearchInput waits 400ms; the app default is 350.
                    debounce: const Duration(milliseconds: 400),
                    onChanged: (value) => _apply(() => cubit.setSearch(value)),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterButton(
                  activeCount: cubit.query.type == null ? 0 : 1,
                  onPressed: () => _openFilters(cubit),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => cubit.load(refresh: true),
              child: InfiniteScroll(
                onLoadMore: cubit.loadMore,
                child: BlocBuilder<AnnouncementsCubit,
                    RemoteState<Paginated<Announcement>>>(
                  builder: (context, state) => AnimatedOpacity(
                    // The web dims its grid while refetching. It matters more
                    // here: a search keeps the previous rows on screen, so
                    // without this the field gives no sign anything happened.
                    opacity: state.status == RemoteStatus.loading &&
                            state.data != null
                        ? 0.6
                        : 1,
                    duration: const Duration(milliseconds: 150),
                    child: RemoteView<AnnouncementsCubit,
                        Paginated<Announcement>>(
                      onRetry: cubit.load,
                      loading: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _CardSkeletons(),
                      ),
                      isEmpty: (page) => page.items.isEmpty,
                      emptyTitle: hasFilters
                          ? 'No announcements match your filters'
                          : 'No announcements yet',
                      emptyDescription: hasFilters
                          ? 'Search matches titles only. Try a different word '
                              'or clear the type filter.'
                          : 'Notices from your college will appear here.',
                      emptyIcon: Icons.campaign_outlined,
                      emptyAction: hasFilters
                          ? AppButton(
                              label: 'Clear filters',
                              variant: AppButtonVariant.outline,
                              size: AppButtonSize.sm,
                              onPressed: () => _clearFilters(cubit),
                            )
                          : null,
                      builder: (context, page) => ListView.separated(
                        // No controller: the list must stay on the
                        // PrimaryScrollController so it coordinates with the
                        // shell's collapsing header.
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
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
                              endLabel: 'No more announcements',
                            );
                          }
                          final announcement = page.items[index];
                          return AnnouncementCard(
                            // The feed sorts by priority then publishedAt with
                            // no id tiebreaker, so same-priority rows can shift
                            // between pages; keying by id keeps Flutter from
                            // recycling the wrong card.
                            key: ValueKey(announcement.id),
                            announcement: announcement,
                            onTap: () => _open(announcement),
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
}

/// Card-shaped placeholders.
///
/// Not `AppListSkeleton`, whose text-line rows are a different height from an
/// image-led card — the list would jump as the real data landed.
class _CardSkeletons extends StatelessWidget {
  const _CardSkeletons();

  /// Three, not the web's eight — a phone fits about two.
  static const _count = 3;

  // A list rather than a Column: three card-height placeholders are taller than
  // a phone's viewport, and a Column would overflow instead of clipping.
  @override
  Widget build(BuildContext context) => ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: _count,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: AppSkeleton(height: 300, radius: AppTheme.radiusLg),
        ),
      );
}

/// The filter entry point: an icon that carries a count when a type is chosen.
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

/// Wraps the chosen type so `null` can mean "All types" rather than "dismissed".
@immutable
class _TypeChoice {
  const _TypeChoice(this.type);

  final String? type;
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.draft});

  final ValueNotifier<String?> draft;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: draft,
      builder: (context, value, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppOptionGroup<String?>(
            header: 'Type',
            selected: value,
            onSelected: (type) => draft.value = type,
            options: [
              const AppOptionItem(
                value: null,
                label: 'All types',
                icon: Icons.apps_rounded,
              ),
              for (final type in AnnouncementMeta.types)
                AppOptionItem(
                  value: type,
                  label: AnnouncementMeta.typeLabel(type),
                  icon: AnnouncementMeta.typeIcon(type),
                ),
            ],
          ),
          AppFilterActions(
            onReset: value == null ? null : () => draft.value = null,
            onApply: () => Navigator.of(context).pop(_TypeChoice(value)),
          ),
        ],
      ),
    );
  }
}
