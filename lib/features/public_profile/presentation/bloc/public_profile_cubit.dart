import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../domain/entities/public_profile.dart';
import '../../domain/usecases/get_public_profile_usecase.dart';

/// One student's public showcase. Read-only and fetched once per screen.
class PublicProfileCubit extends Cubit<RemoteState<PublicProfile>> {
  PublicProfileCubit({
    required GetPublicProfileUseCase getPublicProfile,
    required this.username,
  })  : _getPublicProfile = getPublicProfile,
        super(const RemoteState());

  final GetPublicProfileUseCase _getPublicProfile;
  final String username;

  Future<void> load({bool refresh = false}) async {
    if (isClosed) return;
    emit(state.copyWith(
      status: RemoteStatus.loading,
      isRefreshing: refresh,
      clearFailure: true,
    ));

    final result = await _getPublicProfile(username);
    if (isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: RemoteStatus.failure,
        failure: failure,
        isRefreshing: false,
      )),
      (profile) => emit(RemoteState(status: RemoteStatus.success, data: profile)),
    );
  }
}
