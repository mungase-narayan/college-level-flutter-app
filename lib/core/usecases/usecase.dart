import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../error/failures.dart';

/// Base contract for every use case.
///
/// Blocs depend on use cases, never on repositories directly, so the
/// presentation layer stays ignorant of the data layer.
abstract class UseCase<T, P> {
  Future<Either<Failure, T>> call(P params);
}

/// A use case that runs synchronously (no I/O).
abstract class SyncUseCase<T, P> {
  Either<Failure, T> call(P params);
}

/// Parameter placeholder for use cases that take no input.
class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => const [];
}

/// Parameter object for the very common "fetch one thing by id" case.
class IdParams extends Equatable {
  const IdParams(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// Parameter object for paginated list endpoints.
class PageParams extends Equatable {
  const PageParams({this.page = 1, this.limit = 20, this.search});

  final int page;
  final int limit;
  final String? search;

  Map<String, dynamic> toQuery() => {
        'page': page,
        'limit': limit,
        'search': search,
      };

  @override
  List<Object?> get props => [page, limit, search];
}
