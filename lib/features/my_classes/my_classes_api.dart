import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_error.dart';
import '../../core/network/json.dart';
import '../payment/payment_api.dart';
import '../payment/payment_models.dart';
import 'my_classes_models.dart';

final myClassesApiProvider =
    Provider((ref) => MyClassesApi(ref.watch(apiClientProvider), ref.watch(paymentApiProvider)));

/// view: current | history | all
typedef ClassesView = String;

/// `my-classes/services/learning.service.ts` + `resumeOrder.service.ts`
class MyClassesApi {
  MyClassesApi(this._api, this._payment);
  final ApiClient _api;
  final PaymentApi _payment;

  static final _uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);

  ApiError _denied() => ApiError(status: 403, code: 'CLASS_ACCESS_DENIED', message: 'Class access denied');

  /// 1 trang `me/classes` (100 dòng/trang)
  Future<({Paged<Enrollment> page, DateTime asOf})> classesPage(ClassesView view, int page) async {
    final j = Json(await _api.get('me/classes', query: {'view': view, 'page': page, 'pageSize': 100}), learningError);
    final p = Paged.fromJson(j, Enrollment.fromJson);
    p.check(page, p.items.length, learningError);
    return (page: p, asOf: j.dateTime('asOf'));
  }

  /// Đọc HẾT các trang. Lỗi trang sau không bị coi là danh sách rỗng.
  Future<({List<Enrollment> items, DateTime asOf})> allClasses([ClassesView view = 'all']) async {
    final items = <String, Enrollment>{};
    var page = 1, count = 0;
    while (true) {
      final r = await classesPage(view, page);
      count += r.page.items.length;
      r.page.check(page, count, learningError);
      for (final e in r.page.items) {
        items[e.enrollmentId] = e;
      }
      if (count >= r.page.total) return (items: items.values.toList(), asOf: r.asOf);
      page++;
    }
  }

  Enrollment? _currentAccess(List<Enrollment> rows, String classId) {
    final candidates =
        rows.where((r) => r.classId == classId && r.classStatus != ClassStatus.CANCELLED && !r.isHoldExpired);
    for (final r in candidates) {
      if (r.enrollmentStatus == EnrollmentStatus.ACTIVE && r.action == EnrollmentAction.FULL) return r;
    }
    for (final r in candidates) {
      if (r.enrollmentStatus == EnrollmentStatus.PENDING_PAYMENT && r.action == EnrollmentAction.CASH_PREVIEW) {
        return r;
      }
    }
    return null;
  }

  Future<ClassDetail> _readDetail(Enrollment row) async {
    final preview = row.accessMode == AccessMode.CASH_PREVIEW;
    final res = await _api.get('me/classes/${row.classId}${preview ? '/preview' : ''}');
    final d = ClassDetail.fromJson(Json(res, learningError), preview: preview);
    if (d.id != row.classId || d.classStatus == ClassStatus.CANCELLED) throw _denied();
    return d;
  }

  /// Chi tiết lớp sau khi đã xác minh quyền từ danh sách enrollment.
  /// Gặp 403 thì tải lại quyền ĐÚNG MỘT lần; quyền không đổi thì báo lỗi luôn.
  Future<({ClassDetail detail, Enrollment enrollment})> verifiedDetail(String classId) async {
    if (!_uuid.hasMatch(classId)) {
      throw ApiError(status: 404, code: 'CLASS_NOT_FOUND', message: 'Class not found');
    }
    final first = _currentAccess((await allClasses()).items, classId);
    if (first == null) throw _denied();
    try {
      return (detail: await _readDetail(first), enrollment: first);
    } on ApiError catch (e) {
      if (e.status != 403 || !['CLASS_ACCESS_DENIED', 'CLASS_PREVIEW_DENIED'].contains(e.code)) rethrow;
      final next = _currentAccess((await allClasses()).items, classId);
      if (next == null || next.accessMode == first.accessMode) rethrow;
      return (detail: await _readDetail(next), enrollment: next);
    }
  }

  /// "Tiếp tục thanh toán" từ Lớp của tôi: chỉ khi MỌI dòng của đơn đều ở trạng thái PAYMENT.
  Future<Order> verifiedResumeOrder(String orderId) async {
    ApiError invalid() => ApiError(status: 409, code: 'PAYMENT_ORDER_INVALID', message: 'Order cannot be resumed');
    final rows = await allClasses();
    final candidates = rows.items.where((r) => r.order?.orderId == orderId).toList();
    if (candidates.isEmpty || candidates.any((r) => r.action != EnrollmentAction.PAYMENT)) throw invalid();
    final order = await _payment.order(orderId);
    if (order.status != OrderStatus.PENDING ||
        order.paymentType != PaymentType.PAYOS ||
        order.payment?.status == PaymentStatus.REQUIRES_REVIEW ||
        order.payment?.status == PaymentStatus.SUCCEEDED ||
        !order.expiresAt.isAfter(rows.asOf)) {
      throw invalid();
    }
    return order;
  }
}
