import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../../core/config/theme/app_colors.dart';

/// `GET /rewards/wallet` — the student's coin balance.
///
/// `balance` is what can be spent; `totalEarned` and `totalSpent` are lifetime
/// counters, both stored positive (a spend is negative in the ledger but adds
/// to `totalSpent`), so never derive one from the other.
class Wallet extends Equatable {
  const Wallet({
    this.balance = 0,
    this.totalEarned = 0,
    this.totalSpent = 0,
    this.availableTickets = 0,
  });

  final int balance;
  final int totalEarned;
  final int totalSpent;

  /// Unused Time Travel Tickets — purchased but not yet spent on a missed day.
  final int availableTickets;

  @override
  List<Object?> get props => [balance, totalEarned, totalSpent, availableTickets];
}

/// One row of the append-only points ledger.
class PointTransaction extends Equatable {
  const PointTransaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.reason,
    this.createdAt,
  });

  final String id;

  /// Signed: positive credits, negative debits. Rendering must not add its own
  /// minus — a debit already carries one.
  final int amount;

  final String type;
  final String reason;
  final String? createdAt;

  bool get isCredit => amount >= 0;

  /// The row's heading. Falls back to the reason for a type the app does not
  /// know, which is how a newly added backend type degrades gracefully.
  String get label => RewardsMeta.transactionLabel(type) ?? reason;

  @override
  List<Object?> get props => [id, amount, type, reason, createdAt];
}

/// A purchasable item in the school's rewards store.
class Product extends Equatable {
  const Product({
    required this.id,
    required this.title,
    required this.price,
    this.description,
    this.imageUrl,
    this.productType = RewardsMeta.generic,
    this.isActive = true,
  });

  final String id;
  final String title;
  final int price;
  final String? description;
  final String? imageUrl;
  final String productType;
  final bool isActive;

  /// Tickets carry a gameplay effect rather than being fulfilled by hand.
  bool get isTicket => productType == RewardsMeta.timeTravelTicket;

  @override
  List<Object?> get props =>
      [id, title, price, description, imageUrl, productType, isActive];
}

/// `GET /rewards/store` — the catalogue plus the wallet it is priced against.
class Store extends Equatable {
  const Store({
    this.products = const [],
    this.wallet = const Wallet(),
    this.availableTickets = 0,
  });

  final List<Product> products;

  /// The store's own copy of the balance. It omits `availableTickets`, which
  /// arrives as a sibling field — see [availableTickets].
  final Wallet wallet;

  final int availableTickets;

  @override
  List<Object?> get props => [products, wallet, availableTickets];
}

/// A completed purchase. Doubles as the ticket inventory: an unspent ticket is
/// an order with `effectStatus == 'unused'`.
class RewardOrder extends Equatable {
  const RewardOrder({
    required this.id,
    required this.productTitle,
    required this.pointsSpent,
    this.productId,
    this.productType = RewardsMeta.generic,
    this.effectStatus = RewardsMeta.effectNone,
    this.consumedRefId,
    this.consumedAt,
    this.createdAt,
    this.fulfilledAt,
    this.unreadCount = 0,
  });

  final String id;
  final String productTitle;
  final int pointsSpent;
  final String? productId;
  final String productType;

  /// `none` for ordinary goods, `unused`/`consumed` for tickets.
  final String effectStatus;

  /// The daily set a spent ticket re-opened.
  final String? consumedRefId;
  final String? consumedAt;
  final String? createdAt;

  /// Null until an admin marks the order done. Meaningless for tickets, which
  /// take effect immediately rather than being fulfilled.
  final String? fulfilledAt;

  final int unreadCount;

  bool get isTicket => productType == RewardsMeta.timeTravelTicket;

  bool get isFulfilled => fulfilledAt != null;

  /// Only physical goods have a tracking conversation; a ticket has nothing to
  /// chase up. The backend rejects chat on a ticket order outright.
  bool get canChat => !isTicket;

  @override
  List<Object?> get props => [
        id,
        productTitle,
        pointsSpent,
        productId,
        productType,
        effectStatus,
        consumedRefId,
        consumedAt,
        createdAt,
        fulfilledAt,
        unreadCount,
      ];
}

/// One message in an order's student ⇄ admin tracking chat.
class OrderMessage extends Equatable {
  const OrderMessage({
    required this.id,
    required this.content,
    required this.authorRole,
    this.senderName,
    this.senderAvatar,
    this.createdAt,
  });

  final String id;
  final String content;
  final String authorRole;
  final String? senderName;
  final String? senderAvatar;
  final String? createdAt;

  /// This screen only ever runs as the student, so their own role is the test.
  bool get isMine => authorRole == RewardsMeta.roleStudent;

  @override
  List<Object?> get props =>
      [id, content, authorRole, senderName, senderAvatar, createdAt];
}

/// One way to earn points, for the static "Earn Points" tab.
class EarnMethod {
  const EarnMethod({
    required this.title,
    required this.description,
    required this.points,
    required this.icon,
    required this.shade,
  });

  final String title;
  final String description;
  final int points;
  final IconData icon;
  final TwShade shade;
}

/// Labels, tints and the string constants the API speaks, ported from the maps
/// the web keeps inline in each wallet panel.
class RewardsMeta {
  const RewardsMeta._();

  // Product / order types.
  static const generic = 'generic';
  static const timeTravelTicket = 'time_travel_ticket';

  // Order effect statuses.
  static const effectNone = 'none';
  static const effectUnused = 'unused';
  static const effectConsumed = 'consumed';

  // Message author roles.
  static const roleStudent = 'student';
  static const roleAdmin = 'admin';

  /// How many ledger rows to pull per page.
  static const transactionsPageSize = 20;

  /// The web's `TXN_LABEL`, plus `contest_prize`, which the backend enum has
  /// and the web's union is missing.
  ///
  /// Null for an unrecognised type so the caller can fall back to the row's own
  /// reason rather than printing a raw enum key.
  static String? transactionLabel(String type) => switch (type) {
        'daily_login' => 'Daily visit',
        'daily_challenge' => 'Daily challenge completed',
        'monthly_challenge' => 'Perfect month',
        'contest_prize' => 'Contest prize',
        'purchase' => 'Reward redeemed',
        'backfill' => 'Earned before launch',
        'refund' => 'Refund',
        'adjustment' => 'Adjustment',
        _ => null,
      };

  /// The web's `EFFECT_BADGE`. Null for `none`, which renders no badge.
  static String? effectLabel(String status) => switch (status) {
        effectUnused => 'Ready to use',
        effectConsumed => 'Used',
        _ => null,
      };

  static TwShade effectShade(String status) =>
      status == effectUnused ? TwColors.emerald : TwColors.slate;

  /// The three static cards of the "Earn Points" tab, with the amounts the
  /// backend actually awards (`POINTS` in `rewards.constants.ts`).
  static const earnMethods = [
    EarnMethod(
      title: 'Visit daily',
      description: 'Open the app on any day to collect your daily bonus — the '
          'first visit each day counts.',
      points: 1,
      icon: Icons.calendar_today_rounded,
      shade: TwColors.blue,
    ),
    EarnMethod(
      title: 'Complete a daily challenge',
      description: "Solve every question in the day's challenge to earn its "
          'bonus.',
      points: 10,
      icon: Icons.verified_rounded,
      shade: TwColors.emerald,
    ),
    EarnMethod(
      title: 'Complete a perfect month',
      description: 'Complete every daily challenge across a whole calendar '
          'month for a big bonus.',
      points: 30,
      icon: Icons.workspace_premium_rounded,
      shade: TwColors.violet,
    ),
  ];
}
