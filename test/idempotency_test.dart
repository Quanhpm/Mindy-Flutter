import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/idempotency.dart';

void main() {
  test('Retry giữ nguyên body dù form/danh sách gốc tiếp tục thay đổi', () {
    final row = <String, Object?>{'enrollmentId': 'sample', 'status': 'PRESENT'};
    final rows = <Object?>[row];
    final input = <String, Object?>{'expectedVersion': 2, 'records': rows};
    final call = IdempotentCall(input);
    final encoded = jsonEncode(call.body);
    input['expectedVersion'] = 99;
    row['status'] = 'ABSENT';
    rows.add({'enrollmentId': 'other', 'status': 'PRESENT'});
    expect(jsonEncode(call.body), encoded);
    expect(() => call.body['expectedVersion'] = 3, throwsUnsupportedError);
    expect(() => (call.body['records']! as List<Object?>).clear(), throwsUnsupportedError);
  });
}
