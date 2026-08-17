import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/uploaded_file.dart';

abstract class FileRepository {
  Future<Either<Failure, UploadedFile>> getFile(String fileId);

  /// Uploads a file from the device. The caller keeps the returned record's
  /// `id`, which is what every other endpoint accepts.
  Future<Either<Failure, UploadedFile>> upload({
    required String filePath,
    required String fileName,
  });

  /// The URL to hand to the platform for viewing or downloading. Resolves to a
  /// presigned URL for a private file and to `fileUrl` for a public one.
  Future<Either<Failure, String>> resolveOpenUrl(UploadedFile file);
}
