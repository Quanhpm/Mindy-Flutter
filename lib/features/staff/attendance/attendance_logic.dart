import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../teaching/teaching_models.dart';
import 'attendance_models.dart';

/// Clone `modules/attendance/model.ts` + `services/intentKey.ts`.

/// Đếm theo ký tự Unicode (Array.from).
int noteLength(String text) => text.runes.length;

class BatchLimitError implements Exception {
  const BatchLimitError();
}

/// Đổi trạng thái 1 hàng trong nháp; về lại trạng thái gốc thì bỏ khỏi nháp. Tối đa 100 hàng/loại.
Draft changeDraft(Draft draft, AttendanceRow row, Mark status) {
  final result = Map<String, DraftItem>.of(draft);
  final baseStatus = draft[row.id]?.baseStatus ?? row.status;
  if (status == baseStatus) {
    result.remove(row.id);
  } else {
    final count = draft.values.where((item) => item.entryType == row.entryType).length;
    if (!draft.containsKey(row.id) && count >= 100) throw const BatchLimitError();
    result[row.id] = (baseStatus: baseStatus, status: status, entryType: row.entryType);
  }
  return result;
}

/// So nháp với dữ liệu mới: hàng mất -> dropped; hàng có trạng thái server khác gốc -> conflict.
({Draft draft, List<String> conflicts, int dropped}) compareDraft(Draft draft, List<AttendanceRow> rows) {
  final result = <String, DraftItem>{};
  final conflicts = <String>[];
  var dropped = 0;
  for (final entry in draft.entries) {
    final row = rows.where((r) => r.id == entry.key).firstOrNull;
    if (row == null) {
      dropped++;
      continue;
    }
    result[entry.key] = entry.value;
    if (row.status != entry.value.baseStatus) conflicts.add(entry.key);
  }
  return (draft: result, conflicts: conflicts, dropped: dropped);
}

/// `DD/MM/YYYY` + `HH:mm` (giờ VN) -> ISO `YYYY-MM-DDTHH:mm:00+07:00`, sai -> null.
String? parseVietnamTime(String date, String time) {
  if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(date) || !RegExp(r'^\d{2}:\d{2}$').hasMatch(time)) return null;
  final d = date.split('/').map(int.parse).toList();
  final t = time.split(':').map(int.parse).toList();
  final test = DateTime.utc(d[2], d[1], d[0]);
  if (test.year != d[2] || test.month != d[1] || test.day != d[0] || t[0] > 23 || t[1] > 59) return null;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d[2]}-${two(d[1])}-${two(d[0])}T$time:00+07:00';
}

/// Căn cứ ghi nhận khi khôi phục: đã trả trước giờ học / trả tiền mặt muộn.
Basis? admissionBasis(EnrollmentStatus status, PaymentMethod method, DateTime? paidAt, DateTime startedAt) {
  if (!const [EnrollmentStatus.ACTIVE, EnrollmentStatus.COMPLETED, EnrollmentStatus.CANCELLED].contains(status) ||
      paidAt == null) {
    return null;
  }
  if (!paidAt.isAfter(startedAt)) return Basis.PAID_BEFORE_START;
  return method == PaymentMethod.CASH ? Basis.CASH_LATE_ADMISSION : null;
}

/// Kích thước JSON UTF-8 (giới hạn 256KB của request khôi phục).
int requestBytes(Object body) => utf8.encode(jsonEncode(body)).length;

int recoveryRequestBytes(AttendanceIntent intent) => requestBytes({
  'expectedVersion': intent.expectedVersion,
  'reason': intent.reason,
  'evidenceNote': intent.evidenceNote,
  'actualStartedAt': intent.actualStartedAt,
  'actualEndedAt': intent.actualEndedAt,
  'records': intent.recoveryRecords?.map((r) => r.toJson()).toList(),
});

DateTime _vn(DateTime v) => v.toUtc().add(const Duration(hours: 7));
String _two(int v) => v.toString().padLeft(2, '0');

/// `DD/MM/YYYY` giờ VN.
String isoDate(DateTime value) {
  final d = _vn(value);
  return '${_two(d.day)}/${_two(d.month)}/${d.year}';
}

/// `HH:mm` giờ VN.
String isoTime(DateTime value) {
  final d = _vn(value);
  return '${_two(d.hour)}:${_two(d.minute)}';
}

String newIntentKey() => const Uuid().v4();
