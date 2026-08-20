import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:college_level/core/common/bloc/remote_cubit.dart';
import 'package:college_level/core/constants/api_urls.dart';
import 'package:college_level/core/error/failures.dart';
import 'package:college_level/features/student/public_profile/data/models/public_profile_model.dart';
import 'package:college_level/features/student/public_profile/domain/entities/public_profile.dart';
import 'package:college_level/features/student/public_profile/domain/usecases/get_public_profile_usecase.dart';
import 'package:college_level/features/student/public_profile/presentation/bloc/public_profile_cubit.dart';

class _MockGetPublicProfile extends Mock implements GetPublicProfileUseCase {}

void main() {
  group('PublicProfileModel', () {
    test('a full payload parses', () {
      final profile = PublicProfileModel.fromJson(const {
        'username': 'asha.rao.s24@gis2025.seed',
        'fullName': 'Asha Rao',
        'avatar': 'https://example.com/a.png',
        'schoolName': 'Green Valley',
        'stats': {
          'solved': 88,
          'currentStreak': 12,
          'points': 340,
          'rank': 4,
          'totalStudents': 120,
        },
        'heatmap': {
          'today': '2026-08-18',
          'days': [
            {'date': '2026-08-17', 'count': 3},
            {'date': '2026-08-18', 'count': 1},
          ],
        },
        'badges': [
          {
            'badgeKey': 'streak_7',
            'name': 'Week Warrior',
            'tier': 'silver',
            'category': 'streak',
            'period': '2026-08',
            'earnedAt': '2026-08-01T00:00:00.000Z',
          },
        ],
        'recentSolved': [
          {
            'questionId': 'q1',
            'title': 'Two Sum',
            'difficulty': 'easy',
            'solvedAt': '2026-08-18T10:00:00.000Z',
          },
        ],
      });

      expect(profile.displayName, 'Asha Rao');
      expect(profile.schoolName, 'Green Valley');
      expect(profile.stats.solved, 88);
      expect(profile.stats.currentStreak, 12);
      expect(profile.stats.rank, 4);
      expect(profile.stats.totalStudents, 120);
      expect(profile.heatmapDays, hasLength(2));
      expect(profile.heatmapToday, DateTime.parse('2026-08-18'));
      expect(profile.badges.single.name, 'Week Warrior');
      expect(profile.badges.single.tier, 'silver');
      expect(profile.recentSolved.single.title, 'Two Sum');
    });

    /// Default usernames are full email addresses, so the handle has to stop at
    /// the domain or the header reads "@asha@gis2025.seed".
    test('the handle drops the email domain', () {
      final profile = PublicProfileModel.fromJson(const {
        'username': 'asha.rao.s24@gis2025.seed',
      });

      expect(profile.handle, 'asha.rao.s24');
    });

    test('a username with no domain is its own handle', () {
      final profile = PublicProfileModel.fromJson(const {'username': 'asha'});

      expect(profile.handle, 'asha');
    });

    test('a missing full name falls back to the username', () {
      final profile = PublicProfileModel.fromJson(const {'username': 'asha'});

      expect(profile.displayName, 'asha');
    });

    /// An unranked student must not render as "#0".
    test('a null rank stays null', () {
      final profile = PublicProfileModel.fromJson(const {
        'username': 'asha',
        'stats': {'solved': 0, 'rank': null},
      });

      expect(profile.stats.rank, isNull);
      expect(profile.stats.solved, 0);
    });

    test('an empty payload is survivable', () {
      final profile = PublicProfileModel.fromJson(const {});

      expect(profile.username, '');
      expect(profile.stats.points, 0);
      expect(profile.badges, isEmpty);
      expect(profile.recentSolved, isEmpty);
      expect(profile.heatmapDays, isEmpty);
      expect(profile.heatmapToday, isNull);
    });

    test('an unparseable earnedAt becomes null rather than throwing', () {
      final profile = PublicProfileModel.fromJson(const {
        'badges': [
          {'badgeKey': 'k', 'name': 'n', 'earnedAt': 'not-a-date'},
        ],
      });

      expect(profile.badges.single.earnedAt, isNull);
    });
  });

  group('PublicProfileCubit', () {
    late _MockGetPublicProfile getPublicProfile;

    setUp(() => getPublicProfile = _MockGetPublicProfile());

    test('a success carries the profile', () async {
      when(() => getPublicProfile(any())).thenAnswer(
        (_) async => Right<Failure, PublicProfile>(
          PublicProfileModel.fromJson(const {'username': 'asha'}),
        ),
      );

      final cubit = PublicProfileCubit(
        getPublicProfile: getPublicProfile,
        username: 'asha',
      );
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.success);
      expect(cubit.state.data?.username, 'asha');
      verify(() => getPublicProfile('asha')).called(1);
    });

    test('a failure is surfaced', () async {
      when(() => getPublicProfile(any())).thenAnswer(
        (_) async => const Left<Failure, PublicProfile>(NetworkFailure('offline')),
      );

      final cubit = PublicProfileCubit(
        getPublicProfile: getPublicProfile,
        username: 'asha',
      );
      await cubit.load();

      expect(cubit.state.status, RemoteStatus.failure);
      expect(cubit.state.data, isNull);
    });
  });

  test('the public profile endpoint matches the backend router', () {
    expect(
      ApiUrls.publicStudentProfile('asha'),
      '/public/students/asha',
    );
  });
}
