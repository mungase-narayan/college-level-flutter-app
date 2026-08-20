import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../shared/shell/presentation/pages/app_shell.dart';
import '../../domain/entities/badge.dart';
import '../bloc/badges_cubit.dart';
import '../widgets/badge_category_section.dart';
import '../widgets/badges_progress_hero.dart';

/// Port of `src/pages/student/practice/badges.tsx`.
///
/// One fetch, no filters, no search, no pagination and no detail view. Badges
/// are awarded server-side after each solve, so the client only ever reads.
///
/// It does **not** use [RemoteView], which swaps the whole subtree for its
/// loading and error states. The hero has to outlive both: on the web it sits
/// above the loading branch and renders its own zero state ("Earn badges by
/// practicing consistently.", no bar) rather than vanishing, and keeping it
/// through a failure too means a dead network doesn't blank the screen.
class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  @override
  void initState() {
    super.initState();
    context.read<BadgesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BadgesCubit>();

    return ShellScaffold(
      child: BlocBuilder<BadgesCubit, RemoteState<BadgeCollection>>(
        builder: (context, state) {
          // Null only before the first response lands, and an empty collection
          // is exactly the zero state the hero should show then.
          final badges = state.data ?? const BadgeCollection();
          final failure = state.failure;

          // RefreshableScroll carries its own RefreshIndicator and folds in the
          // iOS glass insets.
          return RefreshableScroll(
            onRefresh: () => cubit.load(refresh: true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BadgesProgressHero(badges: badges),
                const SizedBox(height: 20),
                if (state.isInitialLoading)
                  const _Skeleton()
                else if (state.status == RemoteStatus.failure &&
                    failure != null)
                  AppErrorView(failure: failure, onRetry: cubit.load)
                else
                  // Catalog order is section order — monthly, yearly, accuracy,
                  // streak, daily challenge — and `grouped` preserves it, so
                  // nothing here re-sorts. An empty catalog leaves the hero's
                  // fallback copy alone on screen, as the web does; there is no
                  // separate empty state.
                  for (final group in badges.grouped.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: BadgeCategorySection(
                        category: group.key,
                        definitions: group.value,
                        badges: badges,
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSkeleton(height: 128, radius: AppTheme.radiusLg),
          SizedBox(height: 14),
          AppSkeleton(height: 128, radius: AppTheme.radiusLg),
        ],
      );
}
