import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/config/theme/app_colors.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/rewards/data/models/rewards_models.dart';
import 'package:college_level/features/rewards/domain/entities/rewards.dart';
import 'package:college_level/features/rewards/domain/usecases/rewards_usecases.dart';
import 'package:college_level/features/rewards/presentation/bloc/order_chat_cubit.dart';
import 'package:college_level/features/rewards/presentation/bloc/store_cubit.dart';
import 'package:college_level/features/rewards/presentation/bloc/wallet_cubit.dart';
import 'package:college_level/features/rewards/presentation/pages/wallet_page.dart';

class _MockGetWallet extends Mock implements GetWalletUseCase {}

class _MockListTransactions extends Mock implements ListTransactionsUseCase {}

class _MockGetStore extends Mock implements GetStoreUseCase {}

class _MockPurchase extends Mock implements PurchaseProductUseCase {}

class _MockListMessages extends Mock implements ListOrderMessagesUseCase {}

class _MockSendMessage extends Mock implements SendOrderMessageUseCase {}

PointTransaction _txn({
  String id = 't1',
  int amount = 10,
  String type = 'daily_challenge',
  String reason = 'Completed the challenge',
}) =>
    PointTransaction(id: id, amount: amount, type: type, reason: reason);

Paginated<PointTransaction> _page({
  List<PointTransaction> items = const [],
  int page = 1,
  int total = 1,
  int totalPages = 1,
}) =>
    Paginated<PointTransaction>(
      items: items,
      pagination: Pagination(
        page: page,
        limit: RewardsMeta.transactionsPageSize,
        total: total,
        totalPages: totalPages,
      ),
    );

void main() {
  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(const IdParams('x'));
    registerFallbackValue(const PageParams());
    registerFallbackValue(
      const SendMessageParams(orderId: 'o1', content: 'hi'),
    );
  });

  group('RewardsMeta.transactionLabel', () {
    test('every backend type has a label', () {
      const types = [
        'daily_login',
        'daily_challenge',
        'monthly_challenge',
        'contest_prize',
        'purchase',
        'backfill',
        'refund',
        'adjustment',
      ];

      for (final type in types) {
        expect(
          RewardsMeta.transactionLabel(type),
          isNotNull,
          reason: 'type: $type',
        );
      }
    });

    /// The backend enum has eight values and the web's union lists seven — a
    /// contest prize renders as a raw reason there. The port must not inherit
    /// that gap.
    test('contest_prize is covered, unlike the web', () {
      expect(RewardsMeta.transactionLabel('contest_prize'), 'Contest prize');
    });

    /// A type added server-side must degrade to something readable rather than
    /// printing an enum key.
    test('an unknown type falls back to the row reason', () {
      final txn = _txn(type: 'referral_bonus', reason: 'Invited a friend');

      expect(RewardsMeta.transactionLabel('referral_bonus'), isNull);
      expect(txn.label, 'Invited a friend');
    });
  });

  group('RewardsMeta.effectLabel', () {
    test('only ticket states are badged', () {
      expect(RewardsMeta.effectLabel('unused'), 'Ready to use');
      expect(RewardsMeta.effectLabel('consumed'), 'Used');
      expect(RewardsMeta.effectLabel('none'), isNull);
      expect(RewardsMeta.effectLabel('nonsense'), isNull);
    });

    test('an unused ticket reads as available, a spent one as neutral', () {
      expect(RewardsMeta.effectShade('unused'), TwColors.emerald);
      expect(RewardsMeta.effectShade('consumed'), TwColors.slate);
    });
  });

  group('PointTransaction', () {
    /// Zero is a credit: the ledger has no third state, and rendering it as a
    /// debit would paint it red for no reason.
    test('isCredit treats zero as a credit', () {
      expect(_txn(amount: 5).isCredit, isTrue);
      expect(_txn(amount: 0).isCredit, isTrue);
      expect(_txn(amount: -5).isCredit, isFalse);
    });
  });

  group('RewardOrder', () {
    test('only non-ticket orders can be chased up', () {
      const ticket = RewardOrder(
        id: 'o1',
        productTitle: 'Time Travel Ticket',
        pointsSpent: 70,
        productType: RewardsMeta.timeTravelTicket,
      );
      const goods = RewardOrder(
        id: 'o2',
        productTitle: 'Hoodie',
        pointsSpent: 300,
      );

      expect(ticket.isTicket, isTrue);
      expect(ticket.canChat, isFalse);
      expect(goods.canChat, isTrue);
    });

    test('isFulfilled follows the timestamp', () {
      const pending = RewardOrder(id: 'o', productTitle: 'X', pointsSpent: 1);
      const done = RewardOrder(
        id: 'o',
        productTitle: 'X',
        pointsSpent: 1,
        fulfilledAt: '2026-08-01T00:00:00.000Z',
      );

      expect(pending.isFulfilled, isFalse);
      expect(done.isFulfilled, isTrue);
    });
  });

  group('WalletTab.fromQuery', () {
    test('each tab key resolves', () {
      expect(WalletTab.fromQuery('wallet'), WalletTab.wallet);
      expect(WalletTab.fromQuery('earn'), WalletTab.earn);
      expect(WalletTab.fromQuery('store'), WalletTab.store);
      expect(WalletTab.fromQuery('orders'), WalletTab.orders);
    });

    /// Notification deep links supply this, so a stale or malformed link has to
    /// land somewhere sensible rather than throwing.
    test('anything unrecognised falls back to the ledger', () {
      for (final value in [null, '', 'Wallet', 'nope']) {
        expect(WalletTab.fromQuery(value), WalletTab.wallet, reason: '$value');
      }
    });
  });

  group('models', () {
    test('the wallet parses', () {
      final wallet = WalletModel.fromJson(const {
        'balance': 120,
        'totalEarned': 300,
        'totalSpent': 180,
        'availableTickets': 2,
      });

      expect(wallet.balance, 120);
      expect(wallet.totalEarned, 300);
      expect(wallet.totalSpent, 180);
      expect(wallet.availableTickets, 2);
    });

    /// `/rewards/visit` and the purchase response return the summary without
    /// the ticket count.
    test('a summary without availableTickets defaults it to zero', () {
      final wallet = WalletModel.fromJson(const {
        'balance': 10,
        'totalEarned': 10,
        'totalSpent': 0,
      });

      expect(wallet.availableTickets, 0);
    });

    test('an empty payload yields zeros rather than throwing', () {
      final wallet = WalletModel.fromJson(const {});

      expect(wallet.balance, 0);
      expect(wallet.totalEarned, 0);
      expect(wallet.totalSpent, 0);
      expect(wallet.availableTickets, 0);
    });

    test('the store carries its own copy of the balance', () {
      final store = StoreModel.fromJson(const {
        'products': [
          {
            'id': 'p1',
            'title': 'Time Travel Ticket',
            'price': 70,
            'productType': 'time_travel_ticket',
          },
        ],
        'wallet': {'balance': 100, 'totalEarned': 100, 'totalSpent': 0},
        'availableTickets': 1,
      });

      expect(store.products.single.isTicket, isTrue);
      expect(store.products.single.price, 70);
      expect(store.wallet.balance, 100);
      expect(store.availableTickets, 1);
    });

    test('a product defaults to a generic, active item', () {
      final product = ProductModel.fromJson(const {'id': 'p', 'title': 'T'});

      expect(product.productType, RewardsMeta.generic);
      expect(product.isTicket, isFalse);
      expect(product.isActive, isTrue);
      expect(product.description, isNull);
      expect(product.imageUrl, isNull);
    });

    test('orders parse from a bare array, not an envelope', () {
      final orders = RewardOrderModel.listFromJson(const [
        {
          'id': 'o1',
          'productTitle': 'Hoodie',
          'pointsSpent': 300,
          'unreadCount': 2,
        },
      ]);

      expect(orders.single.productTitle, 'Hoodie');
      expect(orders.single.unreadCount, 2);
      expect(orders.single.effectStatus, RewardsMeta.effectNone);
    });

    /// A deleted product nulls the order's `productId`; the snapshotted title
    /// is what keeps the row readable.
    test('an order survives its product being deleted', () {
      final orders = RewardOrderModel.listFromJson(const [
        {'id': 'o1', 'productTitle': 'Gone', 'pointsSpent': 5, 'productId': null},
      ]);

      expect(orders.single.productId, isNull);
      expect(orders.single.productTitle, 'Gone');
    });

    test('messages parse and identify their own side', () {
      final messages = OrderMessageModel.listFromJson(const [
        {'id': 'm1', 'content': 'Where is it?', 'authorRole': 'student'},
        {
          'id': 'm2',
          'content': 'Shipping today.',
          'authorRole': 'admin',
          'senderName': 'Office',
        },
      ]);

      expect(messages.first.isMine, isTrue);
      expect(messages.last.isMine, isFalse);
      expect(messages.last.senderName, 'Office');
    });

    /// The same defect the badges model had: `as List?` throws on a wrong type
    /// instead of defaulting like a missing key.
    test('a wrong-typed list defaults instead of throwing', () {
      expect(RewardOrderModel.listFromJson('not a list'), isEmpty);
      expect(OrderMessageModel.listFromJson(42), isEmpty);
      expect(StoreModel.fromJson(const {'products': 'nope'}).products, isEmpty);
    });

    test('transactions parse through the paginated envelope', () {
      final page = Paginated<PointTransactionModel>.fromJson(
        const {
          'data': [
            {
              'id': 't1',
              'amount': -70,
              'type': 'purchase',
              'reason': 'Purchased Time Travel Ticket',
              'createdAt': '2026-08-01T10:00:00.000Z',
            },
          ],
          'pagination': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
        },
        PointTransactionModel.fromJson,
      );

      expect(page.items.single.amount, -70);
      expect(page.items.single.isCredit, isFalse);
      expect(page.items.single.label, 'Reward redeemed');
      expect(page.pagination.total, 1);
      expect(page.pagination.hasNextPage, isFalse);
    });
  });

  group('WalletCubit', () {
    late _MockGetWallet getWallet;

    setUp(() => getWallet = _MockGetWallet());

    test('a success carries the wallet', () async {
      when(() => getWallet(any())).thenAnswer(
        (_) async => const Right<Failure, Wallet>(Wallet(balance: 42)),
      );

      final cubit = WalletCubit(getWallet: getWallet);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data?.balance, 42);
    });

    test('a failure leaves no balance to show', () async {
      when(() => getWallet(any())).thenAnswer(
        (_) async => const Left<Failure, Wallet>(NetworkFailure('offline')),
      );

      final cubit = WalletCubit(getWallet: getWallet);
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      expect(cubit.state.data, isNull);
    });
  });

  group('WalletTransactionsCubit', () {
    late _MockListTransactions listTransactions;

    setUp(() => listTransactions = _MockListTransactions());

    test('loadMore appends the next page', () async {
      when(() => listTransactions(any())).thenAnswer(
        (_) async => Right<Failure, Paginated<PointTransaction>>(
          _page(items: [_txn(id: 'a')], total: 2, totalPages: 2),
        ),
      );

      final cubit = WalletTransactionsCubit(listTransactions: listTransactions);
      await cubit.load();
      expect(cubit.hasMore, isTrue);

      when(() => listTransactions(any())).thenAnswer(
        (_) async => Right<Failure, Paginated<PointTransaction>>(
          _page(items: [_txn(id: 'b')], page: 2, total: 2, totalPages: 2),
        ),
      );
      await cubit.loadMore();

      expect(cubit.state.data?.items.map((t) => t.id), ['a', 'b']);
      expect(cubit.hasMore, isFalse);
    });

    /// The rows already on screen are real; a paging failure must not discard
    /// them.
    test('a failed loadMore keeps the rows already loaded', () async {
      when(() => listTransactions(any())).thenAnswer(
        (_) async => Right<Failure, Paginated<PointTransaction>>(
          _page(items: [_txn(id: 'a')], total: 2, totalPages: 2),
        ),
      );

      final cubit = WalletTransactionsCubit(listTransactions: listTransactions);
      await cubit.load();

      when(() => listTransactions(any())).thenAnswer(
        (_) async => const Left<Failure, Paginated<PointTransaction>>(
          NetworkFailure('offline'),
        ),
      );
      await cubit.loadMore();

      expect(cubit.state.data?.items, hasLength(1));
      expect(cubit.state.failure, isA<NetworkFailure>());
    });
  });

  group('StoreCubit.purchase', () {
    late _MockGetStore getStore;
    late _MockPurchase purchase;

    setUp(() {
      getStore = _MockGetStore();
      purchase = _MockPurchase();
      when(() => getStore(any())).thenAnswer(
        (_) async => const Right<Failure, Store>(Store()),
      );
    });

    test('a success reports no failure and reloads the store', () async {
      when(() => purchase(any()))
          .thenAnswer((_) async => const Right<Failure, Unit>(unit));

      final cubit = StoreCubit(getStore: getStore, purchaseProduct: purchase);
      final failure = await cubit.purchase('p1');

      expect(failure, isNull);
      verify(() => purchase(const IdParams('p1'))).called(1);
      // Once for the purchase's own refresh.
      verify(() => getStore(any())).called(1);
    });

    /// Insufficient points comes back as the server's message, which the page
    /// surfaces verbatim.
    test('a failure is returned for the caller to show', () async {
      when(() => purchase(any())).thenAnswer(
        (_) async => const Left<Failure, Unit>(
          ServerFailure('You do not have enough points for this purchase'),
        ),
      );

      final cubit = StoreCubit(getStore: getStore, purchaseProduct: purchase);
      final failure = await cubit.purchase('p1');

      expect(failure, isA<ServerFailure>());
      expect(
        failure?.message,
        'You do not have enough points for this purchase',
      );
    });

    /// Double-tapping Redeem must not spend twice.
    test('a second purchase is ignored while one is in flight', () async {
      when(() => purchase(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return const Right<Failure, Unit>(unit);
      });

      final cubit = StoreCubit(getStore: getStore, purchaseProduct: purchase);
      await Future.wait([cubit.purchase('p1'), cubit.purchase('p1')]);

      verify(() => purchase(any())).called(1);
    });
  });

  group('OrderChatCubit', () {
    late _MockListMessages listMessages;
    late _MockSendMessage sendMessage;

    OrderChatCubit build() => OrderChatCubit(
          orderId: 'o1',
          listMessages: listMessages,
          sendMessage: sendMessage,
        );

    setUp(() {
      listMessages = _MockListMessages();
      sendMessage = _MockSendMessage();
    });

    test('loading fetches the thread for its own order', () async {
      when(() => listMessages(any())).thenAnswer(
        (_) async => const Right<Failure, List<OrderMessage>>([
          OrderMessage(id: 'm1', content: 'Hi', authorRole: 'student'),
        ]),
      );

      final cubit = build();
      await cubit.load();

      expect(cubit.state.data, hasLength(1));
      verify(() => listMessages(const IdParams('o1'))).called(1);
      await cubit.close();
    });

    test('an empty message is never sent', () async {
      final cubit = build();

      expect(await cubit.send('   '), isNull);
      verifyNever(() => sendMessage(any()));
      await cubit.close();
    });

    test('sending trims and refreshes the thread', () async {
      when(() => sendMessage(any()))
          .thenAnswer((_) async => const Right<Failure, Unit>(unit));
      when(() => listMessages(any())).thenAnswer(
        (_) async => const Right<Failure, List<OrderMessage>>([]),
      );

      final cubit = build();
      final failure = await cubit.send('  hello  ');

      expect(failure, isNull);
      verify(
        () => sendMessage(
          const SendMessageParams(orderId: 'o1', content: 'hello'),
        ),
      ).called(1);
      verify(() => listMessages(any())).called(1);
      await cubit.close();
    });

    /// A dropped poll must not replace a readable thread with an error screen.
    test('a failed silent refresh keeps the messages on screen', () async {
      when(() => listMessages(any())).thenAnswer(
        (_) async => const Right<Failure, List<OrderMessage>>([
          OrderMessage(id: 'm1', content: 'Hi', authorRole: 'admin'),
        ]),
      );

      final cubit = build();
      await cubit.load();

      when(() => listMessages(any())).thenAnswer(
        (_) async => const Left<Failure, List<OrderMessage>>(
          NetworkFailure('offline'),
        ),
      );
      await cubit.load(silent: true);

      expect(cubit.state.data, hasLength(1));
      expect(cubit.state.status, RemoteStatus.success);
      await cubit.close();
    });

    /// The timer must not outlive the sheet.
    test('closing stops the poll', () async {
      when(() => listMessages(any())).thenAnswer(
        (_) async => const Right<Failure, List<OrderMessage>>([]),
      );

      final cubit = build();
      await cubit.load();
      await cubit.close();

      clearInteractions(listMessages);
      await Future<void>.delayed(OrderChatCubit.pollInterval * 1.2);

      verifyNever(() => listMessages(any()));
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('endpoints', () {
    test('the rewards paths match the backend router', () {
      expect(ApiUrls.rewardsWallet, '/rewards/wallet');
      expect(ApiUrls.rewardsTransactions, '/rewards/wallet/transactions');
      expect(ApiUrls.rewardsStore, '/rewards/store');
      expect(ApiUrls.rewardsOrders, '/rewards/orders');
      expect(ApiUrls.rewardsPurchase('p1'), '/rewards/store/p1/purchase');
      expect(ApiUrls.rewardsOrderMessages('o1'), '/rewards/orders/o1/messages');
    });
  });
}
