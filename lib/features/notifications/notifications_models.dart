import '../../core/network/json.dart';

class MindyNotification {
  const MindyNotification({
    required this.id,
    required this.actorId,
    required this.conversationId,
    required this.messageId,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.readAt,
  });
  final String id, actorId, conversationId, messageId, title, body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory MindyNotification.fromJson(Json j) {
    if (j.str('type') != 'CHAT_MESSAGE') j.fail();
    final conversation = j.uuid('conversationId');
    final message = j.uuid('messageId');
    final data = j.obj('data');
    if (data.uuid('conversationId') != conversation || data.uuid('messageId') != message) j.fail();
    return MindyNotification(
      id: j.uuid('id'),
      actorId: j.uuid('actorId'),
      conversationId: conversation,
      messageId: message,
      title: j.str('title'),
      body: j.str('body'),
      createdAt: j.dateTime('createdAt'),
      readAt: j.dateTimeOrNull('readAt'),
    );
  }
}

class NotificationPage {
  NotificationPage({required List<MindyNotification> items, required this.nextCursor, required this.hasMore})
    : items = List.unmodifiable(items);
  final List<MindyNotification> items;
  final String? nextCursor;
  final bool hasMore;

  factory NotificationPage.fromJson(Json j) {
    final meta = j.obj('meta');
    final more = meta.boolean('hasMore');
    final cursor = meta.strOrNull('nextCursor');
    final items = j.list('data', MindyNotification.fromJson);
    if ((more && (cursor == null || cursor.isEmpty || items.isEmpty)) || (!more && cursor != null)) j.fail();
    if (items.map((e) => e.id).toSet().length != items.length) j.fail();
    return NotificationPage(items: items, nextCursor: cursor, hasMore: more);
  }
}
