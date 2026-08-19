import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/rewards.dart';
import '../../domain/usecases/rewards_usecases.dart';

/// The rewards store, plus the purchase mutation.
///
/// A purchase moves money the wallet and orders tabs also show. Rather than a
/// global event bus, [purchase] just reports its outcome and the page refreshes
/// its sibling cubits — the same coordination `NotesPage` does for its stats.
class StoreCubit extends RemoteCubit<Store> {
  StoreCubit({
    required GetStoreUseCase getStore,
    required PurchaseProductUseCase purchaseProduct,
  })  : _purchaseProduct = purchaseProduct,
        super(() => getStore(const NoParams()));

  final PurchaseProductUseCase _purchaseProduct;

  bool _isPurchasing = false;

  bool get isPurchasing => _isPurchasing;

  /// Spends points on [productId]. Returns null on success, or the failure to
  /// show — most often "You do not have enough points for this purchase".
  ///
  /// The store reloads itself either way, because a failure can just as easily
  /// mean the product was deactivated as that the balance was short.
  Future<Failure?> purchase(String productId) async {
    if (isClosed || _isPurchasing) return null;
    _isPurchasing = true;

    final result = await _purchaseProduct(IdParams(productId));

    _isPurchasing = false;
    if (isClosed) return null;

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    await load(refresh: true);
    return failure;
  }
}
