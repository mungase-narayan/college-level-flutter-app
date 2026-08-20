import 'package:equatable/equatable.dart';

/// The tenant the user belongs to, as returned inside the login payload.
class School extends Equatable {
  const School({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    this.config,
  });

  final String id;
  final String name;
  final String code;
  final String status;
  final SchoolConfig? config;

  @override
  List<Object?> get props => [id, name, code, status, config];
}

/// Per-school branding.
///
/// Note the React app **stores** `primaryColor`/`secondaryColor` but never
/// injects them into the theme — `useSchoolBranding` only sets the document
/// title and favicon. This client matches that behaviour: the colours are
/// displayed as swatches on the settings screen, not applied to the palette.
class SchoolConfig extends Equatable {
  const SchoolConfig({
    this.logo,
    this.logoDark,
    this.favicon,
    this.bannerImage,
    this.primaryColor,
    this.secondaryColor,
    this.appName,
  });

  final String? logo;
  final String? logoDark;
  final String? favicon;
  final String? bannerImage;
  final String? primaryColor;
  final String? secondaryColor;
  final String? appName;

  @override
  List<Object?> get props => [
        logo,
        logoDark,
        favicon,
        bannerImage,
        primaryColor,
        secondaryColor,
        appName,
      ];
}
