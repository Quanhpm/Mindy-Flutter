import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/json.dart';
import '../../../core/session/session_controller.dart';
import '../shared/remote.dart';
import 'chat_models.dart';

class ChatFailure implements Exception {
  const ChatFailure(this.kind, {this.code = '', this.requestId});
  final String kind, code;
  final String? requestId;
  static ChatFailure from(Object e, {bool write = false}) {
    if (e is ChatFailure) return e;
    if (e is ApiError) {
      return ChatFailure(
        e.code == 'SESSION_CHANGED' || e.status == 401 || e.status == 403
            ? 'denied'
            : e.status == 404
            ? 'notFound'
            : e.status == 410
            ? 'gone'
            : e.status == 429
            ? 'rateLimited'
            : write && (e.isNetwork || e.status >= 500)
            ? 'uncertain'
            : e.isNetwork
            ? 'offline'
            : 'error',
        code: e.code,
        requestId: e.requestId,
      );
    }
    return ChatFailure(write ? 'uncertain' : 'error');
  }
}

final staffChatServiceProvider = Provider((ref) {
  final epoch = ref.watch(sessionEpochProvider);
  return StaffChatService(
    ref.watch(apiClientProvider),
    () =>
        ref.mounted &&
        ref.read(sessionEpochProvider) == epoch &&
        ref.read(sessionProvider).user?.role.name == 'MENTOR',
  );
});

class StaffChatService {
  StaffChatService(this.api, this.active);
  final ApiClient api;
  final bool Function() active;
  String root(String id) => 'chat/conversations/${resourceId(id)}';
  Future<T> request<T>(
    Future<Object?> Function() call,
    T Function(Json) parse, {
    bool write = false,
  }) async {
    if (!active()) throw const ChatFailure('denied');
    try {
      final body = await call();
      if (!active()) throw const ChatFailure('denied');
      return parse(Json(body, 'INVALID_CHAT_RESPONSE'));
    } catch (e) {
      throw ChatFailure.from(e, write: write);
    }
  }

  ChatPage<T> page<T>(Json j, T Function(Json) parse) {
    final meta = j.obj('meta');
    return ChatPage(
      items: j.list('data', parse),
      next: meta.boolean('hasMore') ? meta.strOrNull('nextCursor') : null,
      watermark: meta.has('highWatermark')
          ? chatSequence(meta, 'highWatermark')
          : null,
      through: meta.has('throughSequence')
          ? chatSequence(meta, 'throughSequence')
          : null,
    );
  }

  Future<ChatPage<ChatConversation>> conversations(
    String type, {
    String? cursor,
  }) => request(
    () => api.get(
      'chat/conversations',
      query: {
        'limit': 20,
        if (type.isNotEmpty) 'type': type,
        'cursor': ?cursor,
      },
    ),
    (j) => page(j, ChatConversation.new),
  );
  Future<ChatConversation> conversation(String id) =>
      request(() => api.get(root(id)), (j) {
        final c = ChatConversation(j);
        if (c.id != id) j.fail();
        return c;
      });
  Future<ChatConversation> direct(String peerId) => request(
    () => api.post(
      'chat/conversations/direct',
      body: {'peerUserId': resourceId(peerId)},
    ),
    (j) {
      j.boolean('created');
      return ChatConversation(j.obj('conversation'));
    },
    write: true,
  );
  Future<ChatPage<ChatMessage>> history(String id, {String? cursor}) => request(
    () => api.get(
      '${root(id)}/messages',
      query: {'limit': 50, 'cursor': ?cursor},
    ),
    (j) {
      final p = page(j, ChatMessage.new);
      if (p.items.any((m) => m.conversationId != id)) j.fail();
      return p;
    },
  );
  Future<({List<ChatMessage> messages, String? through})> catchUp(
    String id,
    String after,
  ) async {
    final messages = <ChatMessage>[];
    String? cursor;
    final seen = <String>{};
    while (true) {
      final result = await request(
        () => api.get(
          '${root(id)}/events',
          query: {
            'limit': 100,
            if (cursor == null) 'afterSequence': after else 'cursor': cursor,
          },
        ),
        (j) => page(j, (e) {
          e.uuid('eventId');
          chatSequence(e, 'sequence');
          e.str('type');
          final message = e.objOrNull('message');
          return message == null ? null : ChatMessage(message);
        }),
      );
      for (final message in result.items) {
        if (message != null) {
          if (message.conversationId != id) throw const ChatFailure('error');
          messages.add(message);
        }
      }
      if (result.next == null) {
        return (messages: messages, through: result.through);
      }
      if (!seen.add(result.next!)) throw const ChatFailure('error');
      cursor = result.next;
    }
  }

  Future<ChatMessage> send(String id, String clientId, String body) {
    if (chatMessageProblem(body) != null) {
      throw const ChatFailure('invalid', code: 'INVALID_BODY');
    }
    return request(
      () => api.post(
        '${root(id)}/messages',
        body: {
          'clientMessageId': resourceId(clientId),
          'type': 'TEXT',
          'body': body,
        },
      ),
      (j) {
        j.boolean('replayed');
        final m = ChatMessage(j.obj('message'));
        if (m.conversationId != id || m.clientId != clientId) j.fail();
        return m;
      },
      write: true,
    );
  }

  Future<void> markRead(String id, String sequence) async {
    if (!active()) return;
    try {
      await api.put('${root(id)}/read', body: {'throughSequence': sequence});
    } catch (e) {
      throw ChatFailure.from(e, write: true);
    }
  }

  Future<Uri> fileUrl(String id, String messageId) => request(
    () => api.post('${root(id)}/messages/${resourceId(messageId)}/file-access'),
    (j) {
      final uri = Uri.tryParse(j.str('url'));
      if (uri == null ||
          !['https', 'http'].contains(uri.scheme) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        j.fail();
      }
      return uri;
    },
  );
  Future<ChatPage<ChatNotification>> notifications({String? cursor}) => request(
    () => api.get('notifications', query: {'limit': 20, 'cursor': ?cursor}),
    (j) => page(j, ChatNotification.new),
  );
  Future<int> unreadCount() =>
      request(() => api.get('notifications/unread-count'), (j) {
        final n = j.integer('unreadCount');
        if (n < 0) j.fail();
        return n;
      });
  Future<void> readNotification(String id) async {
    if (active()) await api.patch('notifications/${resourceId(id)}/read');
  }

  Future<void> readAll() async {
    if (active()) await api.post('notifications/read-all');
  }

  Future<bool> renew() async {
    try {
      await api.get('auth/me');
      return active();
    } catch (_) {
      return false;
    }
  }
}
