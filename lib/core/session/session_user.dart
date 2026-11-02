// ignore_for_file: constant_identifier_names
import '../network/json.dart';

/// Giữ tên enum đúng như backend để parse bằng `Json.enumOf`.
enum Role { STUDENT, MENTOR, MANAGER, ADMIN }

/// DTO `auth/me` - `src/modules/auth/schemas/authResponse.schema.ts`.
class SessionUser {
  SessionUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.phone,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;
  final String? phone;
  final Role role;
  final DateTime createdAt;

  bool get isStudent => role == Role.STUDENT;

  factory SessionUser.fromJson(Json j) {
    if (j.str('status') != 'ACTIVE') j.fail();
    final name = j.nonEmpty('displayName');
    if (name.length > 150) j.fail();
    return SessionUser(
      id: j.uuid('id'),
      email: j.nonEmpty('email'),
      displayName: name,
      phone: j.strOrNull('phone'),
      role: j.enumOf('role', Role.values),
      createdAt: j.dateTime('createdAt'),
    );
  }
}
