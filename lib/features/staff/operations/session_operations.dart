import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/router/routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_user.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../teaching/teaching_models.dart';
import 'operations_service.dart';
import 'operations_widgets.dart';

/// Route các màn điều phối buổi (đăng ký ở router).
abstract final class StaffOpsRoutes {
  static const assignPath = '/manager/session/:sessionId/assign';
  static const reschedulePath = '/manager/session/:sessionId/reschedule';
  static const replacePath = '/manager/session/:sessionId/replace';
  static String assign(String id) => '/manager/session/$id/assign';
  static String reschedule(String id) => '/manager/session/$id/reschedule';
  static String replace(String id) => '/manager/session/$id/replace';
  static const cashOrders = '/manager/cash-orders';
  static const cashOrderPath = '/manager/cash-orders/:orderId';
  static String cashOrder(String id, {String? code}) =>
      Uri(path: '/manager/cash-orders/$id', queryParameters: {'code': ?code}).toString();
}

/// Clone `operations/components/SessionOperations.tsx`: nhóm thao tác điều phối trong chi tiết buổi (Quản lý).
class SessionOperations extends ConsumerWidget {
  const SessionOperations({super.key, required this.session, this.offline = false});
  final TeachingSession session;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionProvider.select((s) => s.user?.role));
    if (role != Role.MANAGER) return const SizedBox.shrink();
    final t = ref.watch(trProvider);
    final actions = sessionActions(session.status, session.startsAt, session.asOf);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: MdySpace.s20,
      children: [
        if (session.makeupForSessionId != null)
          MdyButton(
            key: const Key('session-makeup-source'),
            variant: MdyButtonVariant.text,
            label: t(o('makeupSource')),
            onPressed: () => context.push(Routes.managerSession(session.makeupForSessionId!)),
          ),
        if (actions.isNotEmpty)
          MdyCard(
            key: const Key('session-ops-group'),
            margin: EdgeInsets.zero,
            gap: MdySpace.s10,
            children: [
              Text(t(o('group')), style: MdyType.text.copyWith(fontWeight: MdyType.w600, color: context.mdy.ink)),
              for (final action in actions)
                MdyButton(
                  key: Key('session-ops-$action'),
                  variant: action == 'cancel' ? MdyButtonVariant.danger : MdyButtonVariant.secondary,
                  disabled: offline || session.asOf == null,
                  label: t(
                    o(action == 'assign' && session.assignment == SessionAssignment.SUBSTITUTE ? 'changeSubstitute' : action),
                  ),
                  onPressed: () => context.push(switch (action) {
                    'assign' => StaffOpsRoutes.assign(session.id),
                    'reschedule' => StaffOpsRoutes.reschedule(session.id),
                    _ => StaffOpsRoutes.replace(session.id),
                  }),
                ),
              if (offline) MdyText(t(o('needOnline'))),
            ],
          ),
      ],
    );
  }
}
