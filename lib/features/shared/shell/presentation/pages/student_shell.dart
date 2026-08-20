import 'package:flutter/material.dart';

import '../../../../../core/usecases/usecase.dart';
import '../../../../student/rewards/domain/usecases/rewards_usecases.dart';
import '../widgets/student_nav.dart';
import 'app_shell.dart';

/// Port of `src/pages/student/layout.tsx`.
///
/// [AppShell] supplies the whole chrome; this binds it to the student nav tree
/// and to the one behaviour that belongs to the student area alone — the daily
/// rewards visit `DailyVisitTracker` fires on mount.
class StudentShell extends StatelessWidget {
  const StudentShell({
    super.key,
    required this.child,
    required this.recordDailyVisit,
  });

  final Widget child;
  final RecordDailyVisitUseCase recordDailyVisit;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      spec: StudentNav.spec,
      // Fire-and-forget once per app session; the backend is idempotent per IST
      // day and awards +1 point on the first call.
      onFirstBuild: () => recordDailyVisit(const NoParams()),
      child: child,
    );
  }
}
