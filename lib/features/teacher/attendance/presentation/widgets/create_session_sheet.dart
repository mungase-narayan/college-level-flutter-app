import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../../core/common/widgets/widgets.dart';
import '../../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/attendance_session.dart';
import '../bloc/attendance_tab_cubit.dart';

/// Creates a session from a form. Returns the new session's id, or null when
/// the sheet was dismissed.
///
/// Port of `CreateSessionDialog`, minus its course and division pickers: this
/// sheet is only ever opened from inside a course whose section is already
/// chosen, so asking again would be busywork.
Future<String?> showCreateSessionSheet(
  BuildContext context, {
  required String courseId,
  required String divisionId,
}) {
  final cubit = context.read<AttendanceTabCubit>();

  return showAppSheet<String>(
    context,
    title: 'Create session',
    builder: (_) => _CreateSessionForm(
      cubit: cubit,
      courseId: courseId,
      divisionId: divisionId,
    ),
  );
}

/// Creates a session straight from a timetable slot — no form.
///
/// The slot already carries the course, division, times and title, so the web
/// skips its dialog here too.
Future<String?> createSessionFromSlot(
  BuildContext context, {
  required TodaySlot slot,
}) async {
  final cubit = context.read<AttendanceTabCubit>();
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final result = await cubit.createSession(
    courseId: slot.courseId,
    divisionId: slot.divisionId,
    // A timetable slot is a scheduled class; the web hardcodes the same.
    type: AttendanceType.lecture,
    sessionDate: today,
    startTime: _isoAt(today, slot.startTime) ?? DateTime.now().toIso8601String(),
    endTime: _isoAt(today, slot.endTime),
    topic: slot.title.trim().isEmpty ? null : slot.title.trim(),
    timetableSlotId: slot.id,
  );
  if (!context.mounted) return null;

  return result.fold(
    (failure) {
      AppToast.failure(context, failure);
      return null;
    },
    (session) {
      AppToast.success(context, 'Attendance session created.');
      return session.id;
    },
  );
}

/// Combines a `YYYY-MM-DD` with a `HH:MM:SS` clock string into an ISO instant.
String? _isoAt(String date, String? clock) {
  if (clock == null || clock.isEmpty) return null;
  final parsed = DateTime.tryParse('${date}T$clock');
  return parsed?.toUtc().toIso8601String();
}

class _CreateSessionForm extends StatefulWidget {
  const _CreateSessionForm({
    required this.cubit,
    required this.courseId,
    required this.divisionId,
  });

  final AttendanceTabCubit cubit;
  final String courseId;
  final String divisionId;

  @override
  State<_CreateSessionForm> createState() => _CreateSessionFormState();
}

class _CreateSessionFormState extends State<_CreateSessionForm> {
  String _type = AttendanceType.lecture;
  DateTime _date = DateTime.now();
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay? _end = const TimeOfDay(hour: 10, minute: 0);

  final _topic = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSelect<String>(
          label: 'Session type',
          value: _type,
          items: [
            for (final type in AttendanceType.options)
              AppSelectItem<String>(
                value: type,
                label: AttendanceType.label(type),
              ),
          ],
          onChanged: (value) => setState(() => _type = value ?? _type),
        ),
        const SizedBox(height: 12),
        AppInput(
          controller: _topic,
          label: 'Topic',
          hint: 'Optional — what the class covers',
        ),
        const SizedBox(height: 12),
        _PickerRow(
          label: 'Date',
          value: DateFormat('EEE, d MMM yyyy').format(_date),
          onTap: _pickDate,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _PickerRow(
                label: 'Starts',
                value: _start.format(context),
                onTap: () => _pickTime(isStart: true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PickerRow(
                label: 'Ends',
                value: _end?.format(context) ?? 'Optional',
                onTap: () => _pickTime(isStart: false),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: context.scheme.destructive),
          ),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: 'Create session',
          expand: true,
          isLoading: _busy,
          onPressed: _submit,
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 1),
      lastDate: DateTime(_date.year + 1),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : (_end ?? _start),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    final end = _end;
    // The web's one cross-field rule.
    if (end != null && _minutes(end) <= _minutes(_start)) {
      setState(() => _error = 'End time must be after start time.');
      return;
    }

    setState(() => _busy = true);
    final date = DateFormat('yyyy-MM-dd').format(_date);
    final topic = _topic.text.trim();

    final result = await widget.cubit.createSession(
      courseId: widget.courseId,
      divisionId: widget.divisionId,
      type: _type,
      sessionDate: date,
      startTime: _iso(_date, _start),
      endTime: end == null ? null : _iso(_date, end),
      topic: topic.isEmpty ? null : topic,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    result.fold(
      (failure) => AppToast.failure(context, failure),
      (session) {
        Navigator.of(context).pop(session.id);
        AppToast.success(context, 'Attendance session created.');
      },
    );
  }

  static int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  /// Local wall-clock → UTC instant, which is what the column stores.
  static String _iso(DateTime date, TimeOfDay time) => DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ).toUtc().toIso8601String();
}

/// A labelled row that opens a platform picker.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: 2),
            Text(value, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
