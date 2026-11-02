import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/session/session_controller.dart';
import '../../core/network/json.dart';
import 'manager_api.dart';
import 'manager_models.dart';

enum ManagerUtility { leaves, materials, collections, classes, mentors, students, incomplete, reports, makeup }

extension ManagerUtilityView on ManagerUtility {
  String get labelKey => 'manager.utility.$name';
  IconData get icon => switch (this) {
    ManagerUtility.leaves => Icons.event_note,
    ManagerUtility.materials => Icons.folder_open,
    ManagerUtility.collections => Icons.payments_outlined,
    ManagerUtility.classes => Icons.school_outlined,
    ManagerUtility.mentors => Icons.person_outline,
    ManagerUtility.students => Icons.groups_outlined,
    ManagerUtility.incomplete => Icons.pending_actions,
    ManagerUtility.reports => Icons.bar_chart,
    ManagerUtility.makeup => Icons.event_available,
  };
}

const managerFixedFavorites = [ManagerUtility.leaves, ManagerUtility.materials, ManagerUtility.collections];
final managerFavoritesProvider = AsyncNotifierProvider<ManagerFavorites, List<ManagerUtility>>(ManagerFavorites.new);

class ManagerFavorites extends AsyncNotifier<List<ManagerUtility>> {
  @override
  Future<List<ManagerUtility>> build() async {
    ref.watch(sessionEpochProvider);
    final user = ref.watch(sessionProvider).user;
    if (user == null) return managerFixedFavorites;
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList('manager_favorites_${user.id}') ?? [];
    final items = [
      ...managerFixedFavorites,
      ...ManagerUtility.values.where((u) => !managerFixedFavorites.contains(u) && names.contains(u.name)),
    ];
    return List.unmodifiable(items.take(6));
  }

  Future<void> toggle(ManagerUtility u) async {
    if (managerFixedFavorites.contains(u)) return;
    final epoch = ref.read(sessionEpochProvider), user = ref.read(sessionProvider).user;
    if (user == null) return;
    final values = List<ManagerUtility>.of(state.value ?? managerFixedFavorites);
    if (values.contains(u)) {
      values.remove(u);
    } else {
      if (values.length >= 6) return;
      values.add(u);
    }
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return;
    try {
      await prefs.setStringList('manager_favorites_${user.id}', values.map((u) => u.name).toList());
      if (ref.mounted && ref.read(sessionEpochProvider) == epoch) state = AsyncData(List.unmodifiable(values));
    } catch (error, trace) {
      if (ref.mounted && ref.read(sessionEpochProvider) == epoch) state = AsyncError(error, trace);
    }
  }
}

final managerCoursesProvider = FutureProvider.autoDispose<List<ManagedCourse>>((ref) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerApiProvider).courses(cancel: c);
});
final managerCourseProvider = FutureProvider.autoDispose.family<ManagedCourse, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerApiProvider).course(id, cancel: c);
});
final managerPeopleProvider = FutureProvider.autoDispose.family<List<ManagerPerson>, ({String role, String search})>((
  ref,
  q,
) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerApiProvider).people(q.role, q.search, cancel: c);
});
final managerPersonProvider = FutureProvider.autoDispose.family<ManagerPerson, ({String role, String id})>((ref, q) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerApiProvider).person(q.role, q.id, cancel: c);
});
final managerClassesProvider = FutureProvider.autoDispose
    .family<List<ManagedClass>, ({String? mentorId, String search})>((ref, q) {
      ref.watch(sessionEpochProvider);
      final c = CancelToken();
      ref.onDispose(c.cancel);
      return ref.watch(managerApiProvider).classes(mentorId: q.mentorId, search: q.search, cancel: c);
    });
final managerClassDetailProvider = FutureProvider.autoDispose.family<ManagedClassDetail, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerApiProvider).classDetail(id, cancel: c);
});
final managerClassUnitsProvider = FutureProvider.autoDispose.family<List<ManagedUnit>, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerApiProvider).classUnits(id, cancel: c);
});
final managerStudentClassesProvider = FutureProvider.autoDispose.family<List<ManagerStudentClass>, String>((ref, id) {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  return ref.watch(managerApiProvider).studentClasses(id, cancel: c);
});

final managerZoneProvider = FutureProvider<String>((ref) async {
  ref.watch(sessionEpochProvider);
  final c = CancelToken();
  ref.onDispose(c.cancel);
  final data = await ref
      .watch(managerApiProvider)
      .client
      .get('management/class-sessions/incomplete', query: {'page': 1, 'pageSize': 1}, cancel: c);
  return managerZone(Json(data, managerErrorCode));
});
