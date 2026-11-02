import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/ui/staff/staff_widgets.dart';
import 'notifications_panel.dart';
import 'notifications_providers.dart';

void showMentorNotifications(BuildContext context, WidgetRef ref, {required String timeZone}) {
  final title = ref.read(trProvider)('mentor.notifications');
  ref.invalidate(notificationFeedProvider);
  openStaffSheet(
    context,
    title: title,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final feed = ref.watch(notificationFeedProvider);
        return NotificationsPanel(
          value: feed.whenData((value) => value.page),
          timeZone: timeZone,
          disabled: feed.value?.disabled ?? false,
          onRetry: () => ref.invalidate(notificationFeedProvider),
          onRead: (item) => ref.read(notificationFeedProvider.notifier).read(item),
          onReadAll: () => ref.read(notificationFeedProvider.notifier).readAll(),
          onLoadMore: () => ref.read(notificationFeedProvider.notifier).loadMore(),
        );
      },
    ),
  );
}
