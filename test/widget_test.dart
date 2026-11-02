import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/i18n/i18n.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/json.dart';
import 'package:mindy_flutter/core/utils/format.dart';
import 'package:mindy_flutter/features/payment/payment_models.dart';

/// Test logic thuần (không cần backend). Thêm test theo từng feature khi port.
void main() {
  group('Json (thay Zod)', () {
    test('đọc field đúng kiểu', () {
      final j = Json({'id': '3f2b6d0e-1c2a-4b5c-8d9e-0a1b2c3d4e5f', 'n': 3, 'd': '2026-11-02'});
      expect(j.uuid('id'), '3f2b6d0e-1c2a-4b5c-8d9e-0a1b2c3d4e5f');
      expect(j.integer('n'), 3);
      expect(j.day('d'), '2026-11-02');
    });

    test('sai kiểu -> ApiError 502', () {
      expect(() => Json({'n': '3'}).integer('n'), throwsA(isA<ApiError>()));
      // timestamp thiếu offset bị từ chối
      expect(() => Json({'t': '2026-11-02T10:00:00'}).dateTime('t'), throwsA(isA<ApiError>()));
    });

    test('Mảng UUID kiểm tra kiểu, nội dung và ID trùng', () {
      const id = '3f2b6d0e-1c2a-4b5c-8d9e-0a1b2c3d4e5f';
      expect(
        Json({
          'ids': [id],
        }).uuidList('ids'),
        [id],
      );
      for (final ids in <Object?>[
        [id, id],
        [123],
        ['invalid'],
        'invalid',
      ]) {
        expect(() => Json({'ids': ids}).uuidList('ids'), throwsA(isA<ApiError>()));
      }
    });
  });

  group('Dates', () {
    test('tuần bắt đầu thứ Hai', () {
      final days = Dates.weekDays('2026-11-04'); // thứ Tư
      expect(days.first, '2026-11-02');
      expect(days.last, '2026-11-08');
    });

    test('format', () {
      expect(Dates.displayDay('2026-11-02'), '02/11/2026');
      expect(Dates.dateOnly('2026-11-02'), '02/11');
    });
  });

  test('formatVnd', () {
    expect(formatVnd(1500000), '1.500.000 VND');
  });

  test('Translator nội suy {{x}}', () {
    final t = Translator({
      'common': {'requestId': 'Mã hỗ trợ: {{id}}'},
    }, const Locale('vi'));
    expect(t('common.requestId', {'id': 'abc'}), 'Mã hỗ trợ: abc');
    expect(t('missing.key'), 'missing.key');
  });

  test('Order.result chỉ PAID/CANCELLED/EXPIRED', () {
    Order order(String status, [String? payment]) => Order.fromJson(
      Json({
        'id': '3f2b6d0e-1c2a-4b5c-8d9e-0a1b2c3d4e5f',
        'orderCode': 'MD001',
        'paymentType': 'PAYOS',
        'status': status,
        'totalAmount': 1000,
        'expiresAt': '2026-11-02T10:00:00+07:00',
        'details': <Object>[],
        'payment': payment == null ? null : {'status': payment, 'qrCode': null, 'expiresAt': null, 'amount': 1000},
      }),
    );
    expect(order('PAID').result, OrderStatus.PAID);
    expect(order('PENDING').result, isNull);
    expect(order('PENDING', 'REQUIRES_REVIEW').result, isNull);
    expect(order('EXPIRED').result, OrderStatus.EXPIRED);
  });
}
