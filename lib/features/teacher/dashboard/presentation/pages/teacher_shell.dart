import 'package:flutter/material.dart';

import '../../../../shared/shell/presentation/pages/app_shell.dart';
import '../../../../shared/shell/presentation/widgets/teacher_nav.dart';

/// Port of `src/pages/teacher/layout.tsx`.
///
/// [AppShell] supplies the whole chrome; this binds it to the teacher nav tree.
/// Unlike the student shell there is no mount-time side effect — the daily
/// rewards visit is a student-only concept.
class TeacherShell extends StatelessWidget {
  const TeacherShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      AppShell(spec: TeacherNav.spec, child: child);
}
