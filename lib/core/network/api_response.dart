import 'package:equatable/equatable.dart';

/// The backend's global success envelope (`src/utils/api-response.ts`):
///
/// ```json
/// { "statusCode": 200, "data": {...}, "message": "Login successful.", "success": true }
/// ```
///
/// Note the key is `statusCode`, **not** `status`, and `success` is the
/// authoritative boolean (`statusCode < 400`).
class ApiResponse<T> extends Equatable {
  const ApiResponse({
    required this.statusCode,
    required this.data,
    required this.message,
    required this.success,
  });

  final int statusCode;
  final T data;
  final String message;
  final bool success;

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Object? data) parse,
  ) {
    final statusCode = (json['statusCode'] as num?)?.toInt() ?? 200;
    return ApiResponse<T>(
      statusCode: statusCode,
      data: parse(json['data']),
      message: json['message'] as String? ?? '',
      success: json['success'] as bool? ?? statusCode < 400,
    );
  }

  @override
  List<Object?> get props => [statusCode, data, message, success];
}

/// Pagination metadata returned inside `data` by nearly every list endpoint:
/// `{ "data": [...], "pagination": { page, limit, total, totalPages } }`.
class Pagination extends Equatable {
  const Pagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int limit;
  final int total;
  final int totalPages;

  static const empty = Pagination(page: 1, limit: 0, total: 0, totalPages: 0);

  bool get hasNextPage => page < totalPages;

  factory Pagination.fromJson(Map<String, dynamic>? json) {
    if (json == null) return empty;
    return Pagination(
      page: (json['page'] as num?)?.toInt() ?? 1,
      limit: (json['limit'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [page, limit, total, totalPages];
}

/// A page of results plus its [Pagination] metadata.
class Paginated<T> extends Equatable {
  const Paginated({required this.items, required this.pagination});

  final List<T> items;
  final Pagination pagination;

  static Paginated<T> emptyOf<T>() =>
      Paginated<T>(items: const [], pagination: Pagination.empty);

  /// Parses the `data` object of a paginated endpoint.
  ///
  /// Tolerates endpoints that return a bare array with no envelope — a few
  /// dropdown-style endpoints do exactly that.
  factory Paginated.fromJson(
    Object? data,
    T Function(Map<String, dynamic> json) parseItem,
  ) {
    if (data is List) {
      return Paginated<T>(
        items: data
            .whereType<Map<String, dynamic>>()
            .map(parseItem)
            .toList(growable: false),
        pagination: Pagination.empty,
      );
    }
    final map = (data as Map<String, dynamic>?) ?? const {};
    final rawItems = (map['data'] as List?) ?? const [];
    return Paginated<T>(
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(parseItem)
          .toList(growable: false),
      pagination: Pagination.fromJson(map['pagination'] as Map<String, dynamic>?),
    );
  }

  Paginated<T> copyWithAppended(Paginated<T> next) => Paginated<T>(
        items: [...items, ...next.items],
        pagination: next.pagination,
      );

  @override
  List<Object?> get props => [items, pagination];
}
