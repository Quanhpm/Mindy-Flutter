import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../attendance/attendance_widgets.dart';
import '../teaching/classes_screens.dart';
import 'chat_models.dart';
import 'chat_query.dart';
import 'chat_service.dart';
import 'chat_widgets.dart';

abstract final class StaffChatRoutes {
  static const conversations = '/mentor/chat';
  static const notifications = '/mentor/chat/notifications';
  static const roomPath = '/mentor/chat/room/:conversationId';
  static String room(String id, {String? title}) => Uri(
    path: '/mentor/chat/room/$id',
    queryParameters: {'title': ?title},
  ).toString();
}

class StaffChatConversationsScreen extends ConsumerWidget {
  const StaffChatConversationsScreen({super.key});
  static const request = (notifications: false, type: '');
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider),
        q = ref.watch(chatListProvider(request)),
        controller = ref.read(chatListProvider(request).notifier),
        me = ref.watch(sessionProvider).user?.id,
        c = context.mdy;
    void open(ChatConversation row) => context.push(
      StaffChatRoutes.room(row.id, title: row.title(t(ch('unnamed')))),
    );
    final people = q.conversations.where((c) => c.type == 'DIRECT').toList();
    return ChatFlatPage(
      prefix: 'chat-list',
      title: t(ch('title')),
      onBack: () => staffBack(context),
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        color: c.primary,
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: q.conversations.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                children: [
                  if (people.isNotEmpty)
                    SingleChildScrollView(
                      key: const Key('chat-list-people'),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        spacing: MdySpace.s12,
                        children: [
                          for (final row in people)
                            MdyPressed(
                              key: Key('chat-list-person-${row.id}'),
                              onTap: () => open(row),
                              builder: (ctx, pressed) => SizedBox(
                                width: 72,
                                child: Column(
                                  spacing: MdySpace.s4,
                                  children: [
                                    MdyAvatar(
                                      name: row.title(t(ch('unnamed'))),
                                      size: 60,
                                    ),
                                    Text(
                                      row.title(t(ch('unnamed'))),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: MdyType.size(
                                        13,
                                      ).copyWith(color: c.secondary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ChatGate(
                      prefix: 'chat-list',
                      loaded: q.loaded,
                      busy: q.busy,
                      error: q.error,
                      retry: controller.refresh,
                      children: [
                        if (q.conversations.isEmpty)
                          MdyText(
                            t(ch('empty')),
                            key: const Key('chat-list-empty'),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }
            if (index == q.conversations.length + 1) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    if (q.next != null)
                      MdyButton(
                        key: const Key('chat-list-more'),
                        variant: MdyButtonVariant.text,
                        label: t(ch(q.footerError ? 'retry' : 'more')),
                        busy: q.busy,
                        disabled: q.busy,
                        onPressed: controller.more,
                      ),
                  ],
                ),
              );
            }
            final row = q.conversations[index - 1],
                last = row.lastMessage,
                unread = row.unread > 0;
            final content = last == null
                ? t(ch('noPreview'))
                : last.deletedAt != null
                ? t(ch('deleted'))
                : last.body ?? t(ch('file'));
            final preview = last == null
                ? content
                : last.senderId == me
                ? '${t(ch('you'))}: $content'
                : row.type == 'GROUP'
                ? '${last.senderName}: $content'
                : content;
            return Semantics(
              button: true,
              child: MdyPressed(
                key: Key('chat-list-row-${row.id}'),
                onTap: () => open(row),
                builder: (ctx, pressed) => Opacity(
                  opacity: pressed ? .8 : 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      spacing: MdySpace.s12,
                      children: [
                        MdyAvatar(name: row.title(t(ch('unnamed'))), size: 60),
                        Expanded(
                          child: Column(
                            spacing: MdySpace.s2,
                            children: [
                              Row(
                                spacing: MdySpace.s8,
                                children: [
                                  Expanded(
                                    child: Text(
                                      row.title(t(ch('unnamed'))),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: MdyType.size(
                                        17,
                                        unread ? MdyType.w700 : MdyType.w500,
                                      ).copyWith(color: c.ink),
                                    ),
                                  ),
                                  Text(
                                    chatListTime(
                                      row.activityAt,
                                      t.locale.languageCode,
                                    ),
                                    style: MdyType.size(13).copyWith(
                                      color: unread ? c.ink : c.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                spacing: MdySpace.s8,
                                children: [
                                  Expanded(
                                    child: Text(
                                      preview,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          MdyType.size(
                                            15,
                                            unread
                                                ? MdyType.w600
                                                : MdyType.w400,
                                          ).copyWith(
                                            color: unread ? c.ink : c.secondary,
                                          ),
                                    ),
                                  ),
                                  if (unread)
                                    Container(
                                      key: Key('chat-list-unread-${row.id}'),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                      ),
                                      height: 18,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: c.primary,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        row.unread > 99
                                            ? '99+'
                                            : '${row.unread}',
                                        style: MdyType.size(
                                          11,
                                          MdyType.w700,
                                        ).copyWith(color: c.onBrand),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class StaffChatRoomScreen extends ConsumerStatefulWidget {
  const StaffChatRoomScreen({super.key, required this.id, this.title});
  final String id;
  final String? title;
  @override
  ConsumerState<StaffChatRoomScreen> createState() => _RoomState();
}

class _RoomState extends ConsumerState<StaffChatRoomScreen> {
  final _body = TextEditingController();
  final _scroll = ScrollController();
  @override
  void dispose() {
    _body.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _file(ChatMessage message) async {
    final service = ref.read(staffChatServiceProvider),
        toast = ref.read(mdyToastProvider.notifier),
        t = ref.read(trProvider);
    try {
      final uri = await service.fileUrl(widget.id, message.id);
      if (!mounted) return;
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw const ChatFailure('error');
      }
    } catch (_) {
      toast.show(t(ch('fileFailed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        room = ref.watch(chatRoomProvider(widget.id)),
        controller = ref.read(chatRoomProvider(widget.id).notifier),
        c = context.mdy,
        me = ref.watch(sessionProvider).user?.id;
    final ready = room.loaded && room.conversation != null,
        title =
            room.conversation?.title(t(ch('unnamed'))) ??
            widget.title ??
            t(ch('title'));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        controller.visible(ModalRoute.of(context)?.isCurrent == true);
      }
    });
    final messages = room.messages, problem = chatMessageProblem(_body.text);
    var unreadPlaced = false;
    final rows =
        <
          ({
            ChatMessage message,
            bool starts,
            bool ends,
            bool time,
            bool unread,
          })
        >[];
    for (final (index, item) in messages.indexed) {
      final prev = index == 0 ? null : messages[index - 1],
          opening = room.opening;
      final unread =
          !unreadPlaced &&
          opening != null &&
          item.senderId != me &&
          compareChatSequence(item.sequence, opening.lastRead) > 0 &&
          compareChatSequence(item.sequence, opening.watermark) <= 0;
      unreadPlaced = unreadPlaced || unread;
      final time =
          !unread &&
          (prev == null ||
              item.createdAt.difference(prev.createdAt).inMinutes >= 15);
      rows.add((
        message: item,
        starts: unread || time || prev?.senderId != item.senderId,
        ends: true,
        time: time,
        unread: unread,
      ));
    }
    final total = ready ? room.pending.length + rows.length : 0;
    return ChatFlatPage(
      prefix: 'chat-room',
      title: title,
      avatar: true,
      onBack: () => staffBack(context),
      footer: !ready
          ? null
          : room.conversation!.canSend
          ? Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: MdySpace.s4,
                children: [
                  if (problem == 'tooLong')
                    Text(
                      t(ch('tooLong')),
                      key: const Key('chat-composer-too-long'),
                      style: MdyType.size(12).copyWith(color: c.danger),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    spacing: MdySpace.s8,
                    children: [
                      Expanded(
                        child: Semantics(
                          label: t(ch('placeholder')),
                          child: TextField(
                            key: const Key('chat-composer-input'),
                            controller: _body,
                            minLines: 1,
                            maxLines: 5,
                            onChanged: (_) => setState(() {}),
                            style: MdyType.size(15).copyWith(color: c.ink),
                            decoration: InputDecoration(
                              hintText: 'Aa',
                              hintStyle: MdyType.size(
                                15,
                              ).copyWith(color: c.tertiary),
                              filled: true,
                              fillColor: c.muted2,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        enabled: problem == null,
                        label: t(ch('send')),
                        child: MdyPressed(
                          key: const Key('chat-composer-send'),
                          enabled: problem == null,
                          onTap: () {
                            controller.send(_body.text);
                            _body.clear();
                            setState(() {});
                            if (_scroll.hasClients) {
                              _scroll.animateTo(
                                0,
                                duration: MdyMotion.base,
                                curve: Curves.easeOut,
                              );
                            }
                          },
                          builder: (context, pressed) => SizedBox.square(
                            dimension: 44,
                            child: MdyIcon(
                              MdyIcons.send,
                              size: 24,
                              color: problem == null ? c.primary : c.tertiary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: MdyText(
                t(ch('readOnly')),
                key: const Key('chat-room-read-only'),
                textAlign: TextAlign.center,
              ),
            ),
      child: ListView.builder(
        controller: _scroll,
        reverse: ready,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: total + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return !ready
                ? ChatGate(
                    prefix: 'chat-room',
                    loaded: false,
                    busy: room.busy,
                    error: room.error,
                    retry: controller.refresh,
                    children: const [],
                  )
                : room.error != null
                ? MdyAlert(
                    t(
                      ch(
                        room.error!.kind == 'offline'
                            ? 'stale'
                            : 'refreshFailed',
                      ),
                    ),
                    key: Key(
                      room.error!.kind == 'offline'
                          ? 'chat-room-stale'
                          : 'chat-room-refresh-error',
                    ),
                    warning: true,
                  )
                : total == 0
                ? MdyText(
                    t(ch('noMessages')),
                    key: const Key('chat-room-empty'),
                    textAlign: TextAlign.center,
                  )
                : const SizedBox.shrink();
          }
          if (index == total + 1) {
            return ready && room.cursor != null
                ? MdyButton(
                    key: const Key('chat-room-older'),
                    variant: room.olderError == null
                        ? MdyButtonVariant.text
                        : MdyButtonVariant.secondary,
                    size: MdyButtonSize.sm,
                    label: t(ch(room.olderError == null ? 'older' : 'retry')),
                    busy: room.loadingOlder,
                    disabled: room.loadingOlder,
                    onPressed: controller.older,
                  )
                : const SizedBox.shrink();
          }
          final offset = index - 1;
          if (offset < room.pending.length) {
            final pending = room.pending[room.pending.length - 1 - offset];
            return MdyPressed(
              key: Key('chat-pending-${pending.clientId}'),
              enabled: pending.failure != null,
              onTap: () => controller.resend(pending),
              builder: (context, pressed) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Opacity(
                      opacity: .7,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.sizeOf(context).width * .75,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: c.primary,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          pending.body,
                          style: MdyType.size(15).copyWith(color: c.onBrand),
                        ),
                      ),
                    ),
                    Text(
                      t(
                        ch(
                          pending.failure == null
                              ? 'sending'
                              : pending.failure == 'rateLimited'
                              ? 'rateLimited'
                              : 'sendFailed',
                        ),
                      ),
                      key: pending.failure == null
                          ? null
                          : Key('chat-pending-${pending.clientId}-error'),
                      style: MdyType.size(12).copyWith(
                        color: pending.failure == null ? c.secondary : c.danger,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          final position = rows.length - 1 - (offset - room.pending.length),
              row = rows[position],
              item = row.message;
          return ChatMessageBubble(
            item: item,
            mine: item.senderId == me,
            starts: row.starts,
            ends: position == rows.length - 1 || rows[position + 1].starts,
            time: row.time,
            unread: row.unread,
            group: room.conversation?.type == 'GROUP',
            sent:
                position == rows.length - 1 &&
                item.senderId == me &&
                room.pending.isEmpty,
            quoted: messages.where((m) => m.id == item.replyId).firstOrNull,
            onFile: () => _file(item),
          );
        },
      ),
    );
  }
}

class StaffChatNotificationsScreen extends ConsumerStatefulWidget {
  const StaffChatNotificationsScreen({super.key});
  @override
  ConsumerState<StaffChatNotificationsScreen> createState() =>
      _NotificationsState();
}

class _NotificationsState extends ConsumerState<StaffChatNotificationsScreen> {
  static const _request = (notifications: true, type: '');
  bool _marking = false;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider),
        q = ref.watch(chatListProvider(_request)),
        controller = ref.read(chatListProvider(_request).notifier),
        service = ref.read(staffChatServiceProvider);
    return AttendancePage(
      prefix: 'chat-notifications',
      title: t(ch('notifications')),
      onBack: () => staffBack(context),
      refresh: controller.refresh,
      children: [
        ChatGate(
          prefix: 'chat-notifications',
          loaded: q.loaded,
          busy: q.busy,
          error: q.error,
          retry: controller.refresh,
          children: [
            if (q.notifications.any((n) => n.readAt == null))
              MdyButton(
                key: const Key('chat-notifications-read-all'),
                variant: MdyButtonVariant.text,
                size: MdyButtonSize.sm,
                label: t(ch('readAll')),
                busy: _marking,
                disabled: _marking,
                onPressed: () async {
                  setState(() => _marking = true);
                  try {
                    await service.readAll();
                    if (!mounted) return;
                    ref.read(chatRevisionProvider.notifier).bump();
                  } catch (_) {
                    if (mounted) {
                      ref.read(mdyToastProvider.notifier).show(t(ch('error')));
                    }
                  } finally {
                    if (mounted) setState(() => _marking = false);
                  }
                },
              ),
            if (q.notifications.isEmpty)
              MdyText(
                t(ch('notificationsEmpty')),
                key: const Key('chat-notifications-empty'),
              ),
            for (final row in q.notifications)
              MdyPressed(
                key: Key('chat-notifications-row-${row.id}'),
                onTap: () {
                  if (row.readAt == null) {
                    unawaited(
                      service
                          .readNotification(row.id)
                          .then((_) {
                            if (mounted) {
                              ref.read(chatRevisionProvider.notifier).bump();
                            }
                          })
                          .catchError((_) {}),
                    );
                  }
                  context.push(StaffChatRoutes.room(row.conversationId));
                },
                builder: (context, pressed) => MdyCard(
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.all(MdySpace.s14),
                  children: [
                    Row(
                      spacing: MdySpace.s12,
                      children: [
                        MdyIcon(
                          MdyIcons.chat,
                          size: 22,
                          color: row.readAt == null
                              ? context.mdy.primary
                              : context.mdy.ink,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: MdySpace.s2,
                            children: [
                              Text(
                                row.title,
                                style: MdyType.size(
                                  14,
                                  row.readAt == null
                                      ? MdyType.w600
                                      : MdyType.w400,
                                ).copyWith(color: context.mdy.ink),
                              ),
                              MdyText(row.body),
                              Text(
                                chatMessageTime(
                                  row.createdAt,
                                  t.locale.languageCode,
                                ),
                                style: MdyType.size(
                                  11,
                                ).copyWith(color: context.mdy.secondary),
                              ),
                            ],
                          ),
                        ),
                        if (row.readAt == null)
                          Container(
                            key: Key('chat-notifications-unread-${row.id}'),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.mdy.dangerButton,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (q.next != null)
              MdyButton(
                key: const Key('chat-notifications-more'),
                variant: MdyButtonVariant.text,
                label: t(ch(q.footerError ? 'retry' : 'more')),
                busy: q.busy,
                disabled: q.busy,
                onPressed: controller.more,
              ),
          ],
        ),
      ],
    );
  }
}
