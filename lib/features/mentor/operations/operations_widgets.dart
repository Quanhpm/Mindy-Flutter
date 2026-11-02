import 'package:flutter/material.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_error.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_widgets.dart';
export '../../../core/ui/staff/draft_guard.dart' show OperationsBack;
import '../../../core/utils/format.dart';

String operationError(Object error) {
  if (error is! ApiError) return errorKey(error);
  const known = {
    'LEAVE_NOTICE_TOO_SHORT',
    'LEAVE_SOURCE_STALE',
    'LEAVE_MAPPING_INVALID',
    'LEAVE_RANGE_INVALID',
    'LEAVE_REASON_INVALID',
    'LEAVE_STATUS_CONFLICT',
    'LEAVE_TARGET_CONFLICT',
    'LEAVE_SLOTS_STALE',
    'TEACHING_VERSION_CONFLICT',
    'TEACHING_NOTE_WINDOW_CLOSED',
    'TEACHING_NOTE_STATE_CONFLICT',
    'SESSION_VERSION_CONFLICT',
    'MEETING_URL_INVALID',
    'IDEMPOTENCY_KEY_REUSED',
  };
  return known.contains(error.code) ? 'mentor.operations.errors.${error.code}' : errorKey(error);
}

Widget operationFailure(Translator t, Object error) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 12),
  child: StaffDataState(title: t('mentor.operations.failed'), description: t(operationError(error)), error: error),
);

Future<String?> pickOperationDay(BuildContext context, {String? initial}) async {
  final now = DateTime.now();
  final parsed = initial == null ? now : DateTime.parse(initial);
  final day = await showDatePicker(
    context: context,
    initialDate: DateTime(parsed.year, parsed.month, parsed.day),
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  return day == null ? null : DateTime.utc(day.year, day.month, day.day).toIso8601String().substring(0, 10);
}

Widget operationDay(Translator t, {required String label, required String? day, required VoidCallback? onPressed}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StaffButton(
        outlined: true,
        label: '$label: ${day == null ? t('mentor.operations.chooseDate') : Dates.displayDay(day)}',
        onPressed: onPressed,
      ),
    );
