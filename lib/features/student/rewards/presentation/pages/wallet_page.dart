import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/design/extensions/glass_context.dart';
import '../../../../../core/network/api_response.dart';
import '../../../../shared/shell/presentation/pages/app_shell.dart';
import '../../domain/entities/rewards.dart';
import '../bloc/order_chat_cubit.dart';
import '../bloc/store_cubit.dart';
import '../bloc/wallet_cubit.dart';
import '../widgets/earn_method_card.dart';
import '../widgets/order_chat_sheet.dart';
import '../widgets/order_row.dart';
import '../widgets/product_card.dart';
import '../widgets/transaction_row.dart';
import '../widgets/wallet_hero.dart';

/// The four panels of the wallet hub.
enum WalletTab {
  wallet('wallet', 'Wallet'),
  earn('earn', 'Earn Points'),
  store('store', 'Store'),
  orders('orders', 'Orders');

  const WalletTab(this.key, this.label);

  final String key;
  final String label;

  /// Resolves the `?tab=` deep link notifications use. Anything unrecognised —
  /// including null — falls back to the ledger, exactly as the web does.
  static WalletTab fromQuery(String? value) => WalletTab.values.firstWhere(
        (tab) => tab.key == value,
        orElse: () => WalletTab.wallet,
      );
}

/// Port of `src/pages/student/rewards/wallet.tsx`.
///
/// A persistent balance hero over four panels. The hero deliberately sits
/// outside every loading and error branch — it is the screen's identity, and
/// the web keeps it up through both.
///
/// The tabs are chips rather than a [TabBar]: a `TabBarView` would give each
/// panel its own scrollable, which fights [InfiniteScroll]'s reliance on the
/// `PrimaryScrollController` and the shell's collapsing header. The web's own
/// tab bar is a rounded pill strip, so chips are also the closer visual match.
class WalletPage extends StatefulWidget {
  const WalletPage({
    super.key,
    required this.createChatCubit,
    this.initialTab = WalletTab.wallet,
  });

  /// Builds the chat cubit for one order. Injected rather than resolved here so
  /// the service locator stays confined to the router, as it is for every other
  /// screen — and so tests can hand in a stub.
  final OrderChatCubit Function(String orderId) createChatCubit;

  final WalletTab initialTab;

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late WalletTab _tab = widget.initialTab;

  @override
  void initState() {
    super.initState();
    // The hero is on every tab, so the wallet always loads; the rest wait until
    // their tab is first opened.
    context.read<WalletCubit>().load();
    _ensureTabLoaded(_tab);
  }

  /// Loads a tab's data the first time it is shown, and not again — the same
  /// idiom `NotesPage` uses for its stats cubit.
  void _ensureTabLoaded(WalletTab tab) {
    switch (tab) {
      case WalletTab.wallet:
        final cubit = context.read<WalletTransactionsCubit>();
        if (cubit.state.data == null) cubit.load();
      case WalletTab.store:
        final cubit = context.read<StoreCubit>();
        if (cubit.state.data == null) cubit.load();
      case WalletTab.orders:
        final cubit = context.read<OrdersCubit>();
        if (cubit.state.data == null) cubit.load();
      case WalletTab.earn:
        break; // Static content, no endpoint.
    }
  }

  void _selectTab(WalletTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _ensureTabLoaded(tab);
  }

  /// A purchase moves points the hero, ledger and orders all display. The web
  /// invalidates its whole `rewards` query tree; here the page refreshes its
  /// siblings directly.
  Future<void> _refreshAfterPurchase() async {
    await Future.wait([
      context.read<WalletCubit>().load(refresh: true),
      context.read<WalletTransactionsCubit>().load(refresh: true),
      context.read<OrdersCubit>().load(refresh: true),
    ]);
  }

  Future<void> _redeem(Product product) async {
    final store = context.read<StoreCubit>();
    final balance = store.state.data?.wallet.balance ?? 0;

    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Redeem "${product.title}"?',
      message: 'This will spend ${product.price} points. '
          'You have $balance points.',
      confirmLabel: 'Redeem',
    );
    if (!confirmed || !mounted) return;

    final failure = await store.purchase(product.id);
    if (!mounted) return;

    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, 'Purchase successful.');
    await _refreshAfterPurchase();
  }

  Future<void> _openChat(RewardOrder order) async {
    await showOrderChatSheet(
      context,
      order: order,
      createCubit: () => widget.createChatCubit(order.id),
    );
    if (!mounted) return;
    // Reading the thread clears the unread badge server-side, so the list has
    // to come back for the badge to disappear.
    await context.read<OrdersCubit>().load(refresh: true);
  }

  Future<void> _refreshCurrentTab() async {
    await context.read<WalletCubit>().load(refresh: true);
    if (!mounted) return;
    switch (_tab) {
      case WalletTab.wallet:
        await context.read<WalletTransactionsCubit>().load(refresh: true);
      case WalletTab.store:
        await context.read<StoreCubit>().load(refresh: true);
      case WalletTab.orders:
        await context.read<OrdersCubit>().load(refresh: true);
      case WalletTab.earn:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShellScaffold(
      child: Column(
        children: [
          BlocBuilder<WalletCubit, RemoteState<Wallet>>(
            builder: (context, state) => WalletHero(
              wallet: state.data,
              isLoading: state.isInitialLoading,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AppFilterChips<WalletTab>(
              selected: _tab,
              onSelected: _selectTab,
              // These are navigation, not filters: a scrolling strip pushes
              // Orders off a phone-width screen, where a student would never
              // find it.
              wrap: true,
              options: [
                for (final tab in WalletTab.values)
                  AppFilterChipOption(value: tab, label: tab.label),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshCurrentTab,
              child: switch (_tab) {
                WalletTab.wallet => const _TransactionsPanel(),
                WalletTab.earn => const _EarnPanel(),
                WalletTab.store => _StorePanel(onRedeem: _redeem),
                WalletTab.orders => _OrdersPanel(onTrack: _openChat),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsPanel extends StatelessWidget {
  const _TransactionsPanel();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WalletTransactionsCubit>();
    final glassInsets = context.glassContentInsets;

    return InfiniteScroll(
      onLoadMore: cubit.loadMore,
      child: RemoteView<WalletTransactionsCubit, Paginated<PointTransaction>>(
        onRetry: cubit.load,
        loading: const _ListSkeleton(),
        isEmpty: (page) => page.items.isEmpty,
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitle: 'No points activity yet',
        emptyDescription:
            'Log in daily and complete challenges to start earning points.',
        builder: (context, page) => ListView.separated(
          // No controller: the list must stay on the PrimaryScrollController.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + glassInsets.bottom),
          itemCount: page.items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == page.items.length) {
              return AppLoadMoreFooter(
                isLoading: cubit.isLoadingMore || cubit.hasMore,
                hasMore: cubit.hasMore,
                endLabel: 'No more activity',
              );
            }
            final item = page.items[index];
            return TransactionRow(key: ValueKey(item.id), transaction: item);
          },
        ),
      ),
    );
  }
}

class _EarnPanel extends StatelessWidget {
  const _EarnPanel();

  @override
  Widget build(BuildContext context) {
    final glassInsets = context.glassContentInsets;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + glassInsets.bottom),
      itemCount: RewardsMeta.earnMethods.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) =>
          EarnMethodCard(method: RewardsMeta.earnMethods[index]),
    );
  }
}

class _StorePanel extends StatelessWidget {
  const _StorePanel({required this.onRedeem});

  final ValueChanged<Product> onRedeem;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<StoreCubit>();
    final glassInsets = context.glassContentInsets;

    return RemoteView<StoreCubit, Store>(
      onRetry: cubit.load,
      loading: const _ListSkeleton(height: 190),
      isEmpty: (store) => store.products.isEmpty,
      emptyIcon: Icons.storefront_outlined,
      emptyTitle: 'No rewards available yet',
      emptyDescription:
          "Your school hasn't added any rewards. Check back soon.",
      builder: (context, store) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + glassInsets.bottom),
        itemCount: store.products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final product = store.products[index];
          return ProductCard(
            key: ValueKey(product.id),
            product: product,
            balance: store.wallet.balance,
            onRedeem: () => onRedeem(product),
          );
        },
      ),
    );
  }
}

class _OrdersPanel extends StatelessWidget {
  const _OrdersPanel({required this.onTrack});

  final ValueChanged<RewardOrder> onTrack;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrdersCubit>();
    final glassInsets = context.glassContentInsets;

    return RemoteView<OrdersCubit, List<RewardOrder>>(
      onRetry: cubit.load,
      loading: const _ListSkeleton(),
      isEmpty: (orders) => orders.isEmpty,
      emptyIcon: Icons.inventory_2_outlined,
      emptyTitle: 'No orders yet',
      emptyDescription: 'Redeem a reward from the store to see it here.',
      builder: (context, orders) => ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + glassInsets.bottom),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final order = orders[index];
          return OrderRow(
            key: ValueKey(order.id),
            order: order,
            onTrack: () => onTrack(order),
          );
        },
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({this.height = 68});

  final double height;

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) =>
            AppSkeleton(height: height, radius: AppTheme.radiusLg),
      );
}
