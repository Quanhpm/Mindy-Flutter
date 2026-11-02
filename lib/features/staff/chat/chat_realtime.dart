import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/config/env.dart';
import '../../../core/network/json.dart';
import '../../../core/session/session_controller.dart';
import 'chat_models.dart';
import 'chat_service.dart';

final chatRealtimeProvider = Provider.autoDispose((ref) {
  ref.watch(sessionEpochProvider);
  final hub = ChatRealtime(ref.watch(staffChatServiceProvider));
  ref.onDispose(hub.dispose);
  return hub;
});
final chatSignalsProvider = StreamProvider.autoDispose<ChatSignal>((ref) {
  final hub = ref.watch(chatRealtimeProvider);
  unawaited(hub.start());
  return hub.stream;
});

class ChatRealtime {
  ChatRealtime(this.service);
  final StaffChatService service;
  final _signals = StreamController<ChatSignal>.broadcast();
  final _joined = <String, int>{};
  io.Socket? _socket;
  bool connected = false, _starting = false, _closed = false, _renewed = false;
  Stream<ChatSignal> get stream => _signals.stream;
  void _emit(ChatSignal signal) {
    if (!_closed) _signals.add(signal);
  }

  Future<void> start() async {
    if (_closed || _starting || _socket != null || !service.active()) return;
    _starting = true;
    try {
      final uri = Uri.parse(Env.apiUrl),
          cookies = await service.api.cookieJar.loadForRequest(uri);
      if (_closed || !service.active()) return;
      final socket = io.io(
        '${uri.origin}/chat',
        io.OptionBuilder()
            .setPath('/socket.io')
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableForceNew()
            .setExtraHeaders({
              'Origin': Env.appOrigin,
              if (cookies.isNotEmpty)
                'Cookie': cookies.map((c) => '${c.name}=${c.value}').join('; '),
            })
            .build(),
      );
      _socket = socket;
      socket.onConnect((_) {
        connected = true;
        _renewed = false;
        for (final id in _joined.keys) {
          socket.emit('conversation:join', {'conversationId': id});
        }
        _emit(const ChatSignal('connection', connected: true));
      });
      socket.onDisconnect((reason) {
        connected = false;
        _emit(const ChatSignal('connection', connected: false));
        if (reason == 'io server disconnect') unawaited(_renew());
      });
      socket.onConnectError((error) {
        if (error is Map &&
            error['data'] is Map &&
            (error['data'] as Map)['statusCode'] == 401) {
          unawaited(_renew());
        }
      });
      for (final name in [
        'message:created',
        'message:updated',
        'message:deleted',
      ]) {
        socket.on(name, (payload) {
          try {
            final j = Json(payload);
            j.uuid('eventId');
            chatSequence(j, 'sequence');
            j.str('type');
            final raw = j.objOrNull('message');
            if (raw != null) {
              final m = ChatMessage(raw);
              _emit(
                ChatSignal(
                  'message',
                  conversationId: m.conversationId,
                  message: m,
                ),
              );
            }
          } catch (_) {}
        });
      }
      for (final event in [
        ('conversation:membership-changed', 'membership'),
        ('conversation:access-changed', 'revoked'),
      ]) {
        socket.on(event.$1, (payload) {
          try {
            _emit(
              ChatSignal(
                event.$2,
                conversationId: Json(payload).uuid('conversationId'),
              ),
            );
          } catch (_) {}
        });
      }
      for (final event in ['notification:created', 'notifications:read']) {
        socket.on(event, (_) => _emit(const ChatSignal('notifications')));
      }
      socket.connect();
    } finally {
      _starting = false;
    }
  }

  Future<void> _renew() async {
    if (_closed || _renewed) return;
    _renewed = true;
    if (await service.renew() && !_closed) {
      _socket?.dispose();
      _socket = null;
      await start();
    }
  }

  void join(String id) {
    _joined[id] = (_joined[id] ?? 0) + 1;
    _socket?.emit('conversation:join', {'conversationId': id});
  }

  void leave(String id) {
    final n = (_joined[id] ?? 1) - 1;
    if (n > 0) {
      _joined[id] = n;
    } else {
      _joined.remove(id);
      _socket?.emit('conversation:leave', {'conversationId': id});
    }
  }

  void dispose() {
    _closed = true;
    _socket?.dispose();
    _signals.close();
  }
}
