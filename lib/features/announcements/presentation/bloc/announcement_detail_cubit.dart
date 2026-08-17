import 'dart:math' as math;

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/usecases/announcement_usecases.dart';

/// One announcement, plus the two registration mutations an event allows.
///
/// The mutations return the [Failure] rather than emitting a failure state on
/// their own, so the page can toast the server's message while leaving the
/// announcement on screen — a failed registration must not blank the article
/// the student was reading.
class AnnouncementDetailCubit extends RemoteCubit<AnnouncementDetail> {
  AnnouncementDetailCubit({
    required String announcementId,
    required GetAnnouncementUseCase getAnnouncement,
    required RegisterForAnnouncementUseCase registerFor,
    required CancelAnnouncementRegistrationUseCase cancelRegistrationFor,
  })  : _id = announcementId,
        _registerFor = registerFor,
        _cancelRegistrationFor = cancelRegistrationFor,
        super(() => getAnnouncement(IdParams(announcementId)));

  final String _id;
  final RegisterForAnnouncementUseCase _registerFor;
  final CancelAnnouncementRegistrationUseCase _cancelRegistrationFor;

  /// Returns null on success, or the failure to toast.
  Future<Failure?> register() async {
    final current = state.data;
    if (current == null || isClosed) return null;

    final result = await _registerFor(IdParams(_id));
    if (isClosed) return null;

    return result.fold(
      (failure) => failure,
      (registration) {
        setData(
          current.copyWithRegistration(
            isRegistered: true,
            // Registering is idempotent server-side, so a repeat must not
            // count the student twice.
            registrationCount: current.registrationCount +
                (current.isRegistered ? 0 : 1),
            registrationStatus: registration.status,
          ),
        );
        return null;
      },
    );
  }

  Future<Failure?> cancelRegistration() async {
    final current = state.data;
    if (current == null || isClosed) return null;

    final result = await _cancelRegistrationFor(IdParams(_id));
    if (isClosed) return null;

    return result.fold(
      (failure) => failure,
      (registration) {
        setData(
          current.copyWithRegistration(
            isRegistered: false,
            // The server counts `REGISTERED` rows only, so an attended row was
            // never in the total to begin with.
            registrationCount: math.max(
              0,
              current.registrationCount -
                  (current.registrationStatus == 'REGISTERED' ? 1 : 0),
            ),
            registrationStatus: registration.status,
          ),
        );
        return null;
      },
    );
  }
}
