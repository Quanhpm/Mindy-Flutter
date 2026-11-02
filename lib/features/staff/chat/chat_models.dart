import '../../../core/network/json.dart';

String chatSequence(Json j, String key) {
  final s = j.str(key);
  if (!RegExp(r'^(0|[1-9]\d{0,18})$').hasMatch(s)) j.fail();
  return s;
}

int compareChatSequence(String a, String b) =>
    a.length != b.length ? a.length.compareTo(b.length) : a.compareTo(b);
String maxChatSequence(String a, String b) =>
    compareChatSequence(a, b) >= 0 ? a : b;

class ChatMessage {
  ChatMessage(Json j)
    : id = j.uuid('id'),
      conversationId = j.uuid('conversationId'),
      senderId = j.obj('sender').uuid('id'),
      senderName = j.obj('sender').str('displayName'),
      clientId = j.uuidOrNull('clientMessageId'),
      sequence = chatSequence(j, 'sequence'),
      changedSequence = chatSequence(j, 'lastChangedSequence'),
      type = j.str('type'),
      body = j.strOrNull('body'),
      version = j.integer('version'),
      createdAt = j.dateTime('createdAt'),
      editedAt = j.dateTimeOrNull('editedAt'),
      deletedAt = j.dateTimeOrNull('deletedAt'),
      fileId = j.objOrNull('file')?.uuid('id'),
      fileName = j.objOrNull('file')?.str('originalFilename'),
      replyId = j.objOrNull('replyTo')?.uuid('id'),
      replySender = j.objOrNull('replyTo')?.str('senderDisplayName'),
      replyDeleted = j.objOrNull('replyTo')?.boolean('deleted') ?? false {
    if (!['TEXT', 'FILE', 'IMAGE'].contains(type) || version < 1) j.fail();
    final file = j.objOrNull('file');
    if (file != null) {
      file.str('mimeType');
      if (file.integer('sizeBytes') < 0 ||
          !['IMAGE', 'PDF'].contains(file.str('kind'))) {
        j.fail();
      }
    }
  }
  final String id,
      conversationId,
      senderId,
      senderName,
      sequence,
      changedSequence,
      type;
  final String? clientId, body, fileId, fileName, replyId, replySender;
  final int version;
  final bool replyDeleted;
  final DateTime createdAt;
  final DateTime? editedAt, deletedAt;
}

class ChatConversation {
  ChatConversation(Json j)
    : id = j.uuid('id'),
      type = j.str('type'),
      classId = j.uuidOrNull('classId'),
      name = j.strOrNull('name'),
      peerId = j.objOrNull('peer')?.uuid('id'),
      peerName = j.objOrNull('peer')?.str('displayName'),
      canSend = j.obj('capabilities').boolean('canSend'),
      access = j.str('accessMode'),
      lastRead = chatSequence(j, 'lastReadSequence'),
      watermark = chatSequence(j, 'highWatermark'),
      unread = j.integer('unreadCount'),
      lastMessage = j.objOrNull('lastMessage') == null
          ? null
          : ChatMessage(j.obj('lastMessage')),
      activityAt = j.dateTime('activityAt') {
    if (!j.obj('capabilities').boolean('canRead') ||
        !['GROUP', 'DIRECT'].contains(type) ||
        !['ACTIVE', 'CASH_PENDING', 'HISTORY_READ_ONLY'].contains(access) ||
        unread < 0) {
      j.fail();
    }
  }
  final String id, type, access, lastRead, watermark;
  final String? classId, name, peerId, peerName;
  final bool canSend;
  final int unread;
  final ChatMessage? lastMessage;
  final DateTime activityAt;
  String title(String fallback) =>
      (type == 'GROUP' ? name : peerName) ?? fallback;
}

class ChatNotification {
  ChatNotification(Json j)
    : id = j.uuid('id'),
      conversationId = j.uuid('conversationId'),
      messageId = j.uuid('messageId'),
      actorId = j.uuid('actorId'),
      title = j.str('title'),
      body = j.str('body'),
      readAt = j.dateTimeOrNull('readAt'),
      createdAt = j.dateTime('createdAt') {
    if (j.str('type') != 'CHAT_MESSAGE') j.fail();
  }
  final String id, conversationId, messageId, actorId, title, body;
  final DateTime? readAt;
  final DateTime createdAt;
}

class ChatPage<T> {
  const ChatPage({
    required this.items,
    required this.next,
    this.watermark,
    this.through,
  });
  final List<T> items;
  final String? next, watermark, through;
}

class ChatSignal {
  const ChatSignal(
    this.kind, {
    this.conversationId,
    this.message,
    this.connected,
  });
  final String kind;
  final String? conversationId;
  final ChatMessage? message;
  final bool? connected;
}

class PendingChatMessage {
  const PendingChatMessage({
    required this.clientId,
    required this.body,
    this.failure,
  });
  final String clientId, body;
  final String? failure;
}

List<ChatMessage> upsertChatMessages(
  List<ChatMessage> current,
  List<ChatMessage> incoming,
) {
  final byId = {for (final m in current) m.id: m};
  for (final m in incoming) {
    if (byId[m.id] == null || m.version >= byId[m.id]!.version) byId[m.id] = m;
  }
  return byId.values.toList()
    ..sort((a, b) => compareChatSequence(a.sequence, b.sequence));
}

String? chatMessageProblem(String body) => body.trim().isEmpty
    ? 'empty'
    : body.runes.length > 4000
    ? 'tooLong'
    : null;
