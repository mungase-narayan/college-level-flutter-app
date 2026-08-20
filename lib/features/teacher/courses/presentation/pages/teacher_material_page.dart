import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/injection_modules/service_locator.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../../../../core/error/failures.dart';
import '../../../assessments/domain/usecases/teacher_assessment_usecases.dart';
import '../../../assessments/presentation/bloc/assessments_list_cubit.dart';
import '../../../assessments/presentation/widgets/material_assignments_panel.dart';
import '../../../../shared/auth/presentation/bloc/auth/auth_bloc.dart';
import '../../../../shared/files/domain/usecases/file_usecases.dart';
import '../../../../shared/files/presentation/widgets/attachment_tile.dart';
import '../../../../shared/notes/domain/entities/note.dart';
import '../../../../shared/notes/presentation/bloc/material_notes_cubit.dart';
import '../../../../shared/material_comments/domain/usecases/material_comment_usecases.dart';
import '../../../../shared/material_comments/presentation/bloc/material_comments_cubit.dart';
import '../../../../shared/material_comments/presentation/widgets/material_comments_tab.dart';
import '../../../../shared/notes/presentation/widgets/material_notes_tab.dart';
import '../../domain/entities/teacher_course_tree.dart';
import '../../domain/repositories/teacher_course_repository.dart';
import '../bloc/course_content_cubit.dart';
import '../bloc/teacher_course_detail_cubit.dart';

/// Port of the teacher's `MaterialTabs` — the content half of the web's split
/// view, as a pushed screen.
///
/// The web edits Content, Video and Attachments **in place**, each saving a
/// one-field `PATCH`; this does the same, behind an edit affordance that only
/// the material's author sees.
class TeacherMaterialPage extends StatelessWidget {
  const TeacherMaterialPage({
    super.key,
    required this.courseId,
    required this.materialId,
  });

  final String courseId;
  final String materialId;

  /// Pushes the screen carrying the caller's cubits, so the tree stays one
  /// source of truth: an edit here reloads it and the row behind updates with
  /// nothing to keep in sync.
  ///
  /// A `go_router` route would have to rebuild those cubits from scratch and
  /// refetch the whole tree just to name one material.
  static Future<void> push(
    BuildContext context, {
    required String courseId,
    required String materialId,
  }) {
    final detail = context.read<TeacherCourseDetailCubit>();
    final content = context.read<CourseContentCubit>();

    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: detail),
            BlocProvider.value(value: content),
          ],
          child: TeacherMaterialPage(
            courseId: courseId,
            materialId: materialId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-derived from the tree on every build, so a save that reloads the tree
    // shows through here immediately.
    return BlocBuilder<TeacherCourseDetailCubit,
        RemoteState<TeacherCourseDetailData>>(
      builder: (context, state) {
        final located = state.data?.tree.locate(materialId);

        if (located == null) {
          return Scaffold(
            appBar: const AdaptiveAppBar(title: 'Material'),
            body: state.isInitialLoading
                ? const AppLoader()
                : const AppEmptyState(
                    title: 'Material unavailable',
                    description: 'It may have been removed from this course.',
                    icon: Icons.description_outlined,
                  ),
          );
        }

        return _MaterialScaffold(
          courseId: courseId,
          divisionId: state.data!.divisionId,
          location: located,
        );
      },
    );
  }
}

class _MaterialScaffold extends StatelessWidget {
  const _MaterialScaffold({
    required this.courseId,
    required this.divisionId,
    required this.location,
  });

  final String courseId;

  /// The section the comment thread belongs to — required by the teacher
  /// comment endpoints.
  final String divisionId;
  final TeacherMaterialLocation location;

  /// The teacher repository, which is what satisfies the shared
  /// [MaterialCommentSource] contract the comment use cases are written against.
  TeacherCourseRepository get _comments => sl<TeacherCourseRepository>();

  @override
  Widget build(BuildContext context) {
    final material = location.material;
    final userId = context.select((AuthBloc bloc) => bloc.state.user?.id) ?? '';
    final canEdit = material.canManage(userId);

    // Unlike the student screen, the Video tab is always present for an author
    // — it is where a video is *added*, so hiding it when there is none would
    // leave no way in.
    final hasVideo = (material.videoUrl ?? '').trim().isNotEmpty;
    final showVideo = hasVideo || canEdit;

    final tabs = <Tab>[
      const Tab(text: 'Content'),
      if (showVideo) const Tab(text: 'Video'),
      Tab(child: _AttachmentsLabel(count: material.attachments.length)),
      const Tab(text: 'Assignments'),
      const Tab(text: 'Notes'),
      const Tab(text: 'Comments'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AdaptiveAppBar(
          title: material.name,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _Header(location: location, canEdit: canEdit),
              Expanded(
                child: TabBarView(
                  children: [
                    _ContentTab(material: material, canEdit: canEdit),
                    if (showVideo)
                      _VideoTab(material: material, canEdit: canEdit),
                    _AttachmentsTab(material: material, canEdit: canEdit),
                    // Scoped by material rather than by section: an assignment
                    // published against a material reaches every section, so
                    // no division is passed.
                    BlocProvider(
                      create: (_) => AssessmentsListCubit(
                        assessments: sl<TeacherAssessmentUseCases>(),
                        courseId: courseId,
                        courseMaterialId: material.id,
                        quizzes: false,
                      ),
                      child: MaterialAssignmentsPanel(
                        courseMaterialId: material.id,
                        divisionId: divisionId,
                      ),
                    ),
                    BlocProvider(
                      create: (_) => MaterialNotesCubit(
                        list: sl(),
                        create: sl(),
                        link: NoteLinkContext(
                          courseId: courseId,
                          materialId: material.id,
                        ),
                      ),
                      child: const MaterialNotesTab(),
                    ),
                    // The same cubit and widget the student thread uses — the
                    // teacher repository satisfies the shared comment contract,
                    // and the only difference on the wire is the section.
                    BlocProvider(
                      create: (_) => MaterialCommentsCubit(
                        list: ListMaterialCommentsUseCase(_comments),
                        create: CreateMaterialCommentUseCase(_comments),
                        reply: ReplyToMaterialCommentUseCase(_comments),
                        update: UpdateMaterialCommentUseCase(_comments),
                        remove: DeleteMaterialCommentUseCase(_comments),
                        materialId: material.id,
                        divisionId: divisionId,
                      ),
                      child: const MaterialCommentsTab(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the material sits, plus the school-wide notice when it is read-only.
class _Header extends StatelessWidget {
  const _Header({required this.location, required this.canEdit});

  final TeacherMaterialLocation location;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final material = location.material;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${location.module.name} · ${location.topic.name}',
            style: theme.textTheme.labelSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if ((material.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(material.description!, style: theme.textTheme.bodySmall),
          ],
          if (!canEdit) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  material.isGlobal
                      ? Icons.public_rounded
                      : Icons.lock_outline_rounded,
                  size: 14,
                  color: scheme.mutedForeground,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    material.isGlobal
                        ? 'School-wide material — read-only.'
                        : 'Added by another teacher — read-only.',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContentTab extends StatelessWidget {
  const _ContentTab({required this.material, required this.canEdit});

  final TeacherMaterial material;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final body = (material.content ?? '').trim();

    if (body.isEmpty) {
      return AppEmptyState(
        icon: Icons.notes_rounded,
        title: 'No content yet',
        description: canEdit
            ? 'Add the body students will read for this material.'
            : 'Nothing has been written for this material.',
        action: canEdit
            ? AppButton(
                label: 'Add content',
                onPressed: () => _edit(context, material),
              )
            : null,
      );
    }

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
          children: [AppMarkdown(material.content)],
        ),
        if (canEdit)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: () => _edit(context, material),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
          ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, TeacherMaterial material) =>
      _editField(
        context,
        title: 'Content',
        initial: material.content ?? '',
        hint: 'Markdown is supported',
        maxLines: 14,
        onSave: (value) => context.read<CourseContentCubit>().updateMaterial(
              id: material.id,
              content: value.isEmpty ? null : value,
            ),
        success: 'Content saved.',
      );
}

class _VideoTab extends StatelessWidget {
  const _VideoTab({required this.material, required this.canEdit});

  final TeacherMaterial material;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final url = (material.videoUrl ?? '').trim();

    if (url.isEmpty) {
      return AppEmptyState(
        icon: Icons.play_circle_outline_rounded,
        title: 'No video yet',
        description: 'Link a YouTube, Vimeo, or direct video URL.',
        action: AppButton(
          label: 'Add video',
          onPressed: () => _edit(context),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        VideoPreview(url: url),
        if (canEdit) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Change video',
                  variant: AppButtonVariant.outline,
                  onPressed: () => _edit(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Remove',
                  variant: AppButtonVariant.outline,
                  onPressed: () => _remove(context),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _edit(BuildContext context) => _editField(
        context,
        title: 'Video URL',
        initial: material.videoUrl ?? '',
        hint: 'https://…',
        maxLines: 1,
        // Matches the web's `new URL()` check — a malformed link renders an
        // empty player rather than failing visibly.
        validate: (value) =>
            value.isEmpty || Uri.tryParse(value)?.hasAbsolutePath == true
                ? null
                : 'Enter a valid URL (including https://).',
        onSave: (value) => context.read<CourseContentCubit>().updateMaterial(
              id: material.id,
              videoUrl: value.isEmpty ? null : value,
            ),
        success: 'Video updated.',
      );

  Future<void> _remove(BuildContext context) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Remove video?',
      message: 'The link will be cleared from this material.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    final detail = context.read<TeacherCourseDetailCubit>();
    // An explicit null clears the column — an omitted key would leave it.
    final failure = await context
        .read<CourseContentCubit>()
        .updateMaterial(id: material.id, videoUrl: null);
    if (!context.mounted) return;

    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, 'Video removed.');
    await detail.reloadTree();
  }
}

class _AttachmentsTab extends StatelessWidget {
  const _AttachmentsTab({required this.material, required this.canEdit});

  final TeacherMaterial material;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final ids = material.attachments;

    if (ids.isEmpty) {
      return AppEmptyState(
        icon: Icons.attach_file_rounded,
        title: 'No attachments',
        description: canEdit
            ? 'Attach slides, notes, or any file students should download.'
            : 'Nothing is attached to this material.',
        action: canEdit
            ? AppButton(
                label: 'Attach files',
                onPressed: () => _add(context),
              )
            : null,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        for (final id in ids)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AttachmentTile(
              fileId: id,
              onRemove: canEdit ? () => _remove(context, id) : null,
            ),
          ),
        if (canEdit) ...[
          const SizedBox(height: 6),
          AppButton(
            label: 'Attach more',
            icon: Icons.attach_file_rounded,
            variant: AppButtonVariant.outline,
            expand: true,
            onPressed: () => _add(context),
          ),
        ],
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      // Paths, not bytes: `DioClient.uploadFile` streams from a path.
      withData: false,
    );
    final files = [
      for (final file in picked?.files ?? const <PlatformFile>[])
        if (file.path != null) (path: file.path!, name: file.name),
    ];
    if (files.isEmpty || !context.mounted) return;

    final detail = context.read<TeacherCourseDetailCubit>();
    final content = context.read<CourseContentCubit>();

    // One request for the whole batch, so the attachments land as a unit.
    final result = await sl<UploadFilesUseCase>()(UploadFilesParams(files));
    if (!context.mounted) return;

    final uploaded = result.fold<List<String>?>(
      (failure) {
        AppToast.failure(context, failure);
        return null;
      },
      (files) => [for (final file in files) file.id],
    );
    if (uploaded == null || uploaded.isEmpty) return;

    // The whole list is sent, not a delta — `attachments` is replaced wholesale.
    final saved = await content.updateMaterial(
      id: material.id,
      attachments: [...material.attachments, ...uploaded],
    );
    if (!context.mounted) return;

    if (saved != null) {
      AppToast.failure(context, saved);
      return;
    }
    AppToast.success(
      context,
      uploaded.length == 1
          ? 'File attached.'
          : '${uploaded.length} files attached.',
    );
    await detail.reloadTree();
  }

  Future<void> _remove(BuildContext context, String fileId) async {
    final detail = context.read<TeacherCourseDetailCubit>();
    final failure = await context.read<CourseContentCubit>().updateMaterial(
          id: material.id,
          attachments: [
            for (final id in material.attachments)
              if (id != fileId) id,
          ],
        );
    if (!context.mounted) return;

    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    AppToast.success(context, 'Attachment removed.');
    await detail.reloadTree();
  }
}

/// One-field edit sheet shared by Content and Video.
///
/// Saving patches just that field, so an edit here can never clobber another
/// one the teacher did not touch.
Future<void> _editField(
  BuildContext context, {
  required String title,
  required String initial,
  required String hint,
  required int maxLines,
  required Future<Failure?> Function(String value) onSave,
  required String success,
  String? Function(String value)? validate,
}) async {
  final detail = context.read<TeacherCourseDetailCubit>();

  final saved = await showAppSheet<bool>(
    context,
    title: title,
    builder: (sheetContext) => _FieldForm(
      initial: initial,
      hint: hint,
      maxLines: maxLines,
      validate: validate,
      onSave: onSave,
    ),
  );
  if (saved != true || !context.mounted) return;

  AppToast.success(context, success);
  await detail.reloadTree();
}

class _FieldForm extends StatefulWidget {
  const _FieldForm({
    required this.initial,
    required this.hint,
    required this.maxLines,
    required this.onSave,
    this.validate,
  });

  final String initial;
  final String hint;
  final int maxLines;
  final Future<Failure?> Function(String value) onSave;
  final String? Function(String value)? validate;

  @override
  State<_FieldForm> createState() => _FieldFormState();
}

class _FieldFormState extends State<_FieldForm> {
  late final _controller = TextEditingController(text: widget.initial);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No padding of its own: `showAppSheet` already wraps the body in a padded
    // scroll view on both branches, and adding a second layer was what made the
    // field look inset and left a wide band under the button.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          controller: _controller,
          hint: widget.hint,
          maxLines: widget.maxLines,
          minLines: widget.maxLines > 1 ? 4 : null,
          errorText: _error,
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 14),
        AppButton(
          label: 'Save',
          expand: true,
          isLoading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    final error = widget.validate?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() => _busy = true);
    final failure = await widget.onSave(value);
    if (!mounted) return;
    setState(() => _busy = false);

    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    Navigator.of(context).pop(true);
  }
}

/// `Attachments 3` — the tab strip's one piece of live data.
class _AttachmentsLabel extends StatelessWidget {
  const _AttachmentsLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Attachments'),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.muted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.mutedForeground,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
