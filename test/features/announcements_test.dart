import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/config/theme/app_colors.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/core/usecases/usecase.dart';
import 'package:college_level/features/announcements/data/models/announcement_model.dart';
import 'package:college_level/features/announcements/domain/entities/announcement.dart';
import 'package:college_level/features/announcements/domain/usecases/announcement_usecases.dart';
import 'package:college_level/features/announcements/presentation/bloc/announcement_detail_cubit.dart';
import 'package:college_level/features/announcements/presentation/bloc/announcements_cubit.dart';

class _MockList extends Mock implements ListAnnouncementsUseCase {}

class _MockGet extends Mock implements GetAnnouncementUseCase {}

class _MockRegister extends Mock implements RegisterForAnnouncementUseCase {}

class _MockCancel extends Mock
    implements CancelAnnouncementRegistrationUseCase {}

Announcement _item(String id) => Announcement(
      id: id,
      title: 'Tech fest $id',
      type: 'EVENT',
      priority: 'HIGH',
    );

Paginated<Announcement> _page({
  required int page,
  required int totalPages,
  int items = 2,
}) =>
    Paginated<Announcement>(
      items: [for (var i = 0; i < items; i++) _item('$page-$i')],
      pagination: Pagination(
        page: page,
        limit: 12,
        total: totalPages * items,
        totalPages: totalPages,
      ),
    );

AnnouncementDetail _detail({
  String type = 'EVENT',
  bool isRegistered = false,
  String? registrationStatus,
  int registrationCount = 4,
}) =>
    AnnouncementDetail(
      id: 'a1',
      title: 'Tech fest',
      type: type,
      priority: 'HIGH',
      isRegistered: isRegistered,
      registrationStatus: registrationStatus,
      registrationCount: registrationCount,
    );

void main() {
  late _MockList list;
  late AnnouncementsCubit cubit;

  List<AnnouncementQueryParams> capturedParams() =>
      verify(() => list(captureAny()))
          .captured
          .cast<AnnouncementQueryParams>();

  setUpAll(() {
    registerFallbackValue(const AnnouncementQueryParams());
    registerFallbackValue(const IdParams('a1'));
  });

  setUp(() {
    list = _MockList();
    when(() => list(any())).thenAnswer(
      (_) async =>
          Right<Failure, Paginated<Announcement>>(_page(page: 1, totalPages: 1)),
    );
    cubit = AnnouncementsCubit(listAnnouncements: list);
  });

  tearDown(() => cubit.close());

  group('AnnouncementsCubit', () {
    /// The web asks for 24 — a four-column grid figure. The server's own default
    /// is 12, which is what one column wants.
    test('every request asks for twelve', () async {
      await cubit.load();
      await cubit.setType('EVENT');

      expect(capturedParams().map((p) => p.limit), everyElement(12));
    });

    test('a search restarts at the first page', () async {
      when(() => list(any())).thenAnswer((invocation) async {
        final params =
            invocation.positionalArguments.first as AnnouncementQueryParams;
        return Right<Failure, Paginated<Announcement>>(
          _page(page: params.page, totalPages: 3),
        );
      });

      await cubit.load();
      await cubit.loadMore();
      await cubit.setSearch('fest');

      final last = capturedParams().last;
      expect(last.page, 1);
      expect(last.query, 'fest');
    });

    test('a type change keeps the search term', () async {
      await cubit.setSearch('fest');
      await cubit.setType('EVENT');

      final last = capturedParams().last;
      expect(last.query, 'fest');
      expect(last.type, 'EVENT');
      expect(last.page, 1);
    });

    /// Pins `clearType`. Without it `copyWith`'s `??` swallows the null and the
    /// filter can be set but never cleared.
    test('clearing the type actually clears it', () async {
      await cubit.setType('EVENT');
      await cubit.setType(null);

      expect(capturedParams().last.type, isNull);
      expect(cubit.query.hasFilters, isFalse);
    });

    test('clearFilters drops both in a single request', () async {
      await cubit.setSearch('fest');
      await cubit.setType('EVENT');
      await cubit.clearFilters();

      final params = capturedParams();
      expect(params, hasLength(3));
      expect(params.last.query, isNull);
      expect(params.last.type, isNull);
    });

    /// The field fires on every debounced keystroke; a term that trims to the
    /// same value must not spend a request.
    test('an unchanged search term does not refire', () async {
      await cubit.setSearch('fest');
      await cubit.setSearch('  fest  ');

      verify(() => list(any())).called(1);
    });

    test('an empty search clears the query rather than sending a blank',
        () async {
      await cubit.setSearch('fest');
      await cubit.setSearch('');

      expect(capturedParams().last.query, isNull);
    });

    test('loadMore appends the next page', () async {
      when(() => list(any())).thenAnswer((invocation) async {
        final params =
            invocation.positionalArguments.first as AnnouncementQueryParams;
        return Right<Failure, Paginated<Announcement>>(
          _page(page: params.page, totalPages: 2),
        );
      });

      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.data!.items, hasLength(4));
      expect(capturedParams().map((p) => p.page), [1, 2]);
    });

    test('loadMore stops at the last page', () async {
      await cubit.load();
      await cubit.loadMore();

      verify(() => list(any())).called(1);
    });

    test('a second loadMore while one is in flight is ignored', () async {
      final gate = Completer<Either<Failure, Paginated<Announcement>>>();
      when(() => list(any())).thenAnswer((invocation) {
        final params =
            invocation.positionalArguments.first as AnnouncementQueryParams;
        if (params.page == 1) {
          return Future.value(
            Right<Failure, Paginated<Announcement>>(
              _page(page: 1, totalPages: 3),
            ),
          );
        }
        return gate.future;
      });

      await cubit.load();
      final first = cubit.loadMore();
      await cubit.loadMore();
      gate.complete(
        Right<Failure, Paginated<Announcement>>(_page(page: 2, totalPages: 3)),
      );
      await first;

      verify(() => list(any())).called(2);
    });

    test('a failed loadMore keeps what is already listed', () async {
      var call = 0;
      when(() => list(any())).thenAnswer((_) async {
        call++;
        if (call == 1) {
          return Right<Failure, Paginated<Announcement>>(
            _page(page: 1, totalPages: 3),
          );
        }
        return const Left<Failure, Paginated<Announcement>>(
          NetworkFailure('offline'),
        );
      });

      await cubit.load();
      await cubit.loadMore();

      expect(cubit.state.data!.items, hasLength(2));
      expect(cubit.state.failure, isNotNull);
    });
  });

  group('AnnouncementDetailCubit', () {
    late _MockGet get;
    late _MockRegister register;
    late _MockCancel cancel;

    AnnouncementDetailCubit build(AnnouncementDetail seed) {
      when(() => get(any()))
          .thenAnswer((_) async => Right<Failure, AnnouncementDetail>(seed));
      return AnnouncementDetailCubit(
        announcementId: 'a1',
        getAnnouncement: get,
        registerFor: register,
        cancelRegistrationFor: cancel,
      );
    }

    setUp(() {
      get = _MockGet();
      register = _MockRegister();
      cancel = _MockCancel();
      when(() => register(any())).thenAnswer(
        (_) async => const Right<Failure, AnnouncementRegistration>(
          AnnouncementRegistration(id: 'r1', status: 'REGISTERED'),
        ),
      );
      when(() => cancel(any())).thenAnswer(
        (_) async => const Right<Failure, AnnouncementRegistration>(
          AnnouncementRegistration(id: 'r1', status: 'CANCELLED'),
        ),
      );
    });

    test('register flips the flag and adds one to the count', () async {
      final detail = build(_detail(registrationCount: 4));
      addTearDown(detail.close);
      await detail.load();

      expect(await detail.register(), isNull);
      expect(detail.state.data!.isRegistered, isTrue);
      expect(detail.state.data!.registrationCount, 5);
    });

    /// Registering is idempotent server-side, so a repeat must not count the
    /// same student twice.
    test('registering again does not double-count', () async {
      final detail = build(
        _detail(isRegistered: true, registrationStatus: 'REGISTERED'),
      );
      addTearDown(detail.close);
      await detail.load();

      await detail.register();

      expect(detail.state.data!.registrationCount, 4);
    });

    test('cancelling clears the flag and removes one', () async {
      final detail = build(
        _detail(isRegistered: true, registrationStatus: 'REGISTERED'),
      );
      addTearDown(detail.close);
      await detail.load();

      expect(await detail.cancelRegistration(), isNull);
      expect(detail.state.data!.isRegistered, isFalse);
      expect(detail.state.data!.registrationStatus, 'CANCELLED');
      expect(detail.state.data!.registrationCount, 3);
    });

    /// The server counts `REGISTERED` rows only, so an attended row was never
    /// in the total.
    test('an attended registration offers no buttons and cannot decrement',
        () async {
      final attended =
          _detail(isRegistered: true, registrationStatus: 'ATTENDED');

      expect(attended.canCancel, isFalse);
      expect(attended.canRegister, isFalse);

      final detail = build(attended);
      addTearDown(detail.close);
      await detail.load();

      await detail.cancelRegistration();
      expect(detail.state.data!.registrationCount, 4);
    });

    test('a failed register leaves the announcement untouched', () async {
      when(() => register(any())).thenAnswer(
        (_) async => const Left<Failure, AnnouncementRegistration>(
          ServerFailure('Event is full', statusCode: 400),
        ),
      );

      final detail = build(_detail());
      addTearDown(detail.close);
      await detail.load();

      final failure = await detail.register();

      expect(failure, isA<ServerFailure>());
      expect(detail.state.data!.isRegistered, isFalse);
      expect(detail.state.data!.registrationCount, 4);
    });

    test('a non-event can never register', () {
      final general = _detail(type: 'GENERAL');

      expect(general.canRegister, isFalse);
      expect(general.canCancel, isFalse);
    });
  });

  group('AnnouncementModel', () {
    test('parses the double-nested feed page', () {
      final page = Paginated<AnnouncementModel>.fromJson(
        const {
          'data': [
            {'id': 'a1', 'title': 'Fest', 'type': 'EVENT', 'priority': 'HIGH'},
          ],
          'pagination': {
            'page': 1,
            'limit': 12,
            'total': 3,
            'totalPages': 1,
          },
        },
        AnnouncementModel.fromJson,
      );

      expect(page.items.single.title, 'Fest');
      expect(page.pagination.totalPages, 1);
    });

    test('absent decorations fall back rather than throwing', () {
      final item = AnnouncementModel.fromJson(const {'id': 'a1'});

      expect(item.attachmentFiles, isEmpty);
      expect(item.registrationCount, 0);
      expect(item.isRegistered, isFalse);
      expect(item.type, 'GENERAL');
      expect(item.priority, 'MEDIUM');
    });

    /// `fees` is a Postgres numeric and can arrive as a string.
    test('parses a numeric fee sent as a string', () {
      final item = AnnouncementModel.fromJson(const {
        'id': 'a1',
        'fees': '500.00',
        'isFree': false,
      });

      expect(item.fees, 500);
      expect(item.feeLabel, '₹500');
    });

    test('drops an attachment whose url did not resolve', () {
      final item = AnnouncementModel.fromJson(const {
        'id': 'a1',
        'attachmentFiles': [
          {'id': 'f1', 'url': 'https://x/1.pdf', 'name': 'Rules.pdf'},
          {'id': 'f2', 'name': 'Broken.pdf'},
        ],
      });

      expect(item.attachmentFiles, hasLength(1));
      expect(item.attachmentFiles.single.name, 'Rules.pdf');
    });

    test('detail parses a null room and a full author', () {
      final detail = AnnouncementDetailModel.fromJson(const {
        'id': 'a1',
        'title': 'Fest',
        'room': null,
        'author': {'id': 'u1', 'fullName': 'Ada Lovelace', 'avatar': null},
      });

      expect(detail.room, isNull);
      expect(detail.venue, 'To be announced');
      expect(detail.author!.fullName, 'Ada Lovelace');
    });

    test('a blank author name falls back rather than reading "Posted by  ·"',
        () {
      final detail = AnnouncementDetailModel.fromJson(const {
        'id': 'a1',
        'author': {'id': 'u1', 'fullName': ''},
      });

      expect(detail.author!.fullName, 'Unknown');
    });
  });

  group('derivations', () {
    test('dateRange joins both ends with an em dash', () {
      const both = Announcement(
        id: 'a',
        title: 't',
        type: 'EVENT',
        priority: 'LOW',
        startDate: '2026-08-02T10:00:00.000Z',
        endDate: '2026-08-02T16:00:00.000Z',
      );

      expect(both.dateRange, contains('—'));
      expect(both.dateRange.split('—'), hasLength(2));
    });

    test('dateRange with no end is the start alone', () {
      const start = Announcement(
        id: 'a',
        title: 't',
        type: 'EVENT',
        priority: 'LOW',
        startDate: '2026-08-02T10:00:00.000Z',
      );

      expect(start.dateRange, isNot(contains('—')));
    });

    test('dateRange with no dates is announced later', () {
      const none =
          Announcement(id: 'a', title: 't', type: 'EVENT', priority: 'LOW');

      expect(none.dateRange, 'To be announced');
    });

    test('venue names the room, its code and its building', () {
      const detail = AnnouncementDetail(
        id: 'a',
        title: 't',
        type: 'EVENT',
        priority: 'LOW',
        room: AnnouncementRoom(
          id: 'r1',
          code: 'L-204',
          name: 'Lab 2',
          building: 'Science Block',
        ),
      );

      expect(detail.venue, 'Lab 2 (L-204) · Science Block');
    });

    test('venue falls back to the code alone', () {
      const detail = AnnouncementDetail(
        id: 'a',
        title: 't',
        type: 'EVENT',
        priority: 'LOW',
        room: AnnouncementRoom(id: 'r1', code: 'L-204'),
      );

      expect(detail.venue, 'L-204');
    });

    /// The web tests `!a.fees`, which is falsy at zero — a plain null check here
    /// would print `₹0`.
    test('a zero fee reads as free', () {
      const free = Announcement(
        id: 'a',
        title: 't',
        type: 'EVENT',
        priority: 'LOW',
        fees: 0,
      );

      expect(free.feeLabel, 'Free entry');
    });

    test('isFree wins over a set fee', () {
      const free = Announcement(
        id: 'a',
        title: 't',
        type: 'EVENT',
        priority: 'LOW',
        fees: 500,
        isFree: true,
      );

      expect(free.feeLabel, 'Free entry');
    });

    test('registered label pluralises', () {
      Announcement withCount(int n) => Announcement(
            id: 'a',
            title: 't',
            type: 'EVENT',
            priority: 'LOW',
            registrationCount: n,
          );

      expect(withCount(0).registeredLabel, '0 students');
      expect(withCount(1).registeredLabel, '1 student');
      expect(withCount(2).registeredLabel, '2 students');
    });
  });

  group('AnnouncementMeta', () {
    test('carries all fifteen types in the web order', () {
      expect(AnnouncementMeta.types, hasLength(15));
      expect(AnnouncementMeta.types.first, 'GENERAL');
      expect(AnnouncementMeta.types.last, 'OTHER');
      expect(AnnouncementMeta.types, contains('SCHOLARSHIP'));
    });

    test('every type has a label and a shade', () {
      for (final type in AnnouncementMeta.types) {
        expect(AnnouncementMeta.typeLabel(type), isNot(type));
        expect(AnnouncementMeta.typeShade(type), isA<TwShade>());
      }
    });

    /// The server's enum has grown before; an unknown value must render rather
    /// than throw during parse.
    test('an unknown type degrades instead of throwing', () {
      expect(AnnouncementMeta.typeLabel('PODCAST'), 'PODCAST');
      expect(AnnouncementMeta.typeShade('PODCAST'), TwColors.slate);
    });

    test('priority shades run slate, amber, red', () {
      expect(AnnouncementMeta.priorityShade('LOW'), TwColors.slate);
      expect(AnnouncementMeta.priorityShade('MEDIUM'), TwColors.amber);
      expect(AnnouncementMeta.priorityShade('HIGH'), TwColors.red);
    });
  });
}
