import '../../domain/entities/rewards.dart';

String _string(Object? value) => value is String ? value : '';
String? _stringOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
int _int(Object? value) => (value as num?)?.toInt() ?? 0;

/// `is List` rather than `as List?`: a wrong-typed key must default like a
/// missing one instead of throwing out of the parse.
List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

class WalletModel extends Wallet {
  const WalletModel({
    super.balance,
    super.totalEarned,
    super.totalSpent,
    super.availableTickets,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
        balance: _int(json['balance']),
        totalEarned: _int(json['totalEarned']),
        totalSpent: _int(json['totalSpent']),
        // Absent on `/rewards/visit` and on the purchase response, which return
        // the summary without it.
        availableTickets: _int(json['availableTickets']),
      );
}

class PointTransactionModel extends PointTransaction {
  const PointTransactionModel({
    required super.id,
    required super.amount,
    required super.type,
    required super.reason,
    super.createdAt,
  });

  factory PointTransactionModel.fromJson(Map<String, dynamic> json) =>
      PointTransactionModel(
        id: _string(json['id']),
        amount: _int(json['amount']),
        type: _string(json['type']),
        reason: _string(json['reason']),
        createdAt: _stringOrNull(json['createdAt']),
      );
}

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.title,
    required super.price,
    super.description,
    super.imageUrl,
    super.productType,
    super.isActive,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: _string(json['id']),
        title: _string(json['title']),
        price: _int(json['price']),
        description: _stringOrNull(json['description']),
        imageUrl: _stringOrNull(json['imageUrl']),
        productType: json['productType'] as String? ?? RewardsMeta.generic,
        isActive: json['isActive'] as bool? ?? true,
      );
}

class StoreModel extends Store {
  const StoreModel({super.products, super.wallet, super.availableTickets});

  factory StoreModel.fromJson(Map<String, dynamic> json) => StoreModel(
        products:
            _maps(json['products']).map(ProductModel.fromJson).toList(growable: false),
        wallet: WalletModel.fromJson(_map(json['wallet'])),
        availableTickets: _int(json['availableTickets']),
      );
}

class RewardOrderModel extends RewardOrder {
  const RewardOrderModel({
    required super.id,
    required super.productTitle,
    required super.pointsSpent,
    super.productId,
    super.productType,
    super.effectStatus,
    super.consumedRefId,
    super.consumedAt,
    super.createdAt,
    super.fulfilledAt,
    super.unreadCount,
  });

  factory RewardOrderModel.fromJson(Map<String, dynamic> json) =>
      RewardOrderModel(
        id: _string(json['id']),
        productTitle: _string(json['productTitle']),
        pointsSpent: _int(json['pointsSpent']),
        // Null once an admin deletes the product — the title is snapshotted on
        // the order precisely so the row survives that.
        productId: _stringOrNull(json['productId']),
        productType: json['productType'] as String? ?? RewardsMeta.generic,
        effectStatus: json['effectStatus'] as String? ?? RewardsMeta.effectNone,
        consumedRefId: _stringOrNull(json['consumedRefId']),
        consumedAt: _stringOrNull(json['consumedAt']),
        createdAt: _stringOrNull(json['createdAt']),
        fulfilledAt: _stringOrNull(json['fulfilledAt']),
        unreadCount: _int(json['unreadCount']),
      );

  /// `GET /rewards/orders` answers with a bare array, not a paginated envelope.
  static List<RewardOrder> listFromJson(Object? data) =>
      _maps(data).map(RewardOrderModel.fromJson).toList(growable: false);
}

class OrderMessageModel extends OrderMessage {
  const OrderMessageModel({
    required super.id,
    required super.content,
    required super.authorRole,
    super.senderName,
    super.senderAvatar,
    super.createdAt,
  });

  factory OrderMessageModel.fromJson(Map<String, dynamic> json) =>
      OrderMessageModel(
        id: _string(json['id']),
        content: _string(json['content']),
        authorRole: json['authorRole'] as String? ?? RewardsMeta.roleStudent,
        senderName: _stringOrNull(json['senderName']),
        senderAvatar: _stringOrNull(json['senderAvatar']),
        createdAt: _stringOrNull(json['createdAt']),
      );

  /// Oldest first, as the endpoint returns them.
  static List<OrderMessage> listFromJson(Object? data) =>
      _maps(data).map(OrderMessageModel.fromJson).toList(growable: false);
}
