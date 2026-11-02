import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/i18n.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/router/routes.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/session/session_user.dart';
import '../../../core/ui/mdy/mdy.dart';
import '../chat/chat_query.dart';
import '../chat/chat_screens.dart';
import '../attendance/manager_attendance_screens.dart';
import '../leave/leave_query.dart';
import '../leave/leave_service.dart';
import '../operations/session_operations.dart';
import '../shared/remote.dart';
import '../teaching/teaching_format.dart';
import '../teaching/teaching_query.dart';
import 'today_card.dart';

/// Clone `screens/WorkspaceScreen.tsx`: Home của Mentor và Quản lý.
/// Header: avatar (Hồ sơ) · tên + vai trò · Thông báo (Mentor) · Cài đặt.
/// Thân: thẻ Hôm nay (Mentor) / tóm tắt buổi cần xử lý (Quản lý) + mascot, lưới tiện ích.
/// Tile cuối lưới là màn Flutter không có trong RN (owner chốt giữ lại).
class StaffWorkspaceScreen extends ConsumerWidget {
  const StaffWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(sessionProvider.select((s) => s.user));
    if (user == null) return const SizedBox.shrink();
    final mentor = user.role == Role.MENTOR;
    return Stack(
      children: [
        MdyScreen(
          key: Key(mentor ? 'workspace-mentor-root' : 'workspace-manager-root'),
          app: true,
          onRefresh: mentor ? () => _refreshMentor(ref) : null,
          children: [
            _Header(user: user, mentor: mentor),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: MdySpace.s16),
              child: MdyOverlap(
                by: MdySpace.s50,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (mentor)
                      const MentorTodayCard()
                    else
                      const _ManagerIncompleteSummary(),
                    const Positioned(
                      key: Key('workspace-mascot'),
                      left: -17,
                      top: -57,
                      width: 125,
                      height: 88,
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: Image(
                            image: AssetImage(
                              'assets/images/mdy-mascot-home.png',
                            ),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _Tiles(mentor: mentor),
          ],
        ),
        if (mentor) const _ChatBubble(),
      ],
    );
  }

  static Future<void> _refreshMentor(WidgetRef ref) async {
    ref.invalidate(staffChatUnreadProvider);
    final date = vietnamDate();
    await ref
        .read(
          teachingQueryProvider(MentorTodayCard.scheduleRequest(date)).notifier,
        )
        .refresh();
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.user, required this.mentor});
  final SessionUser user;
  final bool mentor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    Widget glassButton({
      required Key key,
      required String label,
      required MdyIcons icon,
      required VoidCallback onTap,
    }) => Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: MdyPressed(
        key: key,
        onTap: onTap,
        builder: (context, pressed) => Container(
          width: MdySpace.s44,
          height: MdySpace.s44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.onBrandMuted),
            color: pressed ? c.headerPressed : c.headerGlass,
          ),
          child: MdyIcon(icon, size: 24, color: c.onBrand),
        ),
      ),
    );
    return MdyBrandHeader(
      child: Row(
        spacing: MdySpace.s12,
        children: [
          Semantics(
            button: true,
            label: t('mdy.foundation.profileTitle'),
            excludeSemantics: true,
            child: MdyPressed(
              key: const Key('workspace-account-button'),
              onTap: () => context.push(
                mentor ? Routes.mentorProfile : Routes.managerProfile,
              ),
              builder: (context, pressed) => Opacity(
                opacity: pressed ? .8 : 1,
                child: MdyAvatar(name: user.displayName, size: 52),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  textScaler: mdyMaxScale(context),
                  style: MdyType.title.copyWith(color: c.onBrand),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    t(
                      mentor
                          ? 'mdy.foundation.MENTOR'
                          : 'mdy.foundation.MANAGER',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MdyType.size(13).copyWith(color: c.onBrandMuted),
                  ),
                ),
              ],
            ),
          ),
          if (mentor)
            glassButton(
              key: const Key('workspace-open-notifications'),
              label: t('mdy.chat.notifications'),
              icon: MdyIcons.notifications,
              onTap: () => context.push(StaffChatRoutes.notifications),
            ),
          glassButton(
            key: const Key('workspace-settings-button'),
            label: t('mdy.foundation.settingsTitle'),
            icon: MdyIcons.settings,
            onTap: () => context.push(
              mentor ? Routes.mentorSettings : Routes.managerSettings,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tiles extends ConsumerWidget {
  const _Tiles({required this.mentor});
  final bool mentor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    void go(String route) => context.push(route);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MdySpace.s16,
        MdySpace.s24,
        MdySpace.s16,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MdySpace.s14,
        children: [
          Semantics(
            header: true,
            child: Text(
              t(
                mentor
                    ? 'mdy.teaching.home.utilities'
                    : 'mdy.teaching.homeCoordination',
              ),
              style: MdyType.size(17, MdyType.w600).copyWith(color: c.ink),
            ),
          ),
          if (mentor)
            Wrap(
              spacing: MdySpace.s16,
              runSpacing: MdySpace.s16,
              children: [
                MdyHomeTile(
                  key: const Key('workspace-open-classes'),
                  label: t('mdy.teaching.myClasses'),
                  icon: MdyIcons.coPresent,
                  compact: true,
                  onPress: () => go(Routes.mentorPage('classes')),
                ),
                MdyHomeTile(
                  key: const Key('workspace-open-materials'),
                  label: t('mdy.materials.title'),
                  icon: MdyIcons.menuBook,
                  compact: true,
                  onPress: () => go(Routes.mentorPage('materials')),
                ),
                MdyHomeTile(
                  key: const Key('workspace-open-quizzes'),
                  label: t('mdy.quiz.title'),
                  icon: MdyIcons.editNote,
                  compact: true,
                  onPress: () => go(Routes.mentorPage('quiz')),
                ),
                MdyHomeTile(
                  key: const Key('workspace-open-schedule'),
                  label: t('mdy.teaching.schedule'),
                  icon: MdyIcons.calendarMonth,
                  compact: true,
                  onPress: () => go(Routes.mentorPage('schedule')),
                ),
                MdyHomeTile(
                  key: const Key('workspace-open-reports'),
                  label: t('mdy.reports.mentorLink'),
                  icon: MdyIcons.monitoring,
                  compact: true,
                  onPress: () => go(Routes.mentorPage('attendance')),
                ),
                MdyHomeTile(
                  key: const Key('workspace-open-leave'),
                  label: t('mdy.leave.leave.tile'),
                  icon: MdyIcons.eventNote,
                  compact: true,
                  onPress: () => go(Routes.mentorPage('leave')),
                ),
                // Màn Flutter không có trong RN: giữ lại.
                MdyHomeTile(
                  key: const Key('workspace-open-substitute'),
                  label: t('mentor.util.substitute'),
                  icon: MdyIcons.swapHoriz,
                  compact: true,
                  onPress: () => go(Routes.mentorPage('substitute')),
                ),
                MdyHomeTile(
                  key: const Key('workspace-open-upload'),
                  label: t('mentor.util.upload'),
                  icon: MdyIcons.uploadFile,
                  compact: true,
                  onPress: () => go(Routes.mentorPage('upload')),
                ),
              ],
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final w = box.maxWidth / 4;
                return Wrap(
                  runSpacing: MdySpace.s18,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  children: [
                    MdyHomeTile(
                      key: const Key('workspace-open-manager-classes'),
                      width: w,
                      label: t('mdy.teaching.managerClasses'),
                      icon: MdyIcons.school,
                      onPress: () => go(Routes.managerClasses),
                    ),
                    MdyHomeTile(
                      key: const Key('workspace-open-cash-orders'),
                      width: w,
                      label: t('mdy.operations.tile'),
                      icon: MdyIcons.payments,
                      onPress: () => go(StaffOpsRoutes.cashOrders),
                    ),
                    MdyHomeTile(
                      key: const Key('workspace-open-material-review'),
                      width: w,
                      label: t('mdy.materials.review'),
                      icon: MdyIcons.factCheck,
                      onPress: () => go(Routes.managerMaterials),
                    ),
                    MdyHomeTile(
                      key: const Key('workspace-open-attendance-management'),
                      width: w,
                      label: t('mdy.attendance.utility.management'),
                      icon: MdyIcons.factCheck,
                      onPress: () => go(StaffAttendanceRoutes.management),
                    ),
                    MdyHomeTile(
                      key: const Key('workspace-open-finalize'),
                      width: w,
                      label: t('mdy.attendance.finalize.title'),
                      icon: MdyIcons.taskAlt,
                      onPress: () => go(StaffAttendanceRoutes.finalizeSessions),
                    ),
                    _LeavePendingTile(
                      width: w,
                      onPress: () => go(Routes.managerLeaves),
                    ),
                    MdyHomeTile(
                      key: const Key('workspace-open-makeup-conflicts'),
                      width: w,
                      label: t('mdy.leave.leave.conflictsTile'),
                      icon: MdyIcons.eventBusy,
                      onPress: () => go(Routes.managerMakeup),
                    ),
                    // Màn Flutter không có trong RN: giữ lại.
                    MdyHomeTile(
                      key: const Key('workspace-open-mentors'),
                      width: w,
                      label: t('manager.utility.mentors'),
                      icon: MdyIcons.person,
                      onPress: () => go(Routes.managerPeople('MENTOR')),
                    ),
                    MdyHomeTile(
                      key: const Key('workspace-open-students'),
                      width: w,
                      label: t('manager.utility.students'),
                      icon: MdyIcons.groups,
                      onPress: () => go(Routes.managerPeople('STUDENT')),
                    ),
                    MdyHomeTile(
                      key: const Key('workspace-open-manager-reports'),
                      width: w,
                      label: t('manager.utility.reports'),
                      icon: MdyIcons.monitoring,
                      onPress: () => go(Routes.managerReports),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Clone `leave/components/EntryPoints.tsx` › `LeavePendingBadge`.
class _LeavePendingTile extends ConsumerWidget {
  const _LeavePendingTile({required this.width, required this.onPress});
  final double width;
  final VoidCallback onPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    const request = LeaveReadRequest(
      kind: LeaveKind.list,
      role: LeaveRole.MANAGER,
      status: 'PENDING',
      pageSize: 1,
    );
    final query = ref.watch(leaveQueryProvider(request));
    final count = !query.offline && query.result?.success == true
        ? query.data?.total
        : null;
    return MdyHomeTile(
      key: const Key('workspace-open-leave-review'),
      width: width,
      label: t('mdy.leave.leave.tile'),
      semanticLabel: count != null && count > 0
          ? t('mdy.leave.leave.tilePending', {'count': count})
          : t('mdy.leave.leave.tile'),
      icon: MdyIcons.eventNote,
      badge: count,
      onPress: onPress,
    );
  }
}

/// Tổng buổi cần xử lý (`useAttendanceQuery({kind:'incomplete', pageSize:1})`).
final staffIncompleteTotalProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  try {
    final body = await ref
        .watch(apiClientProvider)
        .get(
          'management/class-sessions/incomplete',
          query: {'page': 1, 'pageSize': 1},
          cancel: cancel,
        );
    final total = Json(body, 'INVALID_ATTENDANCE_RESPONSE').integer('total');
    if (total < 0) throw const RemoteError(RemoteFailure.error);
    return total;
  } catch (e) {
    throw RemoteError.from(e);
  }
});

/// Clone `attendance/components/EntryPoints.tsx` › `ManagerIncompleteSummary`.
class _ManagerIncompleteSummary extends ConsumerWidget {
  const _ManagerIncompleteSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final query = ref.watch(staffIncompleteTotalProvider);
    Widget body;
    if (query.hasValue && !query.isLoading) {
      final total = query.value!;
      body = total == 0
          ? Column(
              spacing: MdySpace.s4,
              children: [
                Text(
                  t('mdy.attendance.home.noneTitle'),
                  textAlign: TextAlign.center,
                  style: MdyType.size(15, MdyType.w600).copyWith(color: c.ink),
                ),
                Text(
                  t('mdy.attendance.home.none'),
                  textAlign: TextAlign.center,
                  style: MdyType.size(13).copyWith(color: c.secondary),
                ),
              ],
            )
          : Semantics(
              button: true,
              child: MdyPressed(
                key: const Key('workspace-incomplete-summary'),
                onTap: () => context.push(Routes.managerIncomplete),
                builder: (context, pressed) => ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: MdySpace.s64),
                  child: Row(
                    spacing: MdySpace.s16,
                    children: [
                      Container(
                        padding: const EdgeInsets.only(right: MdySpace.s16),
                        decoration: BoxDecoration(
                          border: Border(right: BorderSide(color: c.divider)),
                        ),
                        child: Text(
                          '$total',
                          style: MdyType.size(
                            26,
                            MdyType.w700,
                          ).copyWith(color: c.link),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          t('mdy.attendance.home.pendingLabel'),
                          style: MdyType.size(
                            15,
                            MdyType.w600,
                          ).copyWith(color: c.ink),
                        ),
                      ),
                      const MdyIcon(MdyIcons.chevronRight, size: 18),
                    ],
                  ),
                ),
              ),
            );
    } else if (query.hasError && !query.isLoading) {
      final error = RemoteError.from(query.error!);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MdySpace.s8,
        children: [
          MdyAlert(
            key: const Key('workspace-incomplete-error'),
            t(
              error.offline
                  ? 'mdy.attendance.offline'
                  : error.kind == RemoteFailure.denied
                  ? 'mdy.attendance.home.denied'
                  : 'mdy.attendance.home.failed',
            ),
            warning: true,
          ),
          if (!error.offline && error.kind != RemoteFailure.denied)
            MdyButton(
              key: const Key('workspace-incomplete-retry'),
              variant: MdyButtonVariant.text,
              label: t('mdy.attendance.retry'),
              onPressed: () => ref.invalidate(staffIncompleteTotalProvider),
            ),
        ],
      );
    } else {
      body = MdySkeleton(
        label: t('mdy.attendance.loading'),
        child: const SizedBox(height: MdySpace.s64),
      );
    }
    return MdyCard(
      key: const Key('workspace-today-card'),
      frosted: true,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(MdySpace.s24),
      gap: MdySpace.s12,
      children: [body],
    );
  }
}

/// Clone `chat/EntryPoints.tsx` › `ChatBubble`: nút tin nhắn nổi góc phải dưới (Home Mentor).
class _ChatBubble extends ConsumerWidget {
  const _ChatBubble();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(trProvider);
    final c = context.mdy;
    final unread = ref.watch(staffChatUnreadProvider).value ?? 0;
    return Positioned(
      right: MdySpace.s16,
      bottom: MediaQuery.paddingOf(context).bottom + 16,
      child: Semantics(
        button: true,
        label: unread > 0
            ? t('mdy.chat.bubbleUnread', {'count': unread})
            : t('mdy.chat.bubble'),
        excludeSemantics: true,
        child: MdyPressed(
          key: const Key('workspace-open-chat'),
          onTap: () => context.push(StaffChatRoutes.conversations),
          builder: (context, pressed) => Opacity(
            opacity: pressed ? .8 : 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: MdySpace.s56,
                  height: MdySpace.s56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                    boxShadow: [mdyShadow(c.tileShadow, 4, 12)],
                  ),
                  child: MdyIcon(MdyIcons.chat, size: 26, color: c.onBrand),
                ),
                if (unread > 0)
                  Positioned(
                    right: -MdySpace.s2,
                    top: -MdySpace.s2,
                    child: Container(
                      key: const Key('workspace-open-chat-badge'),
                      height: MdySpace.s18,
                      constraints: const BoxConstraints(minWidth: MdySpace.s18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: MdySpace.s4,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.dangerButton,
                        borderRadius: BorderRadius.circular(MdyRadius.r99),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        style: MdyType.size(
                          11,
                          MdyType.w700,
                        ).copyWith(color: c.onBrand),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
