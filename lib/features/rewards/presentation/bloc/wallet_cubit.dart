import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/rewards.dart';
import '../../domain/usecases/rewards_usecases.dart';

/// The coin balance behind the wallet hero.
///
/// Kept apart from the ledger so a paging failure never blanks the balance, and
/// so the hero can stay on screen through every tab.
class WalletCubit extends RemoteCubit<Wallet> {
  WalletCubit({required GetWalletUseCase getWallet})
      : super(() => getWallet(const NoParams()));
}

/// The points ledger, newest first.
///
/// The endpoint already answers with the standard `{data, pagination}`
/// envelope, so the generic paginated cubit drops straight in.
class WalletTransactionsCubit extends PaginatedCubit<PointTransaction> {
  WalletTransactionsCubit({required ListTransactionsUseCase listTransactions})
      : super(
          (page) => listTransactions(
            PageParams(page: page, limit: RewardsMeta.transactionsPageSize),
          ),
        );
}

/// Every purchase the student has made. Unpaginated — the endpoint returns a
/// bare array.
class OrdersCubit extends RemoteCubit<List<RewardOrder>> {
  OrdersCubit({required ListOrdersUseCase listOrders})
      : super(() => listOrders(const NoParams()));
}
