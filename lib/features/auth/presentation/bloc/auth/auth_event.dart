part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const [];
}

/// Fired once at boot to hydrate the session from storage. Until it resolves,
/// the router holds every route on the splash screen.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// `POST /users/login`.
class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// The user picked a role — from the login role selector (multi-role accounts)
/// or from the settings screen's role switcher.
class AuthRoleSelected extends AuthEvent {
  const AuthRoleSelected(this.role);

  final UserRole role;

  @override
  List<Object?> get props => [role];
}

/// The user tapped Log out.
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// The API rejected a request with 401.
///
/// There is no refresh endpoint, so this is terminal — the port of the React
/// `performLogout()` that the axios response interceptor calls.
class AuthUnauthorized extends AuthEvent {
  const AuthUnauthorized();
}

/// The profile changed (`PATCH /users/me` succeeded elsewhere in the app).
class AuthUserUpdated extends AuthEvent {
  const AuthUserUpdated(this.user);

  final User user;

  @override
  List<Object?> get props => [user];
}
