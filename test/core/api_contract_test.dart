import 'package:college_level/core/error/exceptions.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/core/network/api_response.dart';
import 'package:college_level/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks in the parts of the backend contract the whole data layer rests on.
void main() {
  group('ApiResponse', () {
    test('reads the statusCode key, not status', () {
      final response = ApiResponse<int>.fromJson(
        {'statusCode': 201, 'data': 7, 'message': 'Created', 'success': true},
        (data) => (data as num).toInt(),
      );

      expect(response.statusCode, 201);
      expect(response.data, 7);
      expect(response.message, 'Created');
      expect(response.success, isTrue);
    });

    test('derives success from statusCode when the key is absent', () {
      final response = ApiResponse<Object?>.fromJson(
        {'statusCode': 404, 'data': null, 'message': 'Not found'},
        (data) => data,
      );

      expect(response.success, isFalse);
    });
  });

  group('Paginated', () {
    test('parses the { data, pagination } envelope', () {
      final page = Paginated<String>.fromJson(
        {
          'data': [
            {'name': 'a'},
            {'name': 'b'},
          ],
          'pagination': {'page': 1, 'limit': 20, 'total': 42, 'totalPages': 3},
        },
        (json) => json['name'] as String,
      );

      expect(page.items, ['a', 'b']);
      expect(page.pagination.total, 42);
      expect(page.pagination.hasNextPage, isTrue);
    });

    test('tolerates a bare array with no pagination envelope', () {
      final page = Paginated<String>.fromJson(
        [
          {'name': 'only'},
        ],
        (json) => json['name'] as String,
      );

      expect(page.items, ['only']);
      expect(page.pagination.hasNextPage, isFalse);
    });

    test('appends the next page onto the accumulated list', () {
      const first = Paginated<String>(
        items: ['a'],
        pagination: Pagination(page: 1, limit: 1, total: 2, totalPages: 2),
      );
      const second = Paginated<String>(
        items: ['b'],
        pagination: Pagination(page: 2, limit: 1, total: 2, totalPages: 2),
      );

      final merged = first.copyWithAppended(second);
      expect(merged.items, ['a', 'b']);
      expect(merged.pagination.page, 2);
      expect(merged.pagination.hasNextPage, isFalse);
    });
  });

  group('Failure mapping', () {
    test('preserves the field errors of a 422', () {
      final failure = mapExceptionToFailure(
        const ValidationException(
          'Received data is not valid',
          fieldErrors: [FieldError(field: 'email', message: 'must be an email')],
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(
        (failure as ValidationFailure).detailedMessage,
        'Received data is not valid\n• email: must be an email',
      );
    });

    test('renders the catch-all `error` key without a field prefix', () {
      const error = FieldError(field: 'error', message: 'something broke');
      expect(error.display, '• something broke');
    });

    test('maps 401 / 403 / 423 onto their own failures', () {
      expect(
        mapExceptionToFailure(const UnauthorizedException('expired')),
        isA<UnauthorizedFailure>(),
      );
      expect(
        mapExceptionToFailure(const ForbiddenException('not allowed')),
        isA<ForbiddenFailure>(),
      );
      expect(
        mapExceptionToFailure(const AccountLockedException('locked')),
        isA<AccountLockedFailure>(),
      );
    });

    test('falls back to a server failure for an unrecognised error', () {
      expect(mapExceptionToFailure(Exception('boom')), isA<ServerFailure>());
    });
  });

  group('Fmt', () {
    test('formats an ISO date day-first without a timezone shift', () {
      // String-sliced like the React helper, so a `date` column never moves.
      expect(Fmt.dmy('2026-07-09'), '09/07/2026');
      expect(Fmt.dmy('2026-07-09T18:30:00.000Z'), '09/07/2026');
      expect(Fmt.dmy(null), '—');
    });

    test('formats durations the way the React helper does', () {
      expect(Fmt.duration(0), '0s');
      expect(Fmt.duration(45), '45s');
      expect(Fmt.duration(90), '1m 30s');
      expect(Fmt.duration(3720), '1h 2m');
      expect(Fmt.duration(null), '0s');
    });

    test('builds countdown clocks and clamps negatives', () {
      expect(Fmt.countdown(const Duration(seconds: 65)), '01:05');
      expect(
        Fmt.countdown(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03',
      );
      expect(Fmt.countdown(const Duration(seconds: -5)), '00:00');
    });

    test('derives avatar initials', () {
      expect(Fmt.initials('Ada Lovelace'), 'AL');
      expect(Fmt.initials('Prince'), 'P');
      expect(Fmt.initials(null), '?');
    });
  });
}
