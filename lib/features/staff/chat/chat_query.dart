import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/session/session_controller.dart';
import '../shared/connectivity.dart';
import '../shared/remote.dart';
import 'chat_models.dart';
import 'chat_service.dart';
import 'chat_realtime.dart';

final chatRevisionProvider = NotifierProvider<ChatRevision, int>(
  ChatRevision.new,
);

class ChatRevision extends Notifier<int> {
  @override
  int build() {
    ref.watch(sessionEpochProvider);
    return 0;
  }

  void bump() => state++;
}

final staffChatUnreadProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(sessionEpochProvider);
  ref.watch(chatRevisionProvider);
  ref.watch(staffOfflineProvider);
  ref.listen(chatSignalsProvider, (_, next) {
    if (next.value?.kind == 'notifications') ref.invalidateSelf();
  });
  final life = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(life.dispose);
  return ref.watch(staffChatServiceProvider).unreadCount();
});
typedef ChatListRequest = ({bool notifications, String type});

class ChatListState {
  const ChatListState({
    this.conversations = const [],
    this.notifications = const [],
    this.next,
    this.busy = true,
    this.loaded = false,
    this.error,
    this.footerError = false,
  });
  final List<ChatConversation> conversations;
  final List<ChatNotification> notifications;
  final String? next;
  final bool busy, loaded, footerError;
  final ChatFailure? error;
}

final chatListProvider = NotifierProvider.autoDispose
    .family<ChatListQuery, ChatListState, ChatListRequest>(ChatListQuery.new);

class ChatListQuery extends Notifier<ChatListState> {
  ChatListQuery(this.request);
  final ChatListRequest request;
  int _seq = 0;
  @override
  ChatListState build() {
    ref.watch(sessionEpochProvider);
    ref.watch(chatRevisionProvider);
    ref.listen(staffOfflineProvider, (prev, next) {
      if (prev == true && !next) unawaited(refresh());
    });
    ref.listen(chatSignalsProvider, (_, event) {
      final kind = event.value?.kind;
      if (request.notifications
          ? kind == 'notifications'
          : kind != null && kind != 'membership') {
        unawaited(refresh());
      }
    });
    final life = AppLifecycleListener(onResume: () => unawaited(refresh()));
    ref.onDispose(() {
      _seq++;
      life.dispose();
    });
    Future.microtask(refresh);
    return const ChatListState();
  }

  Future<void> refresh() => load();
  Future<void> more() => !ref.mounted || state.busy || state.next == null
      ? Future.value()
      : load(cursor: state.next);
  Future<void> load({String? cursor}) async {
    if (!ref.mounted) return;
    final seq = ++_seq, old = state;
    state = ChatListState(
      conversations: old.conversations,
      notifications: old.notifications,
      next: old.next,
      loaded: old.loaded,
    );
    try {
      if (ref.read(staffOfflineProvider)) throw const ChatFailure('offline');
      final service = ref.read(staffChatServiceProvider);
      if (request.notifications) {
        final p = await service.notifications(cursor: cursor);
        if (!ref.mounted || seq != _seq) return;
        state = ChatListState(
          notifications: cursor == null
              ? p.items
              : mergeById(old.notifications, p.items, (n) => n.id),
          next: p.next,
          busy: false,
          loaded: true,
        );
      } else {
        final p = await service.conversations(request.type, cursor: cursor);
        if (!ref.mounted || seq != _seq) return;
        state = ChatListState(
          conversations: cursor == null
              ? p.items
              : mergeById(old.conversations, p.items, (c) => c.id),
          next: p.next,
          busy: false,
          loaded: true,
        );
      }
    } catch (e) {
      if (!ref.mounted || seq != _seq) return;
      final error = ChatFailure.from(e),
          fatal = ['denied', 'notFound'].contains(error.kind);
      state = ChatListState(
        conversations: fatal ? const [] : old.conversations,
        notifications: fatal ? const [] : old.notifications,
        next: fatal ? null : old.next,
        loaded: !fatal && old.loaded,
        busy: false,
        error: error,
        footerError: cursor != null,
      );
    }
  }
}

class ChatRoomState {
  const ChatRoomState({
    this.conversation,
    this.messages = const [],
    this.pending = const [],
    this.cursor,
    this.busy = true,
    this.loaded = false,
    this.loadingOlder = false,
    this.error,
    this.olderError,
    this.opening,
  });
  final ChatConversation? conversation;
  final List<ChatMessage> messages;
  final List<PendingChatMessage> pending;
  final String? cursor;
  final bool busy, loaded, loadingOlder;
  final ChatFailure? error, olderError;
  final ({String lastRead, String watermark})? opening;
  ChatRoomState copy({
    ChatConversation? conversation,
    List<ChatMessage>? messages,
    List<PendingChatMessage>? pending,
    String? cursor,
    bool clearCursor = false,
    bool? busy,
    bool? loaded,
    bool? loadingOlder,
    ChatFailure? error,
    bool clearError = false,
    ChatFailure? olderError,
    bool clearOlderError = false,
    ({String lastRead, String watermark})? opening,
  }) => ChatRoomState(
    conversation: conversation ?? this.conversation,
    messages: messages ?? this.messages,
    pending: pending ?? this.pending,
    cursor: clearCursor ? null : cursor ?? this.cursor,
    busy: busy ?? this.busy,
    loaded: loaded ?? this.loaded,
    loadingOlder: loadingOlder ?? this.loadingOlder,
    error: clearError ? null : error ?? this.error,
    olderError: clearOlderError ? null : olderError ?? this.olderError,
    opening: opening ?? this.opening,
  );
}

final chatRoomProvider = NotifierProvider.autoDispose
    .family<ChatRoomQuery, ChatRoomState, String>(ChatRoomQuery.new);

class ChatRoomQuery extends Notifier<ChatRoomState> {
  ChatRoomQuery(this.id);
  final String id;
  String? _checkpoint;
  String _marked = '0';
  int _seq = 0;
  bool _visible = false;
  Timer? _markTimer;
  final _sending = <String>{};
  @override
  ChatRoomState build() {
    ref.watch(sessionEpochProvider);
    final hub = ref.watch(chatRealtimeProvider);
    hub.join(id);
    ref.listen(chatSignalsProvider, (_, event) {
      final signal = event.value;
      if (signal == null) return;
      if (signal.kind == 'message' && signal.message?.conversationId == id) {
        merge([signal.message!]);
      } else if (signal.kind == 'connection' && signal.connected == true ||
          signal.conversationId == id &&
              ['membership', 'revoked'].contains(signal.kind)) {
        unawaited(refresh());
      }
    });
    ref.listen(staffOfflineProvider, (prev, next) {
      if (prev == true && !next) unawaited(refresh());
    });
    final timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (ref.mounted &&
          !hub.connected &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused) {
        unawaited(refresh());
      }
    });
    final life = AppLifecycleListener(onResume: () => unawaited(refresh()));
    ref.onDispose(() {
      _seq++;
      timer.cancel();
      _markTimer?.cancel();
      life.dispose();
      hub.leave(id);
    });
    Future.microtask(refresh);
    return const ChatRoomState();
  }

  void merge(List<ChatMessage> incoming) {
    if (!ref.mounted) return;
    final clients = incoming.map((m) => m.clientId).toSet();
    state = state.copy(
      messages: upsertChatMessages(state.messages, incoming),
      pending: state.pending
          .where((p) => !clients.contains(p.clientId))
          .toList(),
    );
    _mark();
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    final seq = ++_seq;
    state = state.copy(busy: true, clearError: true);
    final service = ref.read(staffChatServiceProvider);
    try {
      if (ref.read(staffOfflineProvider)) throw const ChatFailure('offline');
      final header = await service.conversation(id);
      if (!ref.mounted || seq != _seq) return;
      state = state.copy(
        conversation: header,
        opening:
            state.opening ??
            (lastRead: header.lastRead, watermark: header.watermark),
      );
      if (_checkpoint == null) {
        await _snapshot(service, false, seq);
      } else {
        try {
          final data = await service.catchUp(id, _checkpoint!);
          if (!ref.mounted || seq != _seq) return;
          merge(data.messages);
          if (data.through != null) {
            _checkpoint = maxChatSequence(_checkpoint!, data.through!);
          }
        } on ChatFailure catch (e) {
          if (e.kind == 'gone') {
            await _snapshot(service, true, seq);
          } else {
            rethrow;
          }
        }
      }
      if (!ref.mounted || seq != _seq) return;
      state = state.copy(busy: false, loaded: true, clearError: true);
      _mark();
    } catch (e) {
      if (!ref.mounted || seq != _seq) return;
      final error = ChatFailure.from(e);
      if (['denied', 'notFound'].contains(error.kind)) {
        state = ChatRoomState(busy: false, error: error);
      } else {
        state = state.copy(busy: false, error: error);
      }
    }
  }

  Future<void> _snapshot(
    StaffChatService service,
    bool restart,
    int seq,
  ) async {
    final p = await service.history(id);
    if (!ref.mounted || seq != _seq) return;
    state = state.copy(
      messages: upsertChatMessages(restart ? [] : state.messages, p.items),
      cursor: p.next,
      clearCursor: p.next == null,
    );
    _checkpoint = p.watermark ?? '0';
  }

  Future<void> older() async {
    if (state.cursor == null || state.loadingOlder) return;
    final cursor = state.cursor;
    state = state.copy(loadingOlder: true, clearOlderError: true);
    try {
      final p = await ref
          .read(staffChatServiceProvider)
          .history(id, cursor: cursor);
      if (!ref.mounted) return;
      merge(p.items);
      state = state.copy(
        cursor: p.next,
        clearCursor: p.next == null,
        loadingOlder: false,
      );
    } catch (e) {
      if (ref.mounted) {
        state = state.copy(
          loadingOlder: false,
          olderError: ChatFailure.from(e),
        );
      }
    }
  }

  void visible(bool value) {
    _visible = value;
    if (value) _mark();
  }

  void _mark() {
    if (!_visible || !ref.mounted || !state.loaded || state.messages.isEmpty) {
      return;
    }
    final newest = state.messages.last.sequence;
    if (compareChatSequence(newest, _marked) <= 0) return;
    _markTimer?.cancel();
    _markTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!ref.mounted ||
          !_visible ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
        return;
      }
      _marked = newest;
      try {
        await ref.read(staffChatServiceProvider).markRead(id, newest);
        if (ref.mounted) ref.read(chatRevisionProvider.notifier).bump();
      } catch (_) {
        _marked = '0';
      }
    });
  }

  void send(String body) {
    if (state.conversation?.canSend != true || chatMessageProblem(body) != null) {
      return;
    }
    final pending = PendingChatMessage(
      clientId: const Uuid().v4(),
      body: body.trim(),
    );
    state = state.copy(pending: [...state.pending, pending]);
    unawaited(resend(pending));
  }

  Future<void> resend(PendingChatMessage pending) async {
    if (!_sending.add(pending.clientId)) return;
    state = state.copy(
      pending: [
        for (final p in state.pending)
          p.clientId == pending.clientId
              ? PendingChatMessage(clientId: p.clientId, body: p.body)
              : p,
      ],
    );
    try {
      final message = await ref
          .read(staffChatServiceProvider)
          .send(id, pending.clientId, pending.body);
      if (ref.mounted) merge([message]);
    } catch (e) {
      if (ref.mounted) {
        state = state.copy(
          pending: [
            for (final p in state.pending)
              p.clientId == pending.clientId
                  ? PendingChatMessage(
                      clientId: p.clientId,
                      body: p.body,
                      failure: ChatFailure.from(e, write: true).kind,
                    )
                  : p,
          ],
        );
      }
    } finally {
      _sending.remove(pending.clientId);
    }
  }
}
