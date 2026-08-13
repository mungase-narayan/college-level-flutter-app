import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/uploaded_file.dart';

abstract class FileRepository {
  Future<Either<Failure, UploadedFile>> getFile(String fileId);

  /// The URL to hand to the platform for viewing or downloading. Resolves to a
  /// presigned URL for a private file and to `fileUrl` for a public one.
  Future<Either<Failure, String>> resolveOpenUrl(UploadedFile file);
}
