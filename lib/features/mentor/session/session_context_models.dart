import '../../../core/network/json.dart';
import '../schedule/schedule_models.dart';

class TeachingRoom {
  const TeachingRoom({required this.session, required this.roomName, required this.meetingUrl});
  final TeachingSession session;
  final String? roomName;
  final Uri? meetingUrl;

  factory TeachingRoom.fromJson(Json j, {required String sessionId}) {
    final session = TeachingSession.fromJson(j.obj('session'));
    if (session.id != sessionId || j.str('accessScope') != 'SESSION') j.fail();
    final raw = j.strOrNull('meetingUrl');
    final uri = raw == null ? null : Uri.tryParse(raw);
    if (raw != null &&
        (uri == null || !['http', 'https'].contains(uri.scheme) || uri.host.isEmpty || uri.userInfo.isNotEmpty)) {
      j.fail();
    }
    return TeachingRoom(session: session, roomName: j.strOrNull('roomName'), meetingUrl: uri);
  }
}
