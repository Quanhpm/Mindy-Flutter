import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/ui/states.dart';
import '../../core/ui/staff/staff_data_state.dart';
import '../../core/ui/staff/staff_theme.dart';
import '../../core/ui/staff/staff_widgets.dart';
import '../../core/ui/staff/sym.dart';
import '../../core/utils/format.dart';
import 'notifications_models.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, required this.count, required this.label, required this.onPressed});
  final int count;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    backgroundColor: StaffColors.accent,
    label: Text(count > 99 ? '99+' : '$count'),
    child: IconButton(
      tooltip: label,
      onPressed: onPressed,
      style: IconButton.styleFrom(backgroundColor: StaffColors.teal500),
      icon: const Icon(Sym.notifications, color: StaffColors.surface),
    ),
  );
}

class NotificationsPanel extends ConsumerStatefulWidget {
  const NotificationsPanel({
    super.key,
    required this.value,
    required this.timeZone,
    required this.onRetry,
    required this.onRead,
    required this.onReadAll,
    this.onLoadMore,
    this.disabled = false,
  });
  final AsyncValue<NotificationPage> value;
  final String timeZone;
  final VoidCallback onRetry;
  final Future<void> Function(MindyNotification) onRead;
  final Future<void> Function() onReadAll;
  final Future<void> Function()? onLoadMore;
  final bool disabled;
  @override
  ConsumerState<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends ConsumerState<NotificationsPanel> {
  bool _pending = false;
  Object? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_pending) return;
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final unread = widget.value.value?.items.any((n) => n.readAt == null) ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _pending || !unread || widget.disabled ? null : () => _run(widget.onReadAll),
            child: Text(t('mentor.notificationsPanel.readAll'), style: StaffText.link),
          ),
        ),
        if (_pending) const LinearProgressIndicator(color: StaffColors.teal600),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: StaffDataState(
              title: t('mentor.notificationsPanel.actionError'),
              description: t(errorKey(_error!)),
              error: _error,
            ),
          ),
        widget.disabled
            ? StaffDataState(
                title: t('mentor.notificationsPanel.empty'),
                description: t('mentor.notificationsPanel.disabled'),
              )
            : widget.value.when(
                skipLoadingOnRefresh: false,
                loading: () => const Skeleton(height: 180),
                error: (error, _) => StaffDataState(
                  title: t('mentor.notificationsPanel.loadError'),
                  description: t(errorKey(error)),
                  error: error,
                  onRetry: widget.onRetry,
                ),
                data: (page) => page.items.isEmpty
                    ? StaffDataState(
                        title: t('mentor.notificationsPanel.empty'),
                        description: t('mentor.notificationsPanel.emptyDescription'),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final notification in page.items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Material(
                                color: notification.readAt == null ? StaffColors.tealTint : StaffColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  onTap: _pending || notification.readAt != null
                                      ? null
                                      : () => _run(() => widget.onRead(notification)),
                                  leading: const Icon(Sym.chat, color: StaffColors.teal600),
                                  title: Text(notification.title, style: StaffText.bodyStrong),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(notification.body, style: StaffText.caption),
                                      const SizedBox(height: 6),
                                      Text(
                                        Dates.instant(notification.createdAt, widget.timeZone),
                                        style: StaffText.small,
                                      ),
                                    ],
                                  ),
                                  trailing: notification.readAt == null
                                      ? Semantics(
                                          label: t('mentor.notificationsPanel.unread'),
                                          child: const Icon(
                                            Sym.radioButtonChecked,
                                            size: 10,
                                            color: StaffColors.accent,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          if (page.hasMore)
                            StaffButton(
                              label: t('mentor.notificationsPanel.loadMore'),
                              outlined: true,
                              loading: _pending,
                              onPressed: widget.onLoadMore == null ? null : () => _run(widget.onLoadMore!),
                            ),
                        ],
                      ),
              ),
      ],
    );
  }
}
