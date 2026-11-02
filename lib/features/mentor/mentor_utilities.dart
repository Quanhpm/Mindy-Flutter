import 'package:flutter/widgets.dart';

import '../../core/ui/staff/sym.dart';

/// Tiện ích của Mentor - bảng `UTILS` trong `Mentor Mobile UI.html`.
/// Đã BỎ "Mở chương" (backend gỡ API release unit 22/10, owner chốt 02/11).
///
/// [primaryOnly]: cần là mentor chính của lớp (`/mentor/classes`); mentor chỉ dạy thay không thấy.
/// [phase]: giai đoạn trong MENTOR_PLAN.md sẽ làm màn này.
enum MentorUtil {
  schedule(Sym.calendarMonth, 'mentor.util.schedule', phase: 'MF2'),
  classes(Sym.coPresent, 'mentor.util.classes', primaryOnly: true, phase: 'MF4'),
  attendance(Sym.factCheck, 'mentor.util.attendance', primaryOnly: true, phase: 'MF4'),
  room(Sym.videocam, 'mentor.util.room', sessionOnly: true, phase: 'MF2'),
  students(Sym.groups, 'mentor.util.students', primaryOnly: true, phase: 'MF4'),
  materials(Sym.folderOpen, 'mentor.util.materials', primaryOnly: true, phase: 'MF5'),
  upload(Sym.uploadFile, 'mentor.util.upload', primaryOnly: true, isNew: true, phase: 'MF5'),
  substitute(Sym.swapHoriz, 'mentor.util.substitute', isNew: true, phase: 'MF2'),
  sync(Sym.sync, 'mentor.util.sync', isNew: true, sessionOnly: true, phase: 'MF3');

  const MentorUtil(
    this.icon,
    this.labelKey, {
    this.primaryOnly = false,
    this.isNew = false,
    this.sessionOnly = false,
    required this.phase,
  });

  final IconData icon;
  final String labelKey;
  final bool primaryOnly;
  final bool isNew;

  /// Cần một buổi đang dạy (mở dạng sheet từ Lịch dạy), không có trang riêng.
  final bool sessionOnly;
  final String phase;

  static MentorUtil? byName(String name) {
    for (final u in values) {
      if (u.name == name) return u;
    }
    return null;
  }
}

/// 3 tiện ích chính luôn nằm đầu Yêu thích, không bỏ được.
const fixedFavorites = [MentorUtil.classes, MentorUtil.schedule, MentorUtil.materials];
const maxFavorites = 6;

/// Nhóm trên Home / trang Tất cả tiện ích.
const utilityGroups = <(String, List<MentorUtil>)>[
  (
    'mentor.home.recent',
    [
      MentorUtil.classes,
      MentorUtil.schedule,
      MentorUtil.materials,
      MentorUtil.attendance,
      MentorUtil.students,
      MentorUtil.upload,
    ],
  ),
  ('mentor.home.new', [MentorUtil.substitute, MentorUtil.sync]),
];

/// Tiện ích được thấy theo loại mentor.
bool isUtilVisible(MentorUtil u, {required bool substituteOnly}) => !(substituteOnly && u.primaryOnly);

/// Danh sách yêu thích hiển thị: 3 cố định trước, rồi phần người dùng chọn; lọc theo quyền.
List<MentorUtil> displayFavorites(List<MentorUtil> chosen, {required bool substituteOnly}) => [
  ...fixedFavorites,
  ...chosen.where((u) => !fixedFavorites.contains(u)),
].where((u) => isUtilVisible(u, substituteOnly: substituteOnly)).toList();

/// Bật/tắt yêu thích. Trả về (danh sách mới, key thông báo lỗi nếu không đổi được).
(List<MentorUtil>, String?) toggleFavorite(List<MentorUtil> chosen, MentorUtil u) {
  if (fixedFavorites.contains(u)) return (chosen, 'mentor.home.fixed');
  if (chosen.contains(u)) return ([...chosen]..remove(u), null);
  final total = fixedFavorites.length + chosen.where((x) => !fixedFavorites.contains(x)).length;
  if (total >= maxFavorites) return (chosen, 'mentor.home.maxFav');
  return ([...chosen, u], null);
}
