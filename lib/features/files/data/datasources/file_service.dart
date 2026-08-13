import '../../../../core/constants/api_urls.dart';
import '../../../../core/network/dio_client.dart';
import '../models/uploaded_file_model.dart';

/// Raw HTTP for the file endpoints — the port of `src/api/file`.
class FileService {
  const FileService(this._client);

  final DioClient _client;

  /// `GET /files/:id` — the file's metadata, including its name and category.
  Future<UploadedFileModel> getFile(String fileId) async {
    final response = await _client.get(
      ApiUrls.file(fileId),
      parse: (data) =>
          UploadedFileModel.fromJson((data as Map<String, dynamic>?) ?? const {}),
    );
    return response.data;
  }

  /// `GET /files/:id/presigned-url` — a short-lived URL for a private file.
  ///
  /// This is what makes an attachment openable at all: every `/files/*` route
  /// is behind `verifyJWT`, and handing a bare API URL to the OS browser sends
  /// no `Authorization` header.
  Future<String> getPresignedUrl(String fileId) async {
    final response = await _client.get(
      ApiUrls.filePresignedUrl(fileId),
      parse: (data) {
        // The endpoint has been seen returning both a bare string and an
        // object, so both are accepted rather than guessing.
        if (data is String) return data;
        final json = (data as Map<String, dynamic>?) ?? const {};
        return (json['url'] ?? json['presignedUrl'] ?? json['fileUrl'] ?? '')
            as String;
      },
    );
    return response.data;
  }
}
