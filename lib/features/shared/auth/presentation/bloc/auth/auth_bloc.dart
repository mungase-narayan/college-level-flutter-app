import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../core/constants/user_constants.dart';
import '../../../../../../core/error/failures.dart';
import '../../../../../../core/network/session_manager.dart';
import '../../../../../../core/usecases/usecase.dart';
import '../../../domain/entities/auth_session.dart';
import '../../../domain/entities/school.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/usecases/auth_usecases.dart';
import '../../../domain/usecases/login_usecase.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Owns the session for the whole app — the port of the React `authSlice` plus
/// the `useLogin` / `useLogout` hooks.
///
/// The router listens to this bloc, so every emit here is what drives
/// redirects.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginUseCase login,
    required LogoutUseCase logout,
    required GetCachedSessionUseCase getCachedSession,
    required SetActiveRoleUseCase setActiveRole,
    required AuthRepository repository,
    required SessionManager sessionManager,
  })  : _login = login,
        _logout = logout,
        _getCachedSession = getCachedSession,
        _setActiveRole = setActiveRole,
        _repository = repository,
        super(const AuthState()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRoleSelected>(_onRoleSelected);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthUnauthorized>(_onUnauthorized);
    on<AuthUserUpdated>(_onUserUpdated);

    // The Dio interceptor can't reach the bloc directly, so it signals through
    // the session manager and we adapt that into an event.
    _unauthorizedSubscription =
        sessionManager.onUnauthorized.listen((_) => add(const AuthUnauthorized()));
  }

  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final GetCachedSessionUseCase _getCachedSession;
  final SetActiveRoleUseCase _setActiveRole;
  final AuthRepository _repository;

  late final StreamSubscription<void> _unauthorizedSubscription;

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _getCachedSession(const NoParams());
    result.fold(
      // A storage read that fails is treated as "no session" rather than an
      // error the user has to dismiss.
      (_) => emit(state.copyWith(status: AuthStatus.unauthenticated)),
      (session) => emit(
        session == null
            ? state.copyWith(status: AuthStatus.unauthenticated)
            : state.copyWith(status: AuthStatus.authenticated, session: session),
      ),
    );
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearFailure: true));

    final result = await _login(
      LoginParams(email: event.email, password: event.password),
    );

    result.fold(
      (failure) => emit(state.copyWith(isSubmitting: false, failure: failure)),
      (session) => emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          isSubmitting: false,
          clearFailure: true,
          // Single-role users go straight to their home; multi-role users get
          // the picker first, exactly as `login-form.tsx` does.
          needsRoleSelection: session.isMultiRole,
        ),
      ),
    );
  }

  Future<void> _onRoleSelected(
    AuthRoleSelected event,
    Emitter<AuthState> emit,
  ) async {
    final session = state.session;
    if (session == null || !session.hasRole(event.role)) return;

    await _setActiveRole(event.role);
    emit(
      state.copyWith(
        session: session.copyWith(activeRole: event.role),
        needsRoleSelection: false,
      ),
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    await _logout(const NoParams());
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onUnauthorized(
    AuthUnauthorized event,
    Emitter<AuthState> emit,
  ) async {
    // Already signed out — a burst of in-flight 401s shouldn't each re-emit.
    if (state.status == AuthStatus.unauthenticated) return;

    await _repository.clearSession();
    emit(
      const AuthState(
        status: AuthStatus.unauthenticated,
        failure: UnauthorizedFailure(),
      ),
    );
  }

  void _onUserUpdated(AuthUserUpdated event, Emitter<AuthState> emit) {
    final session = state.session;
    if (session == null) return;
    emit(state.copyWith(session: session.copyWith(user: event.user)));
  }

  @override
  Future<void> close() {
    _unauthorizedSubscription.cancel();
    return super.close();
  }
}
