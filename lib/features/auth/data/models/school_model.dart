import '../../domain/entities/school.dart';

/// JSON ↔ [School].
class SchoolModel extends School {
  const SchoolModel({
    required super.id,
    required super.name,
    required super.code,
    required super.status,
    super.config,
  });

  factory SchoolModel.fromJson(Map<String, dynamic> json) => SchoolModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
        status: json['status'] as String? ?? 'active',
        config: json['config'] is Map<String, dynamic>
            ? SchoolConfigModel.fromJson(json['config'] as Map<String, dynamic>)
            : null,
      );

  factory SchoolModel.fromEntity(School school) => SchoolModel(
        id: school.id,
        name: school.name,
        code: school.code,
        status: school.status,
        config: school.config,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'status': status,
        'config': config == null ? null : SchoolConfigModel.fromEntity(config!).toJson(),
      };
}

/// JSON ↔ [SchoolConfig].
class SchoolConfigModel extends SchoolConfig {
  const SchoolConfigModel({
    super.logo,
    super.logoDark,
    super.favicon,
    super.bannerImage,
    super.primaryColor,
    super.secondaryColor,
    super.appName,
  });

  factory SchoolConfigModel.fromJson(Map<String, dynamic> json) => SchoolConfigModel(
        logo: json['logo'] as String?,
        logoDark: json['logoDark'] as String?,
        favicon: json['favicon'] as String?,
        bannerImage: json['bannerImage'] as String?,
        primaryColor: json['primaryColor'] as String?,
        secondaryColor: json['secondaryColor'] as String?,
        appName: json['appName'] as String?,
      );

  factory SchoolConfigModel.fromEntity(SchoolConfig config) => SchoolConfigModel(
        logo: config.logo,
        logoDark: config.logoDark,
        favicon: config.favicon,
        bannerImage: config.bannerImage,
        primaryColor: config.primaryColor,
        secondaryColor: config.secondaryColor,
        appName: config.appName,
      );

  Map<String, dynamic> toJson() => {
        'logo': logo,
        'logoDark': logoDark,
        'favicon': favicon,
        'bannerImage': bannerImage,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'appName': appName,
      };
}
