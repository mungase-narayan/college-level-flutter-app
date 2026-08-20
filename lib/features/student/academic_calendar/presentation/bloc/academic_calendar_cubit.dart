import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/academic_calendar.dart';
import '../../domain/usecases/academic_calendar_usecases.dart';

/// The published academic calendar, or the absence of one.
///
/// `T` is nullable on purpose. `RemoteState` keeps `status` separate from
/// `data`, so all four situations the screen has to tell apart stay distinct:
/// loading, success-with-a-calendar, **success-with-null** ("your school has
/// not published one"), and failure. Collapsing the third into either of the
/// others would either invent an error or claim a calendar exists.
class AcademicCalendarCubit extends RemoteCubit<AcademicCalendar?> {
  AcademicCalendarCubit({required GetMyAcademicCalendarUseCase getMyCalendar})
      : super(() => getMyCalendar(const NoParams()));
}
