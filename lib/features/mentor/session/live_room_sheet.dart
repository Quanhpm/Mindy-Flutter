import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_error.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../schedule/schedule_models.dart';
import '../schedule/schedule_providers.dart';
import 'room_sheet.dart';
import 'session_context_api.dart';

Future<void> launchTeachingRoom(Uri uri) async {
  if (!['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw ApiError(status: 0, code: 'MEETING_LINK_OPEN_FAILED');
  }
}

void showMentorRoom(BuildContext outerContext, WidgetRef ref, TeachingEntry entry) {
  final t = ref.read(trProvider);
  ref.invalidate(mentorRoomProvider(entry.session.id));
  openStaffSheet(
    outerContext,
    title: t('mentor.room.title'),
    subtitle: entry.className,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final provider = mentorRoomProvider(entry.session.id);
        ref.listen(provider, (_, next) {
          final error = next.error;
          if (error is ApiError && error.status == 403) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              ref.invalidate(mentorScheduleProvider);
              Navigator.of(context).pop();
              if (outerContext.mounted) showStaffToast(outerContext, t('mentor.session.accessLost'));
            });
          }
        });
        return MentorRoomContent(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          onOpen: launchTeachingRoom,
        );
      },
    ),
  );
}
