import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/injection_modules/service_locator.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../shared/files/domain/usecases/file_usecases.dart';
import '../../domain/entities/teacher_course_tree.dart';
import '../bloc/course_content_cubit.dart';

/// Port of `AddMaterialDialog` — the one content form with more than a name.
///
/// Name, video URL, description, markdown body, and attachments. Files are
/// uploaded first and only their ids are sent with the material, which is the
/// contract the API expects.
class MaterialForm extends StatefulWidget {
  const MaterialForm({
    super.key,
    required this.content,
    required this.onDone,
    required this.courseId,
    required this.divisionId,
    required this.moduleId,
    required this.topicId,
    this.material,
  });

  final CourseContentCubit content;
  final Future<void> Function() onDone;
  final String courseId;
  final String divisionId;
  final String moduleId;
  final String topicId;

  /// Present when editing.
  final TeacherMaterial? material;

  @override
  State<MaterialForm> createState() => _MaterialFormState();
}

class _MaterialFormState extends State<MaterialForm> {
  late final _name = TextEditingController(text: widget.material?.name);
  late final _description = TextEditingController(
    text: widget.material?.description,
  );
  late final _videoUrl = TextEditingController(text: widget.material?.videoUrl);
  late final _body = TextEditingController(text: widget.material?.content);

  late List<String> _attachments = List<String>.from(
    widget.material?.attachments ?? const [],
  );

  bool _busy = false;
  String? _videoError;

  bool get _isEdit => widget.material != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _videoUrl.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Neither a scroll view nor padding of its own: `showAppSheet` already
    // wraps the body in a padded `SingleChildScrollView` on both branches, and
    // nesting a second scrollable inside it is a layout bug as well as a
    // double inset.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          controller: _name,
          label: 'Material name',
          hint: 'e.g. AVL rotation notes',
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        AppInput(
          controller: _videoUrl,
          label: 'Video URL',
          hint: 'Optional — YouTube, Vimeo, or a direct link',
          keyboardType: TextInputType.url,
          errorText: _videoError,
          onChanged: (_) => setState(() => _videoError = null),
        ),
        const SizedBox(height: 12),
        AppInput(
          controller: _description,
          label: 'Description',
          hint: 'Optional',
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        AppInput(
          controller: _body,
          label: 'Content (Markdown)',
          hint: 'Optional — the body students read',
          maxLines: 8,
          minLines: 4,
        ),
        const SizedBox(height: 16),
        _Attachments(
          ids: _attachments,
          busy: _busy,
          onAdd: _pickFiles,
          onRemove: (id) => setState(() => _attachments.remove(id)),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: _isEdit ? 'Save changes' : 'Add material',
          expand: true,
          isLoading: _busy,
          onPressed: _name.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }

  /// Picks files and uploads them, keeping only the returned ids.
  ///
  /// Paths rather than bytes, matching `attempt_runner` — the uploader streams
  /// from a path, so loading a document into memory to hand it straight back
  /// would be wasted heap.
  Future<void> _pickFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    final files = [
      for (final file in picked?.files ?? const <PlatformFile>[])
        if (file.path != null) (path: file.path!, name: file.name),
    ];
    if (files.isEmpty || !mounted) return;

    setState(() => _busy = true);
    // One request for the whole batch rather than a loop: fewer round trips,
    // and the files land as a unit instead of half-attaching on a mid-way error.
    final result = await sl<UploadFilesUseCase>()(UploadFilesParams(files));
    if (!mounted) return;
    setState(() => _busy = false);

    result.fold((failure) => AppToast.failure(context, failure), (uploaded) {
      if (uploaded.isEmpty) return;
      final ids = [for (final file in uploaded) file.id];
      setState(() => _attachments = [..._attachments, ...ids]);
      AppToast.success(
        context,
        ids.length == 1 ? 'File attached.' : '${ids.length} files attached.',
      );
    });
  }

  Future<void> _submit() async {
    final video = _videoUrl.text.trim();
    // Matches the web's `new URL()` check — a malformed link would render an
    // empty player rather than failing visibly.
    if (video.isNotEmpty && Uri.tryParse(video)?.hasAbsolutePath != true) {
      setState(() => _videoError = 'Enter a valid URL (including https://).');
      return;
    }

    setState(() => _busy = true);
    final name = _name.text.trim();
    final description = _description.text.trim();
    final body = _body.text.trim();

    final failure = _isEdit
        ? await widget.content.updateMaterial(
            id: widget.material!.id,
            name: name,
            // Explicit nulls clear the column, which is how a field is emptied.
            description: description.isEmpty ? null : description,
            content: body.isEmpty ? null : body,
            videoUrl: video.isEmpty ? null : video,
            attachments: _attachments,
          )
        : await widget.content.createMaterial(
            courseId: widget.courseId,
            divisionId: widget.divisionId,
            courseModuleId: widget.moduleId,
            courseTopicId: widget.topicId,
            name: name,
            description: description.isEmpty ? null : description,
            content: body.isEmpty ? null : body,
            videoUrl: video.isEmpty ? null : video,
            attachments: _attachments,
          );

    if (!mounted) return;
    setState(() => _busy = false);

    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }

    Navigator.of(context).pop();
    AppToast.success(
      context,
      _isEdit ? 'Material updated.' : 'Material added.',
    );
    await widget.onDone();
  }
}

class _Attachments extends StatelessWidget {
  const _Attachments({
    required this.ids,
    required this.busy,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> ids;
  final bool busy;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Attachments', style: theme.textTheme.labelMedium),
            const Spacer(),
            AppButton(
              label: 'Add files',
              icon: Icons.attach_file_rounded,
              variant: AppButtonVariant.outline,
              size: AppButtonSize.sm,
              onPressed: busy ? null : onAdd,
            ),
          ],
        ),
        if (ids.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'No files attached.',
              style: theme.textTheme.labelSmall,
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final id in ids)
                  Chip(
                    label: Text(
                      // The id is all the form has; names resolve on the
                      // material screen, which fetches the file metadata.
                      '${id.substring(0, id.length.clamp(0, 8))}…',
                      style: theme.textTheme.labelSmall,
                    ),
                    onDeleted: () => onRemove(id),
                    deleteIcon: const Icon(Icons.close_rounded, size: 15),
                    side: BorderSide(color: scheme.border),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
