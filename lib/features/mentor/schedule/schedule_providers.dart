import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/utils/format.dart';
import '../classes/classes_providers.dart';
import '../session/session_context_api.dart';
import 'schedule_api.dart';
import 'schedule_models.dart';

final mentorClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final mentorNowProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = ref.watch(mentorClockProvider);
  return Stream<DateTime>.multi((controller) {
    controller.add(clock());
    final timer = Timer.periodic(const Duration(seconds: 30), (_) => controller.add(clock()));
    controller.onCancel = timer.cancel;
  });
});
final mentorTimeZoneProvider = FutureProvider<String>((ref) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(mentorScheduleApiProvider).timeZone(cancel: cancel);
});

enum MentorScheduleWindow { week, today, substitute }

typedef TeachingQuery = ({MentorScheduleWindow window, String? day});

final mentorScheduleProvider = FutureProvider.autoDispose.family<TeachingSchedule, TeachingQuery>((ref, query) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final zone = await ref.watch(mentorTimeZoneProvider.future);
  if (!ref.mounted) throw ApiError(status: 0, code: 'REQUEST_CANCELLED');
  final now = ref.watch(mentorClockProvider)();
  final day = query.day ?? Dates.localDay(now, zone);
  final range = switch (query.window) {
    MentorScheduleWindow.week => Dates.weekRange(day, zone),
    MentorScheduleWindow.today => (
      from: Dates.startOfDay(day, zone),
      to: Dates.startOfDay(Dates.shiftDay(day, 1), zone),
    ),
    MentorScheduleWindow.substitute => (
      from: Dates.startOfDay(Dates.shiftDay(day, -30), zone),
      to: Dates.startOfDay(Dates.shiftDay(day, 61), zone),
    ),
  };
  final api = ref.watch(mentorScheduleApiProvider);
  final roomApi = ref.watch(mentorSessionApiProvider);
  final classesFuture = ref.watch(mentorClassesProvider.future);
  final classes = await classesFuture;
  final sessions = await api.range(range.from, range.to, cancel: cancel);
  if (!ref.mounted) throw ApiError(status: 0, code: 'REQUEST_CANCELLED');
  if (sessions.timeZone != zone) throw ApiError.invalidResponse(MentorScheduleApi.errorCode);
  final byClass = {for (final item in classes) item.id: item};
  final entries = <TeachingEntry>[];
  final visible = query.window == MentorScheduleWindow.substitute
      ? sessions.sessions.where((session) => session.isSubstitute).toList()
      : sessions.sessions;
  // Context có phòng và kiểm tra lại assignment; không bắn N request không giới hạn.
  for (var offset = 0; offset < visible.length; offset += 3) {
    final batch = visible.skip(offset).take(3);
    final enriched = await Future.wait(
      batch.map((session) async {
        final classroom = byClass[session.classId];
        if (classroom == null) throw ApiError.invalidResponse(MentorScheduleApi.errorCode);
        final room = await roomApi.room(session.id, cancel: cancel);
        if (room.session.version != session.version) {
          throw ApiError(status: 409, code: 'SESSION_VERSION_CONFLICT');
        }
        return TeachingEntry(
          session: session,
          className: classroom.name,
          classCode: classroom.code,
          roomName: room.roomName,
        );
      }),
    );
    entries.addAll(enriched);
  }
  return TeachingSchedule(entries: entries, timeZone: zone);
});

const mentorHomeQuery = (window: MentorScheduleWindow.today, day: null);
const mentorSubstituteQuery = (window: MentorScheduleWindow.substitute, day: null);
