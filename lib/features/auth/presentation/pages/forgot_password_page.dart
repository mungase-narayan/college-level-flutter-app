import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/router/app_router.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/error/failures.dart';
import '../../domain/usecases/password_reset_usecases.dart';

/// Step one of password recovery: ask for the account's email.
///
/// There is no web counterpart to port — the React login screen's "Forgot
/// password?" is a button with no handler — so this follows the invitation
/// flow's shape instead, which is the app's pattern for a public screen that
/// does not touch the session.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.requestPasswordReset});

  final RequestPasswordResetUseCase requestPasswordReset;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSubmitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final email = _emailController.text.trim();
    final result = await widget.requestPasswordReset(
      RequestPasswordResetParams(email: email),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) {
        setState(() => _failure = failure);
        AppToast.failure(context, failure);
      },
      (_) {
        // Carefully hedged: the server answers the same way for an address it
        // has never seen, and stays silent for inactive and unverified
        // accounts, so promising a delivered email would be a lie for them.
        AppToast.success(
          context,
          "If an account exists for that email, we've sent a code.",
        );
        context.go(Routes.resetPasswordFor(email));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Scaffold(
      appBar: const AdaptiveAppBar(title: 'Forgot password'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Enter the email on your account and we'll send you a "
                      '6-digit code to reset your password.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 22),
                    AppInput(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'you@school.edu',
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      enabled: !_isSubmitting,
                      autofillHints: const [AutofillHints.email],
                      onSubmitted: (_) => _submit(),
                      validator: _validateEmail,
                    ),
                    if (_failure case final failure?) ...[
                      const SizedBox(height: 14),
                      _ErrorText(failure: failure),
                    ],
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Send code',
                      expand: true,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => context.go(Routes.login),
                      child: const Text('Back to sign in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Same rule and wording as the login screen's.
  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required';
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }
}

/// The server's own sentence, rendered inline as well as toasted so it survives
/// the toast dismissing itself.
class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Text(
      failure is ValidationFailure
          ? (failure as ValidationFailure).detailedMessage
          : failure.message,
      style: theme.textTheme.bodySmall?.copyWith(color: scheme.destructive),
    );
  }
}
