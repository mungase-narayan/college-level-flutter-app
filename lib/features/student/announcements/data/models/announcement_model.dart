import '../../domain/entities/announcement.dart';

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

String _string(Object? value) => value is String ? value : '';

String? _stringOrNull(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// `fees` is a Postgres numeric, which the driver can hand over as either a
/// number or a string like `"500.00"`.
num? _num(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

List<AnnouncementFileRef> _files(Object? value) =>
    ((value as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => AnnouncementFileRef(
            id: _string(json['id']),
            url: _string(json['url']),
            name: _string(json['name']),
          ),
        )
        // A file whose url failed to resolve cannot be opened, so it is dropped
        // rather than rendered as a dead row.
        .where((file) => file.url.isNotEmpty)
        .toList(growable: false);

/// JSON → [Announcement].
class AnnouncementModel extends Announcement {
  const AnnouncementModel({
    required super.id,
    required super.title,
    required super.type,
    required super.priority,
    super.description,
    super.coverImageUrl,
    super.startDate,
    super.endDate,
    super.roomId,
    super.fees,
    super.isFree,
    super.publishedAt,
    super.attachmentFiles,
    super.registrationCount,
    super.isRegistered,
    super.registrationStatus,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) =>
      AnnouncementModel(
        id: _string(json['id']),
        title: _string(json['title']),
        type: json['type'] as String? ?? 'GENERAL',
        priority: json['priority'] as String? ?? 'MEDIUM',
        description: _stringOrNull(json['description']),
        coverImageUrl: _stringOrNull(json['coverImageUrl']),
        startDate: _stringOrNull(json['startDate']),
        endDate: _stringOrNull(json['endDate']),
        roomId: _stringOrNull(json['roomId']),
        fees: _num(json['fees']),
        isFree: json['isFree'] as bool?,
        publishedAt: _stringOrNull(json['publishedAt']),
        attachmentFiles: _files(json['attachmentFiles']),
        registrationCount: (json['registrationCount'] as num?)?.toInt() ?? 0,
        isRegistered: json['isRegistered'] as bool? ?? false,
        registrationStatus: _stringOrNull(json['registrationStatus']),
      );
}

/// JSON → [AnnouncementDetail].
class AnnouncementDetailModel extends AnnouncementDetail {
  const AnnouncementDetailModel({
    required super.id,
    required super.title,
    required super.type,
    required super.priority,
    super.description,
    super.coverImageUrl,
    super.startDate,
    super.endDate,
    super.roomId,
    super.fees,
    super.isFree,
    super.publishedAt,
    super.attachmentFiles,
    super.registrationCount,
    super.isRegistered,
    super.registrationStatus,
    super.room,
    super.author,
  });

  factory AnnouncementDetailModel.fromJson(Map<String, dynamic> json) {
    final base = AnnouncementModel.fromJson(json);
    final room = json['room'];
    final author = json['author'];

    return AnnouncementDetailModel(
      id: base.id,
      title: base.title,
      type: base.type,
      priority: base.priority,
      description: base.description,
      coverImageUrl: base.coverImageUrl,
      startDate: base.startDate,
      endDate: base.endDate,
      roomId: base.roomId,
      fees: base.fees,
      isFree: base.isFree,
      publishedAt: base.publishedAt,
      attachmentFiles: base.attachmentFiles,
      registrationCount: base.registrationCount,
      isRegistered: base.isRegistered,
      registrationStatus: base.registrationStatus,
      room: room is Map<String, dynamic>
          ? AnnouncementRoom(
              id: _string(room['id']),
              code: _string(room['code']),
              name: _stringOrNull(room['name']),
              building: _stringOrNull(room['building']),
            )
          : null,
      author: author is Map<String, dynamic>
          ? AnnouncementAuthor(
              id: _string(author['id']),
              // Blank rather than absent would render "Posted by  · …".
              fullName: _stringOrNull(author['fullName']) ?? 'Unknown',
              avatar: _stringOrNull(author['avatar']),
            )
          : null,
    );
  }
}

/// JSON → [AnnouncementRegistration].
class AnnouncementRegistrationModel extends AnnouncementRegistration {
  const AnnouncementRegistrationModel({
    required super.id,
    required super.status,
  });

  factory AnnouncementRegistrationModel.fromJson(Object? data) {
    final json = _map(data);
    return AnnouncementRegistrationModel(
      id: _string(json['id']),
      status: json['status'] as String? ?? 'REGISTERED',
    );
  }
}
