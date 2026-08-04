import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../design/extensions/glass_context.dart';
import '../bloc/remote_cubit.dart';
import 'app_states.dart';

/// Renders the four states of a [RemoteCubit] — initial load, failure, empty,
/// and loaded — so screens describe only the loaded case.
class RemoteView<C extends Cubit<RemoteState<T>>, T> extends StatelessWidget {
  const RemoteView({
    super.key,
    required this.builder,
    this.onRetry,
    this.loading,
    this.isEmpty,
    this.emptyTitle = 'Nothing here yet',
    this.emptyDescription,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyAction,
  });

  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;

  /// Shown during the first load. Defaults to a spinner; pass a skeleton for a
  /// list screen.
  final Widget? loading;

  /// Lets the caller decide what "empty" means for its own data shape.
  final bool Function(T data)? isEmpty;
  final String emptyTitle;
  final String? emptyDescription;
  final IconData emptyIcon;
  final Widget? emptyAction;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<C, RemoteState<T>>(
      builder: (context, state) {
        final data = state.data;

        // Keep showing stale data during a background refresh rather than
        // flashing a spinner over content the user is already reading.
        if (data == null) {
          if (state.status == RemoteStatus.failure && state.failure != null) {
            return AppErrorView(failure: state.failure!, onRetry: onRetry);
          }
          if (state.isInitialLoading || state.status == RemoteStatus.initial) {
            return loading ?? const AppLoader();
          }
          return AppEmptyState(
            title: emptyTitle,
            description: emptyDescription,
            icon: emptyIcon,
            action: emptyAction,
          );
        }

        if (isEmpty?.call(data) ?? false) {
          return AppEmptyState(
            title: emptyTitle,
            description: emptyDescription,
            icon: emptyIcon,
            action: emptyAction,
          );
        }

        return builder(context, data);
      },
    );
  }
}

/// Wraps a scrollable in pull-to-refresh.
///
/// The child must be scrollable and always scrollable (use
/// `AlwaysScrollableScrollPhysics`) or the gesture won't fire on short content.
class RefreshableScroll extends StatelessWidget {
  const RefreshableScroll({
    super.key,
    required this.onRefresh,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 28),
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        // On iOS this adds clearance for the floating app bar and nav capsule so
        // content scrolls *under* them while staying fully reachable.
        // `EdgeInsets.zero` everywhere else, so Android's layout is unchanged.
        padding: padding.add(context.glassContentInsets),
        child: child,
      ),
    );
  }
}

/// Calls [onLoadMore] when the user scrolls near the bottom — the infinite
/// scroll used by every paginated list in this app.
///
/// Listens to [ScrollNotification]s rather than owning a [ScrollController].
/// That is not a stylistic choice: a list with its own controller opts out of the
/// [PrimaryScrollController] that [NestedScrollView] hands down, so it would stop
/// coordinating with the shell's collapsing header and the header would never
/// hide on this screen. Notifications leave the list on the primary controller.
class InfiniteScroll extends StatelessWidget {
  const InfiniteScroll({
    super.key,
    required this.onLoadMore,
    required this.child,
    this.threshold = 320,
  });

  final VoidCallback onLoadMore;
  final Widget child;

  /// How close to the bottom (in pixels) triggers the next page.
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Depth 0 and vertical only: the filter chip strip scrolls horizontally
        // and must not be mistaken for the list reaching its end.
        if (notification.depth != 0) return false;
        final metrics = notification.metrics;
        if (metrics.axis != Axis.vertical) return false;

        if (metrics.pixels >= metrics.maxScrollExtent - threshold) {
          // The cubit itself guards against re-entrancy and the end of the list.
          onLoadMore();
        }
        return false;
      },
      child: child,
    );
  }
}
