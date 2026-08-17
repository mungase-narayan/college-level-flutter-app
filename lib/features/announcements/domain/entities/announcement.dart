import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

/// One row of `GET /announcements/student/feed`.
///
/// Carries only what the student screens render. The payload also has
/// `schoolId`, `createdBy`, `status`, the three audience ids, `calendarEventId`
/// and the raw `attachments` uuid list — none of which reach the UI. `status` in
/// particular is always `PUBLISHED` on this feed, since the server filters on it.
class Announcement extends Equatable {
  const Announcement({
    required this.id,
    required this.title,
    required this.type,
    required this.priority,
    this.description,
    this.coverImageUrl,
    this.startDate,
    this.endDate,
    this.roomId,
    this.fees,
    this.isFree,
    this.publishedAt,
    this.attachmentFiles = const [],
    this.registrationCount = 0,
    this.isRegistered = false,
    this.registrationStatus,
  });

  final String id;
  final String title;

  /// One of [AnnouncementMeta.types] — but treat it as open: the server's enum
  /// has grown before, and an unknown value must render rather than throw.
  final String type;

  /// `LOW | MEDIUM | HIGH`.
  final String priority;

  final String? description;
  final String? coverImageUrl;
  final String? startDate;
  final String? endDate;

  /// Kept even though the room itself is only on the detail: the card's "Venue"
  /// chip keys off the presence of an id, exactly as the web's does.
  final String? roomId;

  final num? fees;
  final bool? isFree;
  final String? publishedAt;

  final List<AnnouncementFileRef> attachmentFiles;
  final int registrationCount;
  final bool isRegistered;

  /// `REGISTERED | CANCELLED | ATTENDED`, or null when never registered.
  final String? registrationStatus;

  bool get isEvent => type == 'EVENT';
  bool get hasAttended => registrationStatus == 'ATTENDED';

  /// Only events take registrations, so a non-event can never reach the
  /// mutation even if a page tried.
  bool get canRegister => isEvent && !isRegistered;

  /// False once attended — the web shows no button at all in that state, not a
  /// disabled one.
  bool get canCancel => isEvent && isRegistered && !hasAttended;

  /// `7 Jul 2026, 1:00 PM — 7 Jul 2026, 4:00 PM`, the start alone, or the
  /// fallback. The separator is an em dash, as on the web.
  String get dateRange {
    final start = startDate;
    if (start == null) return 'To be announced';
    final end = endDate;
    if (end == null) return Fmt.dateTime(start);
    return '${Fmt.dateTime(start)} — ${Fmt.dateTime(end)}';
  }

  /// Zero counts as free: the web tests `!a.fees`, which is falsy at 0, so a
  /// plain null check here would print `₹0` where the web prints `Free entry`.
  String get feeLabel {
    final amount = fees;
    if ((isFree ?? false) || amount == null || amount == 0) return 'Free entry';
    return '₹${Fmt.number(amount)}';
  }

  String get registeredLabel =>
      '$registrationCount ${registrationCount == 1 ? 'student' : 'students'}';

  @override
  List<Object?> get props => [
        id,
        title,
        type,
        priority,
        description,
        coverImageUrl,
        startDate,
        endDate,
        roomId,
        fees,
        isFree,
        publishedAt,
        attachmentFiles,
        registrationCount,
        isRegistered,
        registrationStatus,
      ];
}

/// `GET /announcements/student/:id` — the feed row plus the resolved room and
/// the author.
class AnnouncementDetail extends Announcement {
  const AnnouncementDetail({
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
    this.room,
    this.author,
  });

  final AnnouncementRoom? room;
  final AnnouncementAuthor? author;

  /// `Lab 2 (L-204) · Science Block`, or the fallback.
  ///
  /// An event can carry a `roomId` the student cannot resolve, in which case the
  /// card promises a venue this cannot name — the web behaves the same way.
  String get venue {
    final room = this.room;
    if (room == null) return 'To be announced';
    final name = room.name;
    return [
      if (name != null && name.isNotEmpty) '$name (${room.code})' else room.code,
      if (room.building case final building? when building.isNotEmpty) building,
    ].join(' · ');
  }

  /// The only mutation a student can perform, so it is spelled out rather than
  /// exposed as a general `copyWith`.
  AnnouncementDetail copyWithRegistration({
    required bool isRegistered,
    required int registrationCount,
    String? registrationStatus,
  }) =>
      AnnouncementDetail(
        id: id,
        title: title,
        type: type,
        priority: priority,
        description: description,
        coverImageUrl: coverImageUrl,
        startDate: startDate,
        endDate: endDate,
        roomId: roomId,
        fees: fees,
        isFree: isFree,
        publishedAt: publishedAt,
        attachmentFiles: attachmentFiles,
        registrationCount: registrationCount,
        isRegistered: isRegistered,
        registrationStatus: registrationStatus,
        room: room,
        author: author,
      );

  @override
  List<Object?> get props => [...super.props, room, author];
}

/// A resolved attachment: the server hands back the url and name already, so
/// nothing here needs a second round trip to become openable.
class AnnouncementFileRef extends Equatable {
  const AnnouncementFileRef({
    required this.id,
    required this.url,
    required this.name,
  });

  final String id;
  final String url;
  final String name;

  @override
  List<Object?> get props => [id, url, name];
}

class AnnouncementRoom extends Equatable {
  const AnnouncementRoom({
    required this.id,
    required this.code,
    this.name,
    this.building,
  });

  final String id;
  final String code;
  final String? name;
  final String? building;

  @override
  List<Object?> get props => [id, code, name, building];
}

class AnnouncementAuthor extends Equatable {
  const AnnouncementAuthor({
    required this.id,
    required this.fullName,
    this.avatar,
  });

  final String id;
  final String fullName;
  final String? avatar;

  @override
  List<Object?> get props => [id, fullName, avatar];
}

/// The registration row returned by register / cancel.
class AnnouncementRegistration extends Equatable {
  const AnnouncementRegistration({required this.id, required this.status});

  final String id;

  /// `REGISTERED | CANCELLED | ATTENDED` — read back rather than assumed, so the
  /// client never disagrees with the server about what just happened.
  final String status;

  @override
  List<Object?> get props => [id, status];
}

/// Labels, tints and icons for the type and priority vocabularies.
class AnnouncementMeta {
  const AnnouncementMeta._();

  /// All fifteen, in the order the web declares them — which is the order the
  /// filter sheet lists them in.
  static const types = [
    'GENERAL',
    'EVENT',
    'HOLIDAY',
    'EXAM',
    'RESULT',
    'ADMISSION',
    'FEE',
    'SPORTS',
    'CULTURAL',
    'ACADEMIC',
    'TIMETABLE',
    'EMERGENCY',
    'TRANSPORT',
    'SCHOLARSHIP',
    'OTHER',
  ];

  static const priorities = ['LOW', 'MEDIUM', 'HIGH'];

  static String typeLabel(String type) => switch (type) {
        'GENERAL' => 'General',
        'EVENT' => 'Event',
        'HOLIDAY' => 'Holiday',
        'EXAM' => 'Exam',
        'RESULT' => 'Result',
        'ADMISSION' => 'Admission',
        'FEE' => 'Fee',
        'SPORTS' => 'Sports',
        'CULTURAL' => 'Cultural',
        'ACADEMIC' => 'Academic',
        'TIMETABLE' => 'Timetable',
        'EMERGENCY' => 'Emergency',
        'TRANSPORT' => 'Transport',
        'SCHOLARSHIP' => 'Scholarship',
        'OTHER' => 'Other',
        // A type added server-side must show *something* rather than crash the
        // parse or render a blank chip.
        _ => type,
      };

  /// Two deliberate flattenings of the web's palette. `EVENT` uses violet rather
  /// than the theme's primary because `AppBadge` carries a [TwShade] and the two
  /// are the same hue (`#8B5CF6` against `#6E41DB`). `EMERGENCY` shares red with
  /// `EXAM` — the web's own difference is a 15% versus 10% tint, invisible in
  /// practice — so the icon and the label carry the distinction instead.
  static TwShade typeShade(String type) => switch (type) {
        'GENERAL' => TwColors.slate,
        'EVENT' => TwColors.violet,
        'HOLIDAY' => TwColors.emerald,
        'EXAM' => TwColors.red,
        'RESULT' => TwColors.blue,
        'ADMISSION' => TwColors.teal,
        'FEE' => TwColors.amber,
        'SPORTS' => TwColors.orange,
        'CULTURAL' => TwColors.pink,
        'ACADEMIC' => TwColors.indigo,
        'TIMETABLE' => TwColors.cyan,
        'EMERGENCY' => TwColors.red,
        'TRANSPORT' => TwColors.lime,
        'SCHOLARSHIP' => TwColors.fuchsia,
        'OTHER' => TwColors.gray,
        _ => TwColors.slate,
      };

  static IconData typeIcon(String type) => switch (type) {
        'GENERAL' => Icons.campaign_outlined,
        'EVENT' => Icons.event_outlined,
        'HOLIDAY' => Icons.beach_access_outlined,
        'EXAM' => Icons.edit_note_outlined,
        'RESULT' => Icons.grading_outlined,
        'ADMISSION' => Icons.how_to_reg_outlined,
        'FEE' => Icons.payments_outlined,
        'SPORTS' => Icons.sports_soccer_outlined,
        'CULTURAL' => Icons.theater_comedy_outlined,
        'ACADEMIC' => Icons.school_outlined,
        'TIMETABLE' => Icons.calendar_view_week_outlined,
        // Carries the distinction red alone cannot.
        'EMERGENCY' => Icons.warning_amber_rounded,
        'TRANSPORT' => Icons.directions_bus_outlined,
        'SCHOLARSHIP' => Icons.workspace_premium_outlined,
        'OTHER' => Icons.more_horiz_rounded,
        _ => Icons.campaign_outlined,
      };

  static String priorityLabel(String priority) => switch (priority) {
        'LOW' => 'Low',
        'MEDIUM' => 'Medium',
        'HIGH' => 'High',
        _ => priority,
      };

  /// Not `AppBadge.status`, whose `statusShade` has no `low` or `high` case and
  /// would quietly render both as slate.
  static TwShade priorityShade(String priority) => switch (priority) {
        'LOW' => TwColors.slate,
        'MEDIUM' => TwColors.amber,
        'HIGH' => TwColors.red,
        _ => TwColors.slate,
      };

  /// The server's own default. The web asks for 24 — a figure chosen for a
  /// four-column desktop grid, which means nothing on one column.
  static const pageSize = 12;
}
