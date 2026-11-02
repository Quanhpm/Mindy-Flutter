import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/ui/mdy/mdy.dart';
import 'chat_screens.dart';
import 'chat_service.dart';
import 'chat_widgets.dart';

class StaffMessageStudentButton extends ConsumerStatefulWidget {
  const StaffMessageStudentButton({
    super.key,
    required this.studentId,
    this.studentName,
  });
  final String studentId;
  final String? studentName;
  @override
  ConsumerState<StaffMessageStudentButton> createState() => _MessageState();
}

class _MessageState extends ConsumerState<StaffMessageStudentButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    return MdyButton(
      key: const Key('student-report-message'),
      variant: MdyButtonVariant.secondary,
      size: MdyButtonSize.sm,
      icon: MdyIcons.chat,
      label: t(ch('message')),
      busy: _busy,
      disabled: _busy,
      onPressed: () async {
        setState(() => _busy = true);
        try {
          final conversation = await ref
              .read(staffChatServiceProvider)
              .direct(widget.studentId);
          if (mounted && context.mounted) {
            context.push(
              StaffChatRoutes.room(conversation.id, title: widget.studentName),
            );
          }
        } catch (_) {
          if (mounted) {
            ref.read(mdyToastProvider.notifier).show(t(ch('openFailed')));
          }
        } finally {
          if (mounted) setState(() => _busy = false);
        }
      },
    );
  }
}
