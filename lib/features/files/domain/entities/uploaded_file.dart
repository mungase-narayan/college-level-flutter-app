import 'package:equatable/equatable.dart';

/// A row from the `files` table — the payload of `GET /files/:id`, and the port
/// of the `UploadedFile` interface in `src/types/course.types.ts`.
///
/// Course materials store attachments as bare file uuids, so every attachment
/// has to be resolved through this before it can be named, sized, or opened.
class UploadedFile extends Equatable {
  const UploadedFile({
    required this.id,
    required this.originalName,
    required this.fileUrl,
    required this.contentType,
    required this.category,
    required this.isPublic,
    this.fileName,
    this.fileExtension,
    this.fileSize,
  });

  final String id;
  final String originalName;

  /// The object-store URL. Only directly usable when [isPublic]; a private file
  /// needs `GET /files/:id/presigned-url` first.
  final String fileUrl;
  final String contentType;
  final FileCategory category;
  final bool isPublic;
  final String? fileName;
  final String? fileExtension;
  final int? fileSize;

  /// The name worth showing in a row, falling back through the stored names.
  String get displayName {
    if (originalName.trim().isNotEmpty) return originalName;
    if ((fileName ?? '').trim().isNotEmpty) return fileName!;
    return id;
  }

  bool get isPdf => contentType == 'application/pdf';

  /// `1.4 MB`. Null when the backend didn't record a size.
  String? get readableSize {
    final bytes = fileSize;
    if (bytes == null || bytes <= 0) return null;
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  @override
  List<Object?> get props => [id, fileUrl, contentType, category, isPublic];
}

/// The backend's `fileCategory` enum (`file-storage.validator.ts`), which drives
/// the row icon and whether a preview is possible — the same switch
/// `rowIconFor()` makes on the web.
enum FileCategory {
  image,
  video,
  audio,
  document,
  other;

  static FileCategory parse(String? raw) => switch (raw?.toLowerCase()) {
        'image' => FileCategory.image,
        'video' => FileCategory.video,
        'audio' => FileCategory.audio,
        'document' => FileCategory.document,
        _ => FileCategory.other,
      };
}
