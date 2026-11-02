/// Interfaces RN `modules/contacts/types/contact.type.ts` (không có màn/API riêng).
class StaffContact {
  const StaffContact({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatar,
    this.isOnline,
    this.lastSeen,
    this.status,
  });
  final String id, name;
  final String? email, phone, avatar, status;
  final bool? isOnline;
  final DateTime? lastSeen;
}

class StaffContactGroup {
  const StaffContactGroup({
    required this.id,
    required this.name,
    required this.contacts,
    required this.isPrivate,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id, name;
  final List<StaffContact> contacts;
  final bool isPrivate;
  final DateTime createdAt, updatedAt;
}

class StaffContactSearchResult {
  const StaffContactSearchResult({
    required this.contacts,
    required this.total,
    required this.hasMore,
  });
  final List<StaffContact> contacts;
  final int total;
  final bool hasMore;
}
