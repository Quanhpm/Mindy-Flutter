import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/network/json.dart';
import '../../core/session/session_controller.dart';
import 'mentor_utilities.dart';

/// true = mentor chỉ được giao dạy thay (không có lớp chính) -> ẩn tiện ích `primaryOnly`.
/// Chỉ đếm lớp chính: backend mặc định assignment=ANY, gồm cả lớp dạy thay.
/// Lỗi mạng -> coi như mentor chính (không ẩn gì; server vẫn tự chặn quyền).
final mentorSubstituteOnlyProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(sessionEpochProvider);
  try {
    final res = await ref
        .watch(apiClientProvider)
        .get('mentor/classes', query: {'assignment': 'PRIMARY', 'page': 1, 'pageSize': 1});
    return Json(res).integer('total') == 0;
  } catch (_) {
    return false;
  }
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
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? const [];
    return [for (final n in saved) ?MentorUtil.byName(n)];
  }

  /// Trả key thông báo lỗi (tối đa 6 / tiện ích chính) hoặc null nếu đã đổi.
  Future<String?> toggle(MentorUtil u) async {
    final (next, error) = toggleFavorite(state.value ?? const [], u);
    if (error != null) return error;
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [for (final x in next) x.name]);
    return null;
  }
}
