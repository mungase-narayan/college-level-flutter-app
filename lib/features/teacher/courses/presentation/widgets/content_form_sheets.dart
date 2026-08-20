import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/error/failures.dart';
import '../../domain/entities/teacher_course_tree.dart';
import '../bloc/course_content_cubit.dart';
import '../bloc/teacher_course_detail_cubit.dart';
import 'material_form.dart';

/// Add or edit a module.
///
/// Port of `AddModuleDialog`. Passing [module] switches it to edit.
Future<void> showModuleSheet(
  BuildContext context, {
  required String courseId,
  required String divisionId,
  TeacherModule? module,
}) {
  final content = context.read<CourseContentCubit>();
  final detail = context.read<TeacherCourseDetailCubit>();

  return showAppSheet<void>(
    context,
    title: module == null ? 'Add module' : 'Edit module',
    builder: (sheetContext) => _NameDescriptionForm(
      nameLabel: 'Module name',
      nameHint: 'e.g. Introduction to Calculus',
      initialName: module?.name,
      initialDescription: module?.description,
      submitLabel: module == null ? 'Add module' : 'Save changes',
      onSubmit: (name, description) => module == null
          ? content.createModule(
              courseId: courseId,
              divisionId: divisionId,
              name: name,
              description: description,
            )
          : content.updateModule(
              id: module.id,
              name: name,
              description: description,
            ),
      onDone: detail.reloadTree,
      successMessage: module == null ? 'Module added.' : 'Module updated.',
    ),
  );
}

/// Add or edit a topic. Port of `AddTopicDialog`.
Future<void> showTopicSheet(
  BuildContext context, {
  required String courseId,
  required String divisionId,
  required String moduleId,
  required String moduleName,
  TeacherTopic? topic,
}) {
  final content = context.read<CourseContentCubit>();
  final detail = context.read<TeacherCourseDetailCubit>();

  return showAppSheet<void>(
    context,
    title: topic == null ? 'Add topic' : 'Edit topic',
    subtitle: moduleName.isEmpty ? null : 'Under $moduleName',
    builder: (sheetContext) => _NameDescriptionForm(
      nameLabel: 'Topic name',
      nameHint: 'e.g. Limits and Continuity',
      initialName: topic?.name,
      initialDescription: topic?.description,
      submitLabel: topic == null ? 'Add topic' : 'Save changes',
      onSubmit: (name, description) => topic == null
          ? content.createTopic(
              courseId: courseId,
              divisionId: divisionId,
              courseModuleId: moduleId,
              name: name,
              description: description,
            )
          : content.updateTopic(
              id: topic.id,
              name: name,
              description: description,
            ),
      onDone: detail.reloadTree,
      successMessage: topic == null ? 'Topic added.' : 'Topic updated.',
    ),
  );
}

/// Add or edit a material. Port of `AddMaterialDialog`.
Future<void> showMaterialSheet(
  BuildContext context, {
  required String courseId,
  required String divisionId,
  required String moduleId,
  required String topicId,
  required String topicName,
  TeacherMaterial? material,
}) {
  final content = context.read<CourseContentCubit>();
  final detail = context.read<TeacherCourseDetailCubit>();

  return showAppSheet<void>(
    context,
    title: material == null ? 'Add material' : 'Edit material',
    subtitle: topicName.isEmpty ? null : 'Under topic: $topicName',
    builder: (sheetContext) => MaterialForm(
      material: material,
      content: content,
      onDone: detail.reloadTree,
      courseId: courseId,
      divisionId: divisionId,
      moduleId: moduleId,
      topicId: topicId,
    ),
  );
}

/// The shared name + description form behind the module and topic sheets.
class _NameDescriptionForm extends StatefulWidget {
  const _NameDescriptionForm({
    required this.nameLabel,
    required this.nameHint,
    required this.submitLabel,
    required this.onSubmit,
    required this.onDone,
    required this.successMessage,
    this.initialName,
    this.initialDescription,
  });

  final String nameLabel;
  final String nameHint;
  final String submitLabel;
  final Future<Failure?> Function(String name, String? description) onSubmit;
  final Future<void> Function() onDone;
  final String successMessage;
  final String? initialName;
  final String? initialDescription;

  @override
  State<_NameDescriptionForm> createState() => _NameDescriptionFormState();
}

class _NameDescriptionFormState extends State<_NameDescriptionForm> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _description = TextEditingController(
    text: widget.initialDescription,
  );

  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The sheet supplies the body padding on both branches; a second layer
    // here would inset the fields and leave a band under the button.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          controller: _name,
          label: widget.nameLabel,
          hint: widget.nameHint,
          // The backend caps every content name at 200.
          inputFormatters: [LengthLimitingTextInputFormatter(200)],
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        AppInput(
          controller: _description,
          label: 'Description',
          hint: 'Optional',
          maxLines: 3,
        ),
        const SizedBox(height: 14),
        AppButton(
          label: widget.submitLabel,
          expand: true,
          isLoading: _busy,
          onPressed: _name.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    final description = _description.text.trim();
    final failure = await widget.onSubmit(
      _name.text.trim(),
      description.isEmpty ? null : description,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }

    Navigator.of(context).pop();
    AppToast.success(context, widget.successMessage);
    await widget.onDone();
  }
}
