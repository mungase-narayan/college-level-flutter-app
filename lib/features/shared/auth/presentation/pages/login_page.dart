import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/router/app_router.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/design/extensions/glass_context.dart';
import '../../../../../core/design/theme/glass_specs.dart';
import '../../../../../core/design/widgets/liquid_glass_card.dart';
import '../../../../../core/error/failures.dart';
import '../bloc/auth/auth_bloc.dart';
import '../widgets/role_selector_sheet.dart';

/// Port of `src/pages/auth/login/index.tsx` + `components/login-form.tsx`.
///
/// The web version is a split screen (branding panel + form card); on a phone
/// the branding collapses into a header above the form, keeping the radial-dot
/// backdrop and the violet/indigo blur orbs.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
          AuthLoginRequested(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  /// A multi-role login must pick a role before the router will route them, so
  /// the sheet is not dismissible.
  Future<void> _promptForRole(AuthState state) async {
    final role = await RoleSelectorSheet.show(
      context,
      roles: state.roles,
      selected: state.activeRole,
      dismissible: false,
    );
    if (!mounted || role == null) return;
    context.read<AuthBloc>().add(AuthRoleSelected(role));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Scaffold(
      body: BlocConsumer<AuthBloc, AuthState>(
        listenWhen: (prev, next) =>
            prev.failure != next.failure ||
            prev.needsRoleSelection != next.needsRoleSelection,
        listener: (context, state) {
          final failure = state.failure;
          if (failure != null && !state.isAuthenticated) {
            AppToast.failure(context, failure);
          }
          if (state.needsRoleSelection) _promptForRole(state);
        },
        builder: (context, state) {
          return Stack(
            children: [
              const _LoginBackdrop(),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Branding ──────────────────────────────────────
                          Text('Welcome back', style: theme.textTheme.displaySmall),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to continue to College Level.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // ── Form card ─────────────────────────────────────
                          // One of the few content surfaces that earns a real
                          // BackdropFilter: it sits directly over the backdrop's
                          // colour orbs, so there is genuinely something behind it
                          // worth frosting. Elsewhere `AppCard` renders simulated
                          // glass, which is both cheaper and indistinguishable
                          // over a flat background.
                          _LoginFormCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  AppInput(
                                    controller: _emailController,
                                    label: 'Email',
                                    hint: 'you@school.edu',
                                    prefixIcon: Icons.mail_outline_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    enabled: !state.isSubmitting,
                                    autofillHints: const [AutofillHints.email],
                                    validator: _validateEmail,
                                  ),
                                  const SizedBox(height: 16),
                                  AppPasswordInput(
                                    controller: _passwordController,
                                    label: 'Password',
                                    hint: 'Enter your password',
                                    textInputAction: TextInputAction.done,
                                    enabled: !state.isSubmitting,
                                    autofillHints: const [AutofillHints.password],
                                    onSubmitted: (_) => _submit(),
                                    validator: (value) =>
                                        (value == null || value.isEmpty)
                                            ? 'Password is required'
                                            : null,
                                  ),
                                  // Under the field rather than beside its
                                  // label: AppPasswordInput owns its own label
                                  // on both the material and the glass branch,
                                  // so a trailing label action would mean
                                  // reworking a shared widget for no gain.
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: state.isSubmitting
                                          ? null
                                          : () => context
                                              .push(Routes.forgotPassword),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        minimumSize: const Size(0, 36),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                  if (state.failure != null) ...[
                                    const SizedBox(height: 14),
                                    _LoginError(failure: state.failure!),
                                  ],
                                  const SizedBox(height: 22),
                                  AppButton(
                                    label: 'Sign in',
                                    expand: true,
                                    isLoading: state.isSubmitting,
                                    onPressed: _submit,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),
                          Text(
                            'Accounts are created by your school. If you were invited, '
                            'use the link in your invitation email to set a password.',
                            style: theme.textTheme.labelSmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    // Deliberately permissive — the backend's express-validator is the
    // authority, and a client regex that's stricter than the server only ever
    // blocks valid addresses.
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }
}

/// The 403/423 cases deserve more than a toast, since they're actionable and
/// the user will re-read them.
class _LoginError extends StatelessWidget {
  const _LoginError({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final theme = Theme.of(context);

    final message = switch (failure) {
      AccountLockedFailure f => f.message,
      ForbiddenFailure f => f.message,
      ValidationFailure f => f.detailedMessage,
      _ => failure.message,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.destructive.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.destructive.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 17, color: scheme.destructive),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.destructive),
            ),
          ),
        ],
      ),
    );
  }
}

/// The login form's surface.
///
/// Identical to [AppCard] on Android. On iOS it opts into a real
/// [BackdropFilter] — the per-instance escape hatch [LiquidGlassCard] exposes for
/// the case where a content surface genuinely overlaps something worth blurring.
class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const padding = EdgeInsets.all(20);

    if (context.useGlass) {
      return LiquidGlassCard(
        padding: padding,
        blur: GlassBlur.regular,
        child: child,
      );
    }

    return AppCard(padding: padding, child: child);
  }
}

/// The violet/indigo blur orbs behind the login card.
class _LoginBackdrop extends StatelessWidget {
  const _LoginBackdrop();

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    // On iOS the app-wide `GlassBackdrop` already paints this ambient field from
    // `MaterialApp.builder`, and layering a second pair of orbs on top of it
    // would double their alpha into a muddy bloom.
    if (context.useGlass) return const SizedBox.shrink();

    Widget orb(Color color, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
            ),
          ),
        );

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(top: -110, left: -90, child: orb(scheme.primary, 320)),
          Positioned(bottom: -140, right: -110, child: orb(scheme.chart[3], 360)),
        ],
      ),
    );
  }
}
