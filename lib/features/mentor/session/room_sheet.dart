import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/staff/staff_data_state.dart';
import '../../../core/ui/staff/staff_theme.dart';
import '../../../core/ui/staff/staff_widgets.dart';
import '../../../core/ui/staff/sym.dart';
import '../../../core/utils/format.dart';
import 'session_context_models.dart';

class MentorRoomContent extends ConsumerWidget {
  const MentorRoomContent({super.key, required this.value, required this.onRetry, required this.onOpen});
  final AsyncValue<TeachingRoom> value;
  final VoidCallback onRetry;
  final Future<void> Function(Uri) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    return value.when(
      skipLoadingOnRefresh: false,
      loading: () => const Skeleton(height: 180),
      error: (error, _) => StaffDataState(
        title: t('mentor.room.loadError'),
        description: t(errorKey(error)),
        error: error,
        onRetry: onRetry,
      ),
      data: (room) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Sym.locationOn, color: StaffColors.teal600),
              const SizedBox(width: 8),
              Expanded(child: Text(room.roomName ?? t('mentor.session.noRoom'), style: StaffText.bodyStrong)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${Dates.time(room.session.startsAt, room.session.timeZone)} – ${Dates.time(room.session.endsAt, room.session.timeZone)}',
            style: StaffText.caption,
          ),
          const SizedBox(height: 20),
          Text(t('mentor.room.online'), style: StaffText.label),
          const SizedBox(height: 8),
          if (room.meetingUrl == null)
            Text(t('mentor.room.noLink'), style: StaffText.caption)
          else ...[
            SelectableText(room.meetingUrl.toString(), style: StaffText.link),
            const SizedBox(height: 16),
            StaffButton(
              label: t('mentor.room.copy'),
              icon: Sym.contentCopy,
              outlined: true,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: room.meetingUrl.toString()));
                if (!context.mounted) return;
                showStaffToast(context, t('mentor.room.copied'));
              },
            ),
            const SizedBox(height: 8),
            _OpenRoomButton(uri: room.meetingUrl!, onOpen: onOpen),
          ],
        ],
      ),
    );
  }
}

class _OpenRoomButton extends ConsumerStatefulWidget {
  const _OpenRoomButton({required this.uri, required this.onOpen});
  final Uri uri;
  final Future<void> Function(Uri) onOpen;
  @override
  ConsumerState<_OpenRoomButton> createState() => _OpenRoomButtonState();
}

class _OpenRoomButtonState extends ConsumerState<_OpenRoomButton> {
  bool _pending = false;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    return StaffButton(
      label: t('mentor.session.enterRoom'),
      icon: Sym.videocam,
      loading: _pending,
      onPressed: () async {
        setState(() => _pending = true);
        try {
          await widget.onOpen(widget.uri);
        } catch (error) {
          if (mounted) showStaffToast(this.context, t(errorKey(error)));
        } finally {
          if (mounted) setState(() => _pending = false);
        }
      },
    );
  }
}
