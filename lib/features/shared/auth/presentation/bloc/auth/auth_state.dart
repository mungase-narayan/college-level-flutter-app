part of 'auth_bloc.dart';

enum AuthStatus {
  /// Storage hasn't been read yet — the router holds on the splash screen.
  unknown,

  /// No session; only the public routes are reachable.
  unauthenticated,

  /// A session exists.
  authenticated,
}

/// The port of the React `authSlice` state
/// (`{ user, school, roles, tokens, isAuth, activeRole }`), plus the request
/// bookkeeping react-query used to own.
class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.isSubmitting = false,
    this.failure,
    this.needsRoleSelection = false,
  });

  final AuthStatus status;
  final AuthSession? session;

  /// A login or logout is in flight.
  final bool isSubmitting;

  /// The last login failure, cleared on the next attempt.
  final Failure? failure;

  /// A multi-role user just logged in and hasn't picked a role yet — the cue to
  /// show `RoleSelectorSheet`, mirroring `login-form.tsx`.
  final bool needsRoleSelection;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  User? get user => session?.user;
  School? get school => session?.school;
  List<LoginRole> get roles => session?.roles ?? const [];
  UserRole? get activeRole => session?.activeRole;

  /// Where this user should land. Falls back to the public root when signed out.
  String get homePath => session?.homePath ?? '/';

  /// Role checks read the **roles array**, not [activeRole] — matching the
  /// React layout guards, which let a multi-role user reach any of their areas
  /// by URL regardless of which role is currently active.
  bool hasRole(UserRole role) => session?.hasRole(role) ?? false;

  /// True for `teacher`, `class_teacher` **or** `hod` — the three roles the
  /// React app treats identically and routes into the same `/teacher` area.
  bool get hasTeacherRole => session?.hasTeacherRole ?? false;

  AuthState copyWith({
    AuthStatus? status,
    AuthSession? session,
    bool? isSubmitting,
    bool? needsRoleSelection,
    Failure? failure,
    bool clearFailure = false,
    bool clearSession = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        session: clearSession ? null : (session ?? this.session),
        isSubmitting: isSubmitting ?? this.isSubmitting,
        needsRoleSelection: needsRoleSelection ?? this.needsRoleSelection,
        failure: clearFailure ? null : (failure ?? this.failure),
      );

  @override
  List<Object?> get props => [
        status,
        session,
        isSubmitting,
        failure,
        needsRoleSelection,
      ];
}
