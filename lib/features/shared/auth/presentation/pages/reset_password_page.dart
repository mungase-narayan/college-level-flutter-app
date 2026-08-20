import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/router/app_router.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/error/failures.dart';
import '../../domain/usecases/password_reset_usecases.dart';

/// Step two: the emailed code plus the new password.
///
/// The server tells this screen almost nothing — an unknown account, a code
/// that expired, a code burned by five wrong guesses and a plain mismatch all
/// come back as one 400 carrying the same sentence. So there is nothing to
/// branch on: show what the server said and offer a fresh code.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.resetPassword,
    required this.requestPasswordReset,
    this.email,
  });

  final ResetPasswordUseCase resetPassword;

  /// Powers "Resend code" — the same call the previous screen made.
  final RequestPasswordResetUseCase requestPasswordReset;

  final String? email;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  /// Long enough to stop double-taps and rapid retries. It is a courtesy, not a
  /// mirror of a server rule — the backend throttles nothing.
  static const _resendCooldown = Duration(seconds: 60);

  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final TextEditingController _emailController =
      TextEditingController(text: widget.email ?? '');

  Timer? _resendTimer;
  int _secondsLeft = 0;
  bool _isSubmitting = false;
  bool _isResending = false;
  Failure? _failure;

  /// The address came through the route, so it is shown as context rather than
  /// as another field to fill in.
  bool get _hasEmailFromRoute => (widget.email ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Arriving here means a code was just sent, so start the clock immediately
    // rather than inviting an instant resend that would only burn it.
    if (_hasEmailFromRoute) _startCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _secondsLeft = _resendCooldown.inSeconds);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) timer.cancel();
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final result = await widget.resetPassword(
      ResetPasswordParams(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
        password: _passwordController.text,
      ),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) {
        setState(() => _failure = failure);
        AppToast.failure(context, failure);
      },
      (_) {
        AppToast.success(context, 'Password reset. You can now sign in.');
        context.go(Routes.login);
      },
    );
  }

  Future<void> _resend() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || _isResending || _secondsLeft > 0) return;

    setState(() {
      _isResending = true;
      _failure = null;
    });

    final result = await widget.requestPasswordReset(
      RequestPasswordResetParams(email: email),
    );

    if (!mounted) return;
    setState(() => _isResending = false);

    result.fold(
      (failure) => AppToast.failure(context, failure),
      (_) {
        // The server burns the previous code when it issues one, so whatever is
        // already typed in the field is now dead. Clearing it is kinder than
        // letting them submit a code that cannot work.
        _otpController.clear();
        _startCooldown();
        AppToast.success(context, 'A new code is on its way.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Scaffold(
      appBar: const AdaptiveAppBar(title: 'Reset password'),
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
                    if (_hasEmailFromRoute)
                      _SentToNotice(email: widget.email!)
                    else ...[
                      // Landed here directly, so the address has to be asked
                      // for — the same way the invitation screen falls back to
                      // a paste-the-token field.
                      AppInput(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'you@school.edu',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        enabled: !_isSubmitting,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) return 'Email is required';
                          if (!email.contains('@') || !email.contains('.')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 18),
                    AppInput(
                      controller: _otpController,
                      label: 'Verification code',
                      hint: '6-digit code',
                      prefixIcon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      enabled: !_isSubmitting,
                      // Lets iOS offer the code straight from the notification.
                      autofillHints: const [AutofillHints.oneTimeCode],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: _validateOtp,
                    ),
                    const SizedBox(height: 10),
                    _ResendRow(
                      secondsLeft: _secondsLeft,
                      isResending: _isResending,
                      onResend: _resend,
                    ),
                    const SizedBox(height: 18),
                    AppPasswordInput(
                      controller: _passwordController,
                      label: 'New password',
                      hint: 'At least 8 characters',
                      textInputAction: TextInputAction.next,
                      enabled: !_isSubmitting,
                      autofillHints: const [AutofillHints.newPassword],
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 18),
                    AppPasswordInput(
                      controller: _confirmController,
                      label: 'Confirm password',
                      hint: 'Re-enter your password',
                      textInputAction: TextInputAction.done,
                      enabled: !_isSubmitting,
                      onSubmitted: (_) => _submit(),
                      validator: (value) => value != _passwordController.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                    if (_failure case final failure?) ...[
                      const SizedBox(height: 14),
                      Text(
                        failure is ValidationFailure
                            ? failure.detailedMessage
                            : failure.message,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.destructive),
                      ),
                    ],
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Reset password',
                      expand: true,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed:
                          _isSubmitting ? null : () => context.go(Routes.login),
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

  /// The server matches `^\d{6}$` and answers 422 for anything else.
  String? _validateOtp(String? value) {
    final otp = value?.trim() ?? '';
    if (otp.isEmpty) return 'Enter the code from your email';
    if (otp.length != 6) return 'The code is 6 digits';
    return null;
  }

  /// The backend validator requires 8–128 characters.
  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Use at least 8 characters';
    if (password.length > 128) return 'Use at most 128 characters';
    return null;
  }
}

/// Says where the code went, without claiming one was definitely sent — the
/// server stays silent for unknown, inactive and unverified accounts alike.
class _SentToNotice extends StatelessWidget {
  const _SentToNotice({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: scheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 17,
            color: scheme.mutedForeground,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'If an account exists for ',
                  ),
                  TextSpan(
                    text: email,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(
                    text: ', a 6-digit code is on its way. It expires in 10 '
                        'minutes.',
                  ),
                ],
              ),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({
    required this.secondsLeft,
    required this.isResending,
    required this.onResend,
  });

  final int secondsLeft;
  final bool isResending;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waiting = secondsLeft > 0;

    return Row(
      children: [
        Flexible(
          child: Text(
            "Didn't get a code?",
            style: theme.textTheme.labelSmall,
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: waiting || isResending ? null : onResend,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            switch ((waiting, isResending)) {
              (_, true) => 'Sending…',
              (true, _) => 'Resend in ${secondsLeft}s',
              _ => 'Resend code',
            },
          ),
        ),
      ],
    );
  }
}
