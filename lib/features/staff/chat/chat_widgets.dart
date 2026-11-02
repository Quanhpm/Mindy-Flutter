import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../teaching/teaching_widgets.dart';
import 'chat_models.dart';
import 'chat_service.dart';

final sessionUserIdProvider = Provider<String?>(
  (ref) => ref.watch(sessionProvider).user?.id,
);
String ch(String key) => 'mdy.chat.$key';
String chatListTime(DateTime value, String locale) {
  final date = value.toUtc().add(const Duration(hours: 7)),
      now = DateTime.now().toUtc().add(const Duration(hours: 7));
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
  return DateFormat(
    days == 0
        ? 'HH:mm'
        : days > 0 && days < 7
        ? 'EEE'
        : date.year == now.year
        ? 'dd/MM'
        : 'dd/MM/yyyy',
    locale,
  ).format(date);
}

String chatMessageTime(DateTime value, String locale) {
  final date = value.toUtc().add(const Duration(hours: 7)),
      now = DateTime.now().toUtc().add(const Duration(hours: 7));
  return DateFormat(
    date.year == now.year && date.month == now.month && date.day == now.day
        ? 'HH:mm'
        : 'HH:mm dd/MM/yyyy',
    locale,
  ).format(date);
}

class ChatGate extends ConsumerWidget {
  const ChatGate({
    super.key,
    required this.prefix,
    required this.loaded,
    required this.busy,
    required this.children,
    this.error,
    this.retry,
  });
  final String prefix;
  final bool loaded, busy;
  final List<Widget> children;
  final ChatFailure? error;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider), e = error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s12,
      children: [
        if (loaded)
          ...children
        else if (busy)
          KeyedSubtree(
            key: Key('$prefix-skeleton'),
            child: const SkeletonList(count: 3),
          )
        else if (e != null) ...[
          MdyAlert(
            t(
              ch(
                e.kind == 'offline'
                    ? 'offlineEmpty'
                    : ['denied', 'notFound', 'unavailable'].contains(e.kind)
                    ? e.kind
                    : 'error',
              ),
            ),
            key: Key('$prefix-${e.kind == 'notFound' ? 'not-found' : e.kind}'),
          ),
          if (![
            'offline',
            'denied',
            'notFound',
            'unavailable',
          ].contains(e.kind))
            MdyButton(
              key: Key('$prefix-retry'),
              label: t(ch('retry')),
              onPressed: retry,
            ),
        ],
        if (loaded && e != null)
          MdyAlert(
            t(ch(e.kind == 'offline' ? 'stale' : 'refreshFailed')),
            key: Key(
              '$prefix-${e.kind == 'offline' ? 'stale' : 'refresh-error'}',
            ),
            warning: true,
          ),
      ],
    );
  }
}

class ChatFlatPage extends StatelessWidget {
  const ChatFlatPage({
    super.key,
    required this.prefix,
    required this.title,
    required this.onBack,
    required this.child,
    this.avatar = false,
    this.footer,
  });
  final String prefix, title;
  final VoidCallback onBack;
  final Widget child;
  final bool avatar;
  final Widget? footer;
  @override
  Widget build(BuildContext context) {
    final c = context.mdy;
    return Scaffold(
      key: Key('$prefix-screen'),
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                spacing: MdySpace.s8,
                children: [
                  MdyButton(
                    key: Key('$prefix-back'),
                    variant: MdyButtonVariant.text,
                    size: MdyButtonSize.sm,
                    onPressed: onBack,
                    child: MdyIcon(
                      MdyIcons.arrowBack,
                      color: avatar ? c.primary : c.ink,
                    ),
                  ),
                  if (avatar) MdyAvatar(name: title, size: 40),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: MdyType.size(
                        avatar ? 17 : 28,
                        avatar ? MdyType.w600 : MdyType.w700,
                      ).copyWith(color: c.ink),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: child),
            ?footer,
          ],
        ),
      ),
    );
  }
}

class ChatMessageBubble extends ConsumerWidget {
  const ChatMessageBubble({
    super.key,
    required this.item,
    required this.mine,
    required this.starts,
    required this.ends,
    required this.time,
    required this.unread,
    required this.group,
    required this.sent,
    required this.onFile,
    this.quoted,
  });
  final ChatMessage item;
  final ChatMessage? quoted;
  final bool mine, starts, ends, time, unread, group, sent;
  final VoidCallback onFile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider),
        c = context.mdy,
        locale = t.locale.languageCode,
        removed = item.deletedAt != null;
    final foreground = mine ? c.onBrand : c.ink;
    final reply = removed || item.replyId == null
        ? null
        : mine
        ? t(ch('youReplied'), {'to': item.replySender ?? ''})
        : quoted?.senderId == ref.read(sessionUserIdProvider)
        ? t(ch('repliedToYou'), {'name': item.senderName})
        : t(ch('replied'), {
            'name': item.senderName,
            'to': item.replySender ?? '',
          });
    final replyText = item.replyDeleted
        ? t(ch('deleted'))
        : quoted?.body ?? (quoted == null ? null : t(ch('file')));
    return Padding(
      key: Key('chat-message-${item.id}'),
      padding: EdgeInsets.only(top: starts ? MdySpace.s12 : MdySpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (time)
            Padding(
              padding: const EdgeInsets.only(bottom: MdySpace.s12),
              child: Text(
                chatMessageTime(item.createdAt, locale),
                textAlign: TextAlign.center,
                style: MdyType.size(12).copyWith(color: c.secondary),
              ),
            ),
          if (unread)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Row(
                key: const Key('chat-room-unread'),
                spacing: MdySpace.s12,
                children: [
                  Expanded(child: Container(height: 1, color: c.divider)),
                  MdyText(t(ch('unreadDivider'))),
                  Expanded(child: Container(height: 1, color: c.divider)),
                ],
              ),
            ),
          if (group && !mine && starts && reply == null)
            Padding(
              padding: const EdgeInsets.only(left: 48, bottom: 2),
              child: Text(
                item.senderName,
                style: MdyType.size(12).copyWith(color: c.secondary),
              ),
            ),
          if (reply != null)
            Padding(
              padding: EdgeInsets.only(
                left: mine ? 0 : 48,
                right: mine ? 12 : 0,
                bottom: 2,
              ),
              child: Text(
                reply,
                textAlign: mine ? TextAlign.right : TextAlign.left,
                style: MdyType.size(12).copyWith(color: c.secondary),
              ),
            ),
          if (replyText != null)
            Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: EdgeInsets.only(left: mine ? 0 : 36),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * .7,
                ),
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                decoration: BoxDecoration(
                  color: c.muted,
                  borderRadius: BorderRadius.circular(MdyRadius.r18),
                ),
                child: Text(
                  replyText,
                  maxLines: 2,
                  style: MdyType.size(13).copyWith(color: c.secondary),
                ),
              ),
            ),
          Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: MdySpace.s8,
            children: [
              if (!mine)
                ends
                    ? MdyAvatar(name: item.senderName, size: 28)
                    : const SizedBox(width: 28),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * .75,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: mine ? c.primary : c.muted2,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(!mine && !starts ? 4 : 18),
                        bottomLeft: Radius.circular(!mine && !ends ? 4 : 18),
                        topRight: Radius.circular(mine && !starts ? 4 : 18),
                        bottomRight: Radius.circular(mine && !ends ? 4 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: MdySpace.s4,
                      children: [
                        if (!removed && item.fileId != null)
                          MdyPressed(
                            key: Key('chat-message-${item.id}-file'),
                            onTap: onFile,
                            builder: (context, pressed) => ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: MdySpace.s8,
                                children: [
                                  MdyIcon(
                                    MdyIcons.attachFile,
                                    size: 18,
                                    color: foreground,
                                  ),
                                  Flexible(
                                    child: Text(
                                      item.fileName ?? t(ch('file')),
                                      style: MdyType.size(13).copyWith(
                                        color: foreground,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (removed)
                          Text(
                            t(ch('deleted')),
                            style: MdyType.size(15).copyWith(
                              color: mine ? c.onBrandMuted : c.secondary,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else if (item.body?.isNotEmpty ?? false)
                          SelectableText(
                            item.body!,
                            style: MdyType.size(15).copyWith(color: foreground),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (item.editedAt != null && !removed || sent)
            Padding(
              padding: EdgeInsets.only(
                top: 2,
                left: mine ? 0 : 48,
                right: mine ? 12 : 0,
              ),
              child: Text(
                [
                  if (item.editedAt != null && !removed) t(ch('edited')),
                  if (sent) t(ch('sent')),
                ].join(' · '),
                textAlign: mine ? TextAlign.right : TextAlign.left,
                style: MdyType.size(11).copyWith(color: c.secondary),
              ),
            ),
        ],
      ),
    );
  }
}
