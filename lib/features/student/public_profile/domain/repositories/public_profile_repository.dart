import 'package:dartz/dartz.dart';

import '../../../../../core/error/failures.dart';
import '../entities/public_profile.dart';

abstract class PublicProfileRepository {
  Future<Either<Failure, PublicProfile>> getPublicProfile(String username);
}
