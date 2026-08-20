import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/error/failures.dart';
import '../../domain/usecases/accept_invitation_usecase.dart';

/// Port of `src/pages/auth/set-password/index.tsx`.
///
/// Invitation acceptance is the only way an account is ever activated — the
/// backend has no self-registration route. The token arrives as
/// `/invite/set-password?token=…` in the invitation email; when the app is
/// opened without one, the page renders the "invalid link" state and offers a
/// field to paste the token manually.
class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key, required this.acceptInvitation, this.token});

  final AcceptInvitationUseCase acceptInvitation;
  final String? token;

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late final TextEditingController _tokenController =
      TextEditingController(text: widget.token ?? '');

  bool _isSubmitting = false;
  Failure? _failure;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final result = await widget.acceptInvitation(
      AcceptInvitationParams(
        token: _tokenController.text.trim(),
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
        AppToast.success(context, 'Password set. You can now sign in.');
        context.go('/auth/login');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final hasTokenFromLink = (widget.token ?? '').isNotEmpty;

    return Scaffold(
      appBar: const AdaptiveAppBar(title: 'Set your password'),
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
                    if (!hasTokenFromLink) ...[
                      Container(
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
                              Icons.info_outline_rounded,
                              size: 17,
                              color: scheme.mutedForeground,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This link is missing its invitation token. Paste the '
                                'token from your invitation email below.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppInput(
                        controller: _tokenController,
                        label: 'Invitation token',
                        hint: 'Paste the token from your email',
                        maxLines: 3,
                        enabled: !_isSubmitting,
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'The invitation token is required'
                            : null,
                      ),
                      const SizedBox(height: 18),
                    ],
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
                    if (_failure != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _failure is ValidationFailure
                            ? (_failure! as ValidationFailure).detailedMessage
                            : _failure!.message,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.destructive),
                      ),
                    ],
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Set password',
                      expand: true,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/auth/login'),
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

  /// The backend validator requires 8–128 characters.
  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Use at least 8 characters';
    if (password.length > 128) return 'Use at most 128 characters';
    return null;
  }
}
