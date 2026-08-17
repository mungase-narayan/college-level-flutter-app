import 'package:equatable/equatable.dart';

/// Which slice of the feed the hub is showing.
///
/// An enum rather than two booleans because the server treats `mine` and
/// `shared` as antagonistic — `shared` excludes your own notes and `mine`
/// requires them, so sending both returns nothing, forever.
enum NotesTab { all, mine, shared }

/// Everything a note carries in both the feed and the detail.
///
/// [NoteListItem] and [NoteDetail] are siblings rather than one extending the
/// other: the list has an [NoteListItem.excerpt] and no body, the detail has a
/// body and no excerpt, so either inheritance direction would force a field to
/// be faked. Sharing a base means a widget typed on [NoteBase] serves both, and
/// a field added to one and forgotten on the other fails to compile.
abstract class NoteBase extends Equatable {
  const NoteBase({
    required this.id,
    required this.title,
    required this.visibility,
    required this.authorRole,
    required this.author,
    required this.likeCount,
    required this.commentCount,
    required this.viewCount,
    required this.liked,
    required this.isOwner,
    required this.isEdited,
    this.tags = const [],
    this.link = const NoteLinkContext(),
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;

  /// `private` or `published`. A private note is visible only to its author and
  /// to anyone it has been shared with.
  final String visibility;

  /// `student`, `teacher`, or `admin`.
  final String authorRole;
  final NoteAuthor author;
  final int likeCount;
  final int commentCount;
  final int viewCount;
  final bool liked;
  final bool isOwner;
  final bool isEdited;
  final List<String> tags;

  /// What the note is filed against, when it was written from a material or a
  /// practice question.
  final NoteLinkContext link;

  final DateTime? createdAt;

  /// What the card's relative time reads from — the web shows `Edited {ago}`
  /// off this, not off [createdAt].
  final DateTime? updatedAt;

  bool get isPrivate => visibility == 'private';

  /// Whether the note hangs off a material or a question. The feed payload
  /// carries only the ids, never the titles, so this can mark a note as linked
  /// but never name what to.
  bool get isLinked => link.materialId != null || link.questionId != null;

  @override
  List<Object?> get props => [
        id,
        title,
        visibility,
        authorRole,
        author,
        likeCount,
        commentCount,
        viewCount,
        liked,
        isOwner,
        isEdited,
        tags,
        link,
        createdAt,
        updatedAt,
      ];
}

/// A note in the feed — `GET /notes`.
///
/// Carries a plain-text [excerpt] rather than the markdown body; the body only
/// comes back from `GET /notes/:id`.
class NoteListItem extends NoteBase {
  const NoteListItem({
    required super.id,
    required super.title,
    required this.excerpt,
    required super.visibility,
    required super.authorRole,
    required super.author,
    required super.likeCount,
    required super.commentCount,
    required super.viewCount,
    required super.liked,
    required super.isOwner,
    required super.isEdited,
    super.tags,
    super.link,
    super.createdAt,
    super.updatedAt,
    this.attachmentCount = 0,
  });

  /// Already stripped of markdown and truncated server-side, so it renders as
  /// plain text rather than through the markdown renderer.
  final String excerpt;

  final int attachmentCount;

  /// The row after a like, using the server's recounted total.
  NoteListItem copyWithLike({required bool liked, required int likeCount}) =>
      NoteListItem(
        id: id,
        title: title,
        excerpt: excerpt,
        visibility: visibility,
        authorRole: authorRole,
        author: author,
        likeCount: likeCount,
        commentCount: commentCount,
        viewCount: viewCount,
        liked: liked,
        isOwner: isOwner,
        isEdited: isEdited,
        tags: tags,
        link: link,
        createdAt: createdAt,
        updatedAt: updatedAt,
        attachmentCount: attachmentCount,
      );

  @override
  List<Object?> get props => [...super.props, excerpt, attachmentCount];
}

/// One note with its markdown body — `GET /notes/:id`.
class NoteDetail extends NoteBase {
  const NoteDetail({
    required super.id,
    required super.title,
    required this.content,
    required super.visibility,
    required super.authorRole,
    required super.author,
    required super.likeCount,
    required super.commentCount,
    required super.viewCount,
    required super.liked,
    required super.isOwner,
    required super.isEdited,
    super.tags,
    super.link,
    super.createdAt,
    super.updatedAt,
    this.attachmentFiles = const [],
  });

  /// Markdown, so a note can carry the same rich blocks a material can.
  final String content;

  /// Resolved server-side to `{id, url, name}`. Uploading is not yet supported
  /// here, but a note written on the web can carry files, and hiding them would
  /// make the card's attachment count a dead number.
  final List<NoteAttachment> attachmentFiles;

  NoteDetail copyWithLike({required bool liked, required int likeCount}) =>
      NoteDetail(
        id: id,
        title: title,
        content: content,
        visibility: visibility,
        authorRole: authorRole,
        author: author,
        likeCount: likeCount,
        commentCount: commentCount,
        viewCount: viewCount,
        liked: liked,
        isOwner: isOwner,
        isEdited: isEdited,
        tags: tags,
        link: link,
        createdAt: createdAt,
        updatedAt: updatedAt,
        attachmentFiles: attachmentFiles,
      );

  @override
  List<Object?> get props => [...super.props, content, attachmentFiles];
}

class NoteAuthor extends Equatable {
  const NoteAuthor({required this.id, this.fullName, this.avatar});

  final String id;
  final String? fullName;
  final String? avatar;

  String get displayName {
    final name = (fullName ?? '').trim();
    return name.isEmpty ? 'Unknown' : name;
  }

  @override
  List<Object?> get props => [id, fullName, avatar];
}

class NoteAttachment extends Equatable {
  const NoteAttachment({
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

/// Aggregates across the caller's own notes — `GET /notes/my-stats`.
class MyNotesStats extends Equatable {
  const MyNotesStats({
    this.totalViews = 0,
    this.totalLikes = 0,
    this.totalComments = 0,
    this.publishedNotes = 0,
  });

  final int totalViews;
  final int totalLikes;
  final int totalComments;
  final int publishedNotes;

  static const empty = MyNotesStats();

  @override
  List<Object?> get props =>
      [totalViews, totalLikes, totalComments, publishedNotes];
}

/// What `POST /notes/:id/like` answers with — the toggle's new state and the
/// recounted total.
class NoteLikeResult extends Equatable {
  const NoteLikeResult({required this.liked, required this.likeCount});

  final bool liked;
  final int likeCount;

  @override
  List<Object?> get props => [liked, likeCount];
}

/// The link a note is filed under. Notes written from a material are filtered
/// by, and created against, its `courseId` + `materialId`.
class NoteLinkContext extends Equatable {
  const NoteLinkContext({
    this.courseId,
    this.topicId,
    this.materialId,
    this.questionId,
  });

  final String? courseId;
  final String? topicId;
  final String? materialId;
  final String? questionId;

  @override
  List<Object?> get props => [courseId, topicId, materialId, questionId];
}

/// The body of `POST /notes`.
class CreateNoteInput extends Equatable {
  const CreateNoteInput({
    required this.title,
    required this.content,
    required this.link,
    this.tags = const [],
    this.visibility = 'published',
  });

  final String title;

  /// Markdown, so a note can carry the same rich blocks a material can.
  final String content;
  final NoteLinkContext link;
  final List<String> tags;

  /// Always sent explicitly: the server would otherwise default a new note to
  /// `private`, while the web's composer defaults to published.
  final String visibility;

  // Deliberately no `attachments` key. Uploading is not supported here yet, and
  // the server treats the key's *presence* as "replace the list" — so sending
  // an empty one would wipe files a student added on the web.
  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'tags': tags,
        'visibility': visibility,
        'courseId': link.courseId,
        'topicId': link.topicId,
        'materialId': link.materialId,
        'questionId': link.questionId,
      };

  @override
  List<Object?> get props => [title, content, link, tags, visibility];
}

/// The body of `PATCH /notes/:id`.
///
/// Partial by design: the server updates only the keys present. Null therefore
/// means "leave alone" — nothing here is clearable, so an empty `tags` list is
/// a real value distinct from null and no `clear*` flags are needed.
class UpdateNoteInput extends Equatable {
  const UpdateNoteInput({
    required this.id,
    this.title,
    this.content,
    this.tags,
    this.visibility,
  });

  final String id;
  final String? title;
  final String? content;
  final List<String>? tags;
  final String? visibility;

  /// Never emits `attachments` — see [CreateNoteInput.toJson].
  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (content != null) 'content': content,
        if (tags != null) 'tags': tags,
        if (visibility != null) 'visibility': visibility,
      };

  @override
  List<Object?> get props => [id, title, content, tags, visibility];
}

/// Labels, limits, and the small pure functions the note UI needs.
class NoteMeta {
  const NoteMeta._();

  /// The server's own default page size.
  static const pageSize = 12;

  /// What the embedded material/question tab asks for — it has no paging, so it
  /// takes a bigger single bite.
  static const embeddedPageSize = 30;

  static const titleMax = 250;
  static const contentMax = 50000;
  static const tagsMax = 8;
  static const tagMax = 30;

  static const sorts = ['recent', 'most_liked', 'oldest'];

  static String sortLabel(String sort) => switch (sort) {
        'recent' => 'Newest',
        'most_liked' => 'Most liked',
        'oldest' => 'Oldest',
        _ => sort,
      };

  static String visibilityLabel(String? visibility) => switch (visibility) {
        'private' => 'Private',
        'published' => 'Published',
        _ => 'All access',
      };

  /// The badge beside an author's name. Students get none — only a teacher or
  /// an admin is called out, exactly as the web does.
  static String? roleBadge(String role) => switch (role) {
        'teacher' => 'Teacher',
        'admin' => 'Admin',
        _ => null,
      };

  /// `999`, `1K`, `1.1K`, `12.3K` — the web's own rounding, which keeps one
  /// decimal only once the remainder is at least 100.
  static String compact(int value) {
    if (value < 1000) return '$value';
    final thousands = value / 1000;
    return '${thousands.toStringAsFixed(value % 1000 >= 100 ? 1 : 0)}K';
  }

  /// `just now`, `5m ago`, `3h ago`, `2d ago`, `3w ago`, `5mo ago`, `2y ago`.
  ///
  /// Not `Fmt.relative`, which switches to an absolute date past a week — the
  /// card wants the ladder to keep going.
  static String timeAgo(DateTime? value, {DateTime? now}) {
    if (value == null) return '';
    final seconds =
        (now ?? DateTime.now()).difference(value).inSeconds.clamp(0, 1 << 62);
    if (seconds < 60) return 'just now';

    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';

    final hours = minutes ~/ 60;
    if (hours < 24) return '${hours}h ago';

    final days = hours ~/ 24;
    if (days < 7) return '${days}d ago';

    final weeks = days ~/ 7;
    if (weeks < 5) return '${weeks}w ago';

    final months = days ~/ 30;
    if (months < 12) return '${months}mo ago';

    return '${days ~/ 365}y ago';
  }

  /// The detail page's `{n} min read`, at the web's 200 words per minute.
  static int readingMinutes(String text) {
    final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return (words.length / 200).round().clamp(1, 1 << 31);
  }

  /// Normalises one typed tag, or null when it cannot be used.
  ///
  /// Strips leading hashes the way the web does, and rejects anything empty or
  /// over the server's limit.
  static String? normaliseTag(String raw) {
    final value = raw.trim().replaceFirst(RegExp(r'^#+'), '').trim();
    if (value.isEmpty || value.length > tagMax) return null;
    return value;
  }
}
