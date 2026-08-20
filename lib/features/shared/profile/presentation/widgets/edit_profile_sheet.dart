import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/injection_modules/service_locator.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/design/utils/glass_haptics.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../auth/domain/username_rules.dart';
import '../../../auth/domain/usecases/auth_usecases.dart';
import '../../../auth/presentation/bloc/auth/auth_bloc.dart';

/// Edit username and profile picture — the two fields `PATCH /users/me` accepts.
///
/// Port of the web app's `settings/components/edit-profile-dialog.tsx`, including
/// its validation rules verbatim so the two clients cannot disagree about what the
/// backend will accept and produce different error messages for the same input.
Future<void> showEditProfileSheet(BuildContext context, User user) =>
    showAppSheet<void>(
      context,
      title: 'Edit profile',
      subtitle: 'Change your username and profile picture',
      builder: (context) => _EditProfileForm(user: user),
    );

class _EditProfileForm extends StatefulWidget {
  const _EditProfileForm({required this.user});

  final User user;

  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _username =
      TextEditingController(text: widget.user.username);

  /// The avatar as it will be saved: the existing URL until a new image is
  /// uploaded, at which point this holds the freshly uploaded one.
  late String? _avatar = widget.user.avatar;

  bool _uploading = false;
  bool _saving = false;

  bool get _busy => _uploading || _saving;

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _uploading = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        // Downscaled and recompressed before upload: a modern phone photo is
        // 3–8MB, and the web app rejects anything over 5MB. An avatar is never
        // rendered above ~150pt, so this loses nothing visible.
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final url = await sl<UploadAvatarUseCase>()(
        UploadAvatarParams(filePath: picked.path, fileName: picked.name),
      );
      if (!mounted) return;

      url.fold(
        (failure) => AppToast.failure(context, failure),
        (uploaded) {
          GlassHaptics.success();
          setState(() => _avatar = uploaded);
        },
      );
    } on Object catch (_) {
      // A denied photo-library permission surfaces as a PlatformException; the
      // picker is not worth crashing the sheet over.
      if (mounted) {
        AppToast.error(context, 'Could not open your photos. Check permissions.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _chooseSource() async {
    final source = await showAppOptionSheet<ImageSource>(
      context,
      title: 'Profile picture',
      options: const [
        AppSheetOption(
          value: ImageSource.gallery,
          label: 'Choose from library',
          icon: Icons.photo_library_outlined,
        ),
        AppSheetOption(
          value: ImageSource.camera,
          label: 'Take a photo',
          icon: Icons.photo_camera_outlined,
        ),
      ],
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final username = UsernameRules.normalize(_username.text);
    final usernameChanged = username != widget.user.username;
    final avatarChanged = _avatar != widget.user.avatar;

    // `PATCH /users/me` answers 400 "No fields provided to update" for an empty
    // body, so a no-op save must close rather than send nothing.
    if (!usernameChanged && !avatarChanged) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);
    final result = await sl<UpdateMyAccountUseCase>()(
      UpdateMyAccountParams(
        username: usernameChanged ? username : null,
        avatar: avatarChanged ? _avatar : null,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    result.fold(
      // A taken username comes back as 409 with the backend's own message.
      (failure) => AppToast.failure(context, failure),
      (user) {
        GlassHaptics.success();
        // Updates the session in place, so every avatar and name in the app —
        // the app bar, the menu sheet, the profile header — refreshes at once.
        context.read<AuthBloc>().add(AuthUserUpdated(user));
        AppToast.success(context, 'Profile updated');
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _AvatarPreview(url: _avatar, name: widget.user.displayName),
                    if (_uploading)
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x99000000),
                          ),
                          child: Center(child: AppLoader()),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                AppButton(
                  label: _avatar == null ? 'Add photo' : 'Change photo',
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.sm,
                  icon: Icons.photo_camera_outlined,
                  onPressed: _busy ? null : _chooseSource,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppInput(
            controller: _username,
            label: 'Username',
            hint: 'Choose a username',
            prefixIcon: Icons.alternate_email_rounded,
            enabled: !_busy,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            validator: UsernameRules.validate,
          ),
          const SizedBox(height: 6),
          Text(
            'Your unique handle across the app. Defaults to your email.',
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Cancel',
                  variant: AppButtonVariant.outline,
                  expand: true,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Save changes',
                  expand: true,
                  isLoading: _saving,
                  onPressed: _busy ? null : _save,
                ),
              ),
            ],
          ),
          if (_uploading) ...[
            const SizedBox(height: 12),
            Text(
              'Uploading photo…',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}

/// The avatar being edited, with a brand ring so it reads as the subject of the
/// sheet rather than as decoration.
class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.45),
          width: 2,
        ),
      ),
      // Always a network URL: `_avatar` is only assigned after the upload
      // succeeds, so there is never a local file to preview here.
      child: AppAvatar(imageUrl: url, name: name, size: 84),
    );
  }
}
