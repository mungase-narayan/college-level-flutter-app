import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/guard.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/repositories/public_profile_repository.dart';
import '../datasources/public_profile_service.dart';

class PublicProfileRepositoryImpl
    with RepositoryGuard
    implements PublicProfileRepository {
  const PublicProfileRepositoryImpl(this._service);

  final PublicProfileService _service;

  @override
  Future<Either<Failure, PublicProfile>> getPublicProfile(String username) =>
      guard(() => _service.getPublicProfile(username));
}
