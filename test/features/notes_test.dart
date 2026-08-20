import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/shared/notes/data/models/note_model.dart';
import 'package:college_level/features/shared/notes/domain/entities/note.dart';
import 'package:college_level/features/shared/notes/domain/usecases/notes_usecases.dart';
import 'package:college_level/features/shared/notes/presentation/bloc/material_notes_cubit.dart';
import 'package:college_level/features/shared/notes/presentation/bloc/note_detail_cubit.dart';
import 'package:college_level/features/shared/notes/presentation/bloc/notes_hub_cubit.dart';

class _MockList extends Mock implements ListNotesUseCase {}

class _MockGet extends Mock implements GetNoteUseCase {}

class _MockCreate extends Mock implements CreateNoteUseCase {}

class _MockUpdate extends Mock implements UpdateNoteUseCase {}

class _MockDelete extends Mock implements DeleteNoteUseCase {}

class _MockToggleLike extends Mock implements ToggleNoteLikeUseCase {}

NoteListItem _item(String id, {int likeCount = 2, bool liked = false}) =>
    NoteListItem(
      id: id,
      title: 'Note $id',
      excerpt: 'An excerpt',
      visibility: 'published',
      authorRole: 'student',
      author: const NoteAuthor(id: 'u1', fullName: 'Ada Lovelace'),
      likeCount: likeCount,
      commentCount: 0,
      viewCount: 3,
      liked: liked,
      isOwner: false,
      isEdited: false,
    );

Paginated<NoteListItem> _page({
  required int page,
  required int totalPages,
  List<NoteListItem>? items,
}) =>
    Paginated<NoteListItem>(
      items: items ?? [_item('$page-0'), _item('$page-1')],
      pagination: Pagination(
        page: page,
        limit: 12,
        total: totalPages * 2,
        totalPages: totalPages,
      ),
    );

NoteDetail _detail({int likeCount = 4, bool liked = false}) => NoteDetail(
      id: 'n1',
      title: 'Note',
      content: 'Body',
      visibility: 'published',
      authorRole: 'student',
      author: const NoteAuthor(id: 'u1', fullName: 'Ada Lovelace'),
      likeCount: likeCount,
      commentCount: 1,
      viewCount: 9,
      liked: liked,
      isOwner: true,
      isEdited: false,
    );

void main() {
  late _MockList list;
  late _MockCreate create;
  late _MockToggleLike toggleLike;
  late _MockDelete delete;
  late NotesHubCubit cubit;

  List<ListNotesParams> captured() =>
      verify(() => list(captureAny())).captured.cast<ListNotesParams>();

  setUpAll(() {
    registerFallbackValue(const ListNotesParams());
    registerFallbackValue(const IdParams('n1'));
    registerFallbackValue(
      const CreateNoteInput(title: 't', content: 'c', link: NoteLinkContext()),
    );
    registerFallbackValue(const UpdateNoteInput(id: 'n1'));
  });

  setUp(() {
    list = _MockList();
    create = _MockCreate();
    toggleLike = _MockToggleLike();
    delete = _MockDelete();

    when(() => list(any())).thenAnswer(
      (_) async =>
          Right<Failure, Paginated<NoteListItem>>(_page(page: 1, totalPages: 1)),
    );
    cubit = NotesHubCubit(
      list: list,
      create: create,
      toggleLikeUseCase: toggleLike,
      deleteUseCase: delete,
    );
  });

  tearDown(() => cubit.close());

  group('NotesHubCubit', () {
    test('asks for the server page size', () async {
      await cubit.load();
      expect(captured().single.limit, 12);
    });

    /// The two flags are antagonistic server-side — shared excludes your own
    /// notes and mine requires them — so the enum must never produce both.
    test('each tab maps to exactly one flag', () async {
      await cubit.setTab(NotesTab.mine);
      await cubit.setTab(NotesTab.shared);
      await cubit.setTab(NotesTab.all);

      final params = captured();
      expect(params[0].mine, isTrue);
      expect(params[0].shared, isFalse);
      expect(params[1].shared, isTrue);
      expect(params[1].mine, isFalse);
      expect(params[2].mine, isFalse);
      expect(params[2].shared, isFalse);
    });

    /// Access only narrows your own notes, but the choice has to survive a trip
    /// through another tab — the web behaves the same way.
    test('visibility is dropped off My notes but remembered', () async {
      await cubit.setTab(NotesTab.mine);
      await cubit.setVisibility('private');
      await cubit.setTab(NotesTab.all);
      await cubit.setTab(NotesTab.mine);

      final params = captured();
      expect(params[1].visibility, 'private');
      expect(params[2].visibility, isNull, reason: 'not sent off My notes');
      expect(params[3].visibility, 'private', reason: 'restored on return');
      expect(cubit.query.visibility, 'private');
    });

    /// The server matches tags exactly and case-sensitively, so the value must
    /// travel untouched.
    test('a tag is sent with its case intact', () async {
      await cubit.setTag('DSA');
      expect(captured().single.tag, 'DSA');
    });

    test('a filter change restarts at the first page', () async {
      when(() => list(any())).thenAnswer((invocation) async {
        final params = invocation.positionalArguments.first as ListNotesParams;
        return Right<Failure, Paginated<NoteListItem>>(
          _page(page: params.page, totalPages: 3),
        );
      });

      await cubit.load();
      await cubit.loadMore();
      await cubit.setSearch('tcp');

      // One capture pass: `verify` consumes the recorded calls, so counting
      // and inspecting them cannot be two separate verifications.
      final last = captured().last;
      expect(last.page, 1);
      expect(last.query, 'tcp');
    });

    test('an unchanged search term does not refire', () async {
      await cubit.setSearch('tcp');
      await cubit.setSearch('  tcp  ');

      verify(() => list(any())).called(1);
    });

    test('an empty search clears the term rather than sending a blank',
        () async {
      await cubit.setSearch('tcp');
      await cubit.setSearch('');

      expect(captured().last.query, isNull);
    });

    test('clearFilters drops the search, tag and access together', () async {
      await cubit.setTab(NotesTab.mine);
      await cubit.setSearch('tcp');
      await cubit.setTag('dsa');
      await cubit.setVisibility('private');
      await cubit.clearFilters();

      final last = captured().last;
      expect(last.query, isNull);
      expect(last.tag, isNull);
      expect(last.visibility, isNull);
      expect(cubit.query.hasFilters, isFalse);
    });

    test('a tab is not a filter to clear', () async {
      await cubit.setTab(NotesTab.shared);
      expect(cubit.query.hasFilters, isFalse);
    });

    test('loadMore appends the next page', () async {
      when(() => list(any())).thenAnswer((invocation) async {
        final params = invocation.positionalArguments.first as ListNotesParams;
        return Right<Failure, Paginated<NoteListItem>>(
          _page(page: params.page, totalPages: 2),
        );
      });

      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.data!.items, hasLength(4));
      expect(captured().map((p) => p.page), [1, 2]);
    });

    test('loadMore stops at the last page', () async {
      await cubit.load();
      await cubit.loadMore();

      verify(() => list(any())).called(1);
    });

    test('a failed loadMore keeps what is already listed', () async {
      var call = 0;
      when(() => list(any())).thenAnswer((_) async {
        call++;
        if (call == 1) {
          return Right<Failure, Paginated<NoteListItem>>(
            _page(page: 1, totalPages: 3),
          );
        }
        return const Left<Failure, Paginated<NoteListItem>>(
          NetworkFailure('offline'),
        );
      });

      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.data!.items, hasLength(2));
      expect(cubit.state.failure, isNotNull);
    });

    /// Server-authoritative: the toggle lives on the server, so its recount
    /// wins even when it disagrees with what the row was showing.
    test('a like patches one row from the server count', () async {
      when(() => toggleLike(any())).thenAnswer(
        (_) async => const Right<Failure, NoteLikeResult>(
          NoteLikeResult(liked: true, likeCount: 7),
        ),
      );

      await cubit.load();
      final target = cubit.state.data!.items.first.id;
      await cubit.toggleLike(target);

      final items = cubit.state.data!.items;
      expect(items.first.liked, isTrue);
      expect(items.first.likeCount, 7);
      expect(items.last.likeCount, 2, reason: 'other rows untouched');
      // Patching, not reloading — a reload would discard every later page.
      verify(() => list(any())).called(1);
    });

    test('a failed like leaves the row alone', () async {
      when(() => toggleLike(any())).thenAnswer(
        (_) async =>
            const Left<Failure, NoteLikeResult>(NetworkFailure('offline')),
      );

      await cubit.load();
      final failure = await cubit.toggleLike(cubit.state.data!.items.first.id);

      expect(failure, isNotNull);
      expect(cubit.state.data!.items.first.liked, isFalse);
      expect(cubit.state.data!.items.first.likeCount, 2);
    });

    /// Two toggles would cancel out and leave the row where it started.
    test('a double tap only likes once', () async {
      final gate = Completer<Either<Failure, NoteLikeResult>>();
      when(() => toggleLike(any())).thenAnswer((_) => gate.future);

      await cubit.load();
      final id = cubit.state.data!.items.first.id;
      final first = cubit.toggleLike(id);
      await cubit.toggleLike(id);
      gate.complete(
        const Right<Failure, NoteLikeResult>(
          NoteLikeResult(liked: true, likeCount: 3),
        ),
      );
      await first;

      verify(() => toggleLike(any())).called(1);
    });

    test('create returns the new id and reloads', () async {
      when(() => create(any()))
          .thenAnswer((_) async => const Right<Failure, String>('new-id'));

      final result = await cubit.create(
        const CreateNoteInput(
          title: 't',
          content: 'c',
          link: NoteLinkContext(),
        ),
      );

      expect(result.getOrElse(() => ''), 'new-id');
      verify(() => list(any())).called(1);
    });

    test('a failed create does not reload', () async {
      when(() => create(any())).thenAnswer(
        (_) async => const Left<Failure, String>(ServerFailure('nope')),
      );

      await cubit.create(
        const CreateNoteInput(
          title: 't',
          content: 'c',
          link: NoteLinkContext(),
        ),
      );

      verifyNever(() => list(any()));
    });
  });

  group('NoteDetailCubit', () {
    late _MockGet get;
    late _MockUpdate update;

    NoteDetailCubit build(NoteDetail seed) {
      when(() => get(any()))
          .thenAnswer((_) async => Right<Failure, NoteDetail>(seed));
      return NoteDetailCubit(
        noteId: 'n1',
        getNote: get,
        updateUseCase: update,
        deleteUseCase: delete,
        toggleLikeUseCase: toggleLike,
      );
    }

    setUp(() {
      get = _MockGet();
      update = _MockUpdate();
      when(() => toggleLike(any())).thenAnswer(
        (_) async => const Right<Failure, NoteLikeResult>(
          NoteLikeResult(liked: true, likeCount: 11),
        ),
      );
      when(() => update(any()))
          .thenAnswer((_) async => const Right<Failure, Unit>(unit));
      when(() => delete(any()))
          .thenAnswer((_) async => const Right<Failure, Unit>(unit));
    });

    test('a like takes the server count verbatim', () async {
      final detail = build(_detail());
      addTearDown(detail.close);
      await detail.load();

      expect(await detail.toggleLike(), isNull);
      expect(detail.state.data!.liked, isTrue);
      expect(detail.state.data!.likeCount, 11);
    });

    /// `PATCH` answers with the raw database row — no author, no counts — and
    /// the server decides the new `isEdited`, so the note must be re-fetched.
    test('an edit reloads rather than splicing the response', () async {
      final detail = build(_detail());
      addTearDown(detail.close);
      await detail.load();

      expect(await detail.update(const UpdateNoteInput(id: 'n1', title: 'x')),
          isNull);

      verify(() => get(any())).called(2);
    });

    test('a failed edit reports the failure and does not reload', () async {
      when(() => update(any())).thenAnswer(
        (_) async => const Left<Failure, Unit>(ForbiddenFailure('not yours')),
      );

      final detail = build(_detail());
      addTearDown(detail.close);
      await detail.load();

      expect(
        await detail.update(const UpdateNoteInput(id: 'n1', title: 'x')),
        isA<ForbiddenFailure>(),
      );
      verify(() => get(any())).called(1);
    });
  });

  group('MaterialNotesCubit scoping', () {
    MaterialNotesCubit build(NoteLinkContext link) => MaterialNotesCubit(
          list: list,
          create: create,
          link: link,
        );

    /// The regression guard: this used to send only `materialId`, which is null
    /// for a question — so the request carried no filter and listed every note
    /// in the school.
    test('a question-linked tab filters by the question', () async {
      final tab = build(const NoteLinkContext(questionId: 'q1'));
      addTearDown(tab.close);
      await tab.load();

      final params = captured().single;
      expect(params.questionId, 'q1');
      expect(params.materialId, isNull);
      expect(params.limit, 30);
    });

    test('a material-linked tab filters by the material alone', () async {
      final tab = build(
        const NoteLinkContext(courseId: 'c1', materialId: 'm1'),
      );
      addTearDown(tab.close);
      await tab.load();

      final params = captured().single;
      expect(params.materialId, 'm1');
      // Redundant alongside the material, and it would drop a note whose
      // course was never set.
      expect(params.courseId, isNull);
    });

    test('a course-only link still filters by the course', () async {
      final tab = build(const NoteLinkContext(courseId: 'c1'));
      addTearDown(tab.close);
      await tab.load();

      expect(captured().single.courseId, 'c1');
    });
  });

  group('models', () {
    test('parses the double-nested feed page', () {
      final page = Paginated<NoteListItemModel>.fromJson(
        const {
          'data': [
            {
              'id': 'n1',
              'title': 'TCP',
              'excerpt': 'Handshake',
              'materialId': 'm1',
              'updatedAt': '2026-08-17T10:00:00.000Z',
              'tags': ['dsa'],
            },
          ],
          'pagination': {
            'page': 1,
            'limit': 12,
            'total': 3,
            'totalPages': 1,
          },
        },
        NoteListItemModel.fromJson,
      );

      final note = page.items.single;
      expect(note.title, 'TCP');
      expect(note.isLinked, isTrue);
      expect(note.updatedAt, isNotNull);
      expect(note.tags, ['dsa']);
      expect(page.pagination.totalPages, 1);
    });

    test('absent fields fall back rather than throwing', () {
      final note = NoteListItemModel.fromJson(const {'id': 'n1'});

      expect(note.author.displayName, 'Unknown');
      expect(note.likeCount, 0);
      expect(note.tags, isEmpty);
      expect(note.isLinked, isFalse);
      expect(note.visibility, 'published');
    });

    test('the detail parses its body and drops an unresolvable file', () {
      final note = NoteDetailModel.fromJson(const {
        'id': 'n1',
        'content': '# Heading',
        'attachmentFiles': [
          {'id': 'f1', 'url': 'https://x/1.pdf', 'name': 'Rules.pdf'},
          {'id': 'f2', 'name': 'Broken.pdf'},
        ],
      });

      expect(note.content, '# Heading');
      expect(note.attachmentFiles, hasLength(1));
    });

    /// The create response is the raw row — no author, no counts — so only the
    /// id is worth reading back.
    test('the created id is read off the raw row', () {
      expect(noteIdFromJson(const {'id': 'new-id', 'title': 't'}), 'new-id');
      expect(noteIdFromJson(null), '');
    });

    /// The server treats the key's *presence* as "replace the list", so sending
    /// one would wipe files uploaded on the web.
    test('neither write body ever mentions attachments', () {
      const create = CreateNoteInput(
        title: 't',
        content: 'c',
        link: NoteLinkContext(materialId: 'm1'),
      );
      const update = UpdateNoteInput(id: 'n1', title: 't');

      expect(create.toJson().containsKey('attachments'), isFalse);
      expect(update.toJson().containsKey('attachments'), isFalse);
      // The link fields are hoisted to the top level, not nested.
      expect(create.toJson()['materialId'], 'm1');
    });

    test('an update omits the fields it is not changing', () {
      const input = UpdateNoteInput(id: 'n1', title: 'New');

      expect(input.toJson(), {'title': 'New'});
    });

    test('stats default to zero', () {
      final stats = MyNotesStatsModel.fromJson(null);

      expect(stats.totalViews, 0);
      expect(stats.publishedNotes, 0);
    });
  });

  group('NoteMeta', () {
    test('compacts counts the way the web does', () {
      expect(NoteMeta.compact(999), '999');
      expect(NoteMeta.compact(1000), '1K');
      expect(NoteMeta.compact(1050), '1K');
      expect(NoteMeta.compact(1100), '1.1K');
      expect(NoteMeta.compact(12345), '12.3K');
    });

    test('climbs the relative-time ladder past a week', () {
      final now = DateTime(2026, 8, 17, 12);
      String ago(Duration d) => NoteMeta.timeAgo(now.subtract(d), now: now);

      expect(ago(const Duration(seconds: 5)), 'just now');
      expect(ago(const Duration(minutes: 5)), '5m ago');
      expect(ago(const Duration(hours: 3)), '3h ago');
      expect(ago(const Duration(days: 2)), '2d ago');
      expect(ago(const Duration(days: 21)), '3w ago');
      // Past four weeks it switches to months, not more weeks.
      expect(ago(const Duration(days: 150)), '5mo ago');
      expect(ago(const Duration(days: 800)), '2y ago');
    });

    test('reading time is at least a minute', () {
      expect(NoteMeta.readingMinutes(''), 1);
      expect(NoteMeta.readingMinutes(List.filled(100, 'word').join(' ')), 1);
      expect(NoteMeta.readingMinutes(List.filled(300, 'word').join(' ')), 2);
    });

    /// Students get no badge — only a teacher or an admin is called out.
    test('only staff carry a role badge', () {
      expect(NoteMeta.roleBadge('student'), isNull);
      expect(NoteMeta.roleBadge('teacher'), 'Teacher');
      expect(NoteMeta.roleBadge('admin'), 'Admin');
    });

    test('normalises a typed tag', () {
      expect(NoteMeta.normaliseTag('  #dsa '), 'dsa');
      expect(NoteMeta.normaliseTag('##algo'), 'algo');
      expect(NoteMeta.normaliseTag('   '), isNull);
      expect(NoteMeta.normaliseTag('x' * 31), isNull);
    });

    test('labels the sorts as the web does', () {
      expect(NoteMeta.sortLabel('recent'), 'Newest');
      expect(NoteMeta.sortLabel('most_liked'), 'Most liked');
      expect(NoteMeta.sortLabel('oldest'), 'Oldest');
    });
  });
}
