import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/network/json.dart';
import '../../core/session/session_controller.dart';
import 'mentor_utilities.dart';

/// Refresh/lỗi không dùng lại quyền lớp từ snapshot cũ.
bool canShowPrimaryUtilities(AsyncValue<bool> scope) => !scope.isLoading && !scope.hasError && scope.value == false;

/// true = mentor chỉ được giao dạy thay (không có lớp chính) -> ẩn tiện ích `primaryOnly`.
/// Chỉ đếm lớp chính: backend mặc định assignment=ANY, gồm cả lớp dạy thay.
/// Chưa đọc được assignment thì UI chỉ hiện tiện ích dùng chung và cho thử lại.
final mentorSubstituteOnlyProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final res = await ref
      .watch(apiClientProvider)
      .get('mentor/classes', query: {'assignment': 'PRIMARY', 'page': 1, 'pageSize': 1}, cancel: cancel);
  final json = Json(res);
  final total = json.integer('total');
  if (total < 0) json.fail();
  return total == 0;
});

/// Tiện ích yêu thích người dùng tự thêm (ngoài 3 cố định). Lưu cục bộ theo user, không có API.
final mentorFavoritesProvider = AsyncNotifierProvider<MentorFavoritesController, List<MentorUtil>>(
  MentorFavoritesController.new,
);

class MentorFavoritesController extends AsyncNotifier<List<MentorUtil>> {
  String get _key => 'mentor_favs_${ref.read(sessionProvider).user?.id ?? 'guest'}';

  @override
  Future<List<MentorUtil>> build() async {
    ref.watch(sessionEpochProvider);
    final key = _key;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(key) ?? const [];
    return [for (final n in saved) ?MentorUtil.byName(n)];
  }

  /// Trả key thông báo lỗi (tối đa 6 / tiện ích chính) hoặc null nếu đã đổi.
  Future<String?> toggle(MentorUtil u) async {
    final (next, error) = toggleFavorite(state.value ?? const [], u);
    if (error != null) return error;
    // Chụp user trước await: đổi tài khoản không được chuyển lượt ghi sang key mới.
    final key = _key;
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, [for (final x in next) x.name]);
    return null;
  }
}
