import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'failures.dart';

/// Shared exception→[Failure] boundary for repository implementations.
///
/// Every repository method wraps its datasource calls in [guard], so the
/// translation lives in exactly one place and no `catch` block is ever
/// forgotten.
mixin RepositoryGuard {
  /// Runs [action] and converts anything it throws into a [Failure].
  ///
  /// Dio wraps our typed exceptions in a [DioException], so unwrap `.error`
  /// before mapping — otherwise every failure would collapse to a generic
  /// server failure and the 401/403/422 handling would be lost.
  Future<Either<Failure, T>> guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on DioException catch (error) {
      return Left(mapExceptionToFailure(error.error ?? error));
    } catch (error) {
      return Left(mapExceptionToFailure(error));
    }
  }
}
