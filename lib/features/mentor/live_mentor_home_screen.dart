import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/utils/format.dart';
import '../../core/ui/staff/staff_widgets.dart';
import '../notifications/live_notifications_panel.dart';
import '../notifications/notifications_panel.dart';
import '../notifications/notifications_providers.dart';
import 'classes/classes_providers.dart';
import 'home/home_providers.dart';
import 'home/next_session_card.dart';
import 'mentor_actions.dart';
import 'mentor_home_screen.dart';
import 'mentor_providers.dart';
import 'schedule/schedule_providers.dart';
import 'session/live_room_sheet.dart';
import 'session/session_context_api.dart';

class LiveMentorHomeScreen extends ConsumerStatefulWidget {
  const LiveMentorHomeScreen({super.key});
  @override
  ConsumerState<LiveMentorHomeScreen> createState() => _LiveMentorHomeScreenState();
}

class _LiveMentorHomeScreenState extends ConsumerState<LiveMentorHomeScreen> with WidgetsBindingObserver {
  GoRouter? _router;
  Timer? _poll;
  bool _active = false;
  String? _day;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final router = GoRouter.of(context);
    if (_router != router) {
      _router?.routerDelegate.removeListener(_syncPolling);
      _router = router;
      router.routerDelegate.addListener(_syncPolling);
    }
    _syncPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncPolling();

  void _syncPolling() {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final active =
        (lifecycle == null || lifecycle == AppLifecycleState.resumed) &&
        // uri chỉ phản ánh route go(), không phản ánh màn được push lên trên Home.
        _router?.routerDelegate.currentConfiguration.lastOrNull?.matchedLocation == Routes.mentor &&
        ModalRoute.of(context)?.isCurrent != false;
    if (active == _active) return;
    _active = active;
    _poll?.cancel();
    if (!active) return;
    Future.microtask(() {
      if (mounted && _active) {
        ref.invalidate(notificationCountProvider);
        ref.invalidate(mentorScheduleProvider(mentorHomeQuery));
      }
    });
    _poll = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted || !_active) return;
      ref.invalidate(notificationCountProvider);
      final zone = ref.read(mentorTimeZoneProvider).value;
      if (zone != null) {
        final day = Dates.localDay(ref.read(mentorClockProvider)(), zone);
        if (_day != day) {
          _day = day;
          ref.invalidate(mentorScheduleProvider(mentorHomeQuery));
        }
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _router?.routerDelegate.removeListener(_syncPolling);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final schedule = ref.watch(mentorScheduleProvider(mentorHomeQuery));
    final data = schedule.isLoading || schedule.hasError ? null : schedule.value;
    final now = ref.watch(mentorClockProvider)();
    final next = data?.nextToday(now);
    final room = next == null ? null : ref.watch(mentorRoomProvider(next.session.id));
    final dismissed = ref.watch(mentorDismissedNoticesProvider).value;
    final substitutes =
        data
            ?.onDay(Dates.localDay(now, data.timeZone))
            .where((entry) => entry.session.isSubstitute && !(dismissed?.contains(entry.session.id) ?? true))
            .toList() ??
        [];
    final notice = substitutes.isEmpty ? null : substitutes.first;
    final count = ref.watch(notificationCountProvider);
    void refresh() {
      ref.invalidate(mentorSubstituteOnlyProvider);
      ref.invalidate(mentorClassesProvider);
      ref.invalidate(mentorTimeZoneProvider);
      ref.invalidate(mentorScheduleProvider(mentorHomeQuery));
      ref.invalidate(notificationCountProvider);
    }

    return MentorHomeScreen(
      onRefresh: () async => refresh(),
      onSessionUtility: (utility) => openMentorSessionUtility(context, ref, utility),
      teachingCard: MentorNextSessionCard(
        value: schedule,
        now: now,
        room: room,
        onRetry: refresh,
        onViewSchedule: () => context.push(Routes.mentorPage('schedule')),
        onEnterRoom: (entry) async {
          final meeting = ref.read(mentorRoomProvider(entry.session.id)).value?.meetingUrl;
          if (meeting == null) return;
          try {
            await launchTeachingRoom(meeting);
          } catch (_) {
            if (mounted) showStaffToast(this.context, t('mentor.room.openError'));
          }
        },
      ),
      notificationButton: NotificationBell(
        count: count.isLoading || count.hasError ? 0 : count.value ?? 0,
        label: t('mentor.notifications'),
        onPressed: () {
          final zoneState = ref.read(mentorTimeZoneProvider);
          final zone = zoneState.isLoading || zoneState.hasError ? null : zoneState.value;
          if (zone == null) {
            ref.invalidate(mentorTimeZoneProvider);
            showStaffToast(context, t('mentor.schedule.loadError'));
          } else {
            showMentorNotifications(context, ref, timeZone: zone);
          }
        },
      ),
      substituteNotice: notice == null
          ? null
          : MentorSubstituteNotice(
              className: notice.className,
              onDismiss: () => ref.read(mentorDismissedNoticesProvider.notifier).dismiss(notice.session.id),
              onOpen: () => context.push(Routes.mentorPage('substitute')),
            ),
    );
  }
}
