import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/session/session_controller.dart';

final mentorDismissedNoticesProvider = AsyncNotifierProvider<MentorDismissedNotices, Set<String>>(
  MentorDismissedNotices.new,
);

class MentorDismissedNotices extends AsyncNotifier<Set<String>> {
  String get _key => 'mentor_dismissed_${ref.read(sessionProvider).user?.id}';
  @override
  Future<Set<String>> build() async {
    ref.watch(sessionEpochProvider);
    final key = _key;
    final preferences = await SharedPreferences.getInstance();
    return Set.unmodifiable(preferences.getStringList(key) ?? const <String>[]);
  }

  Future<void> dismiss(String sessionId) async {
    final key = _key;
    final epoch = ref.read(sessionEpochProvider);
    final next = {...state.value ?? <String>{}, sessionId}.toList();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(key, next.skip(next.length > 100 ? next.length - 100 : 0).toList());
    if (!ref.mounted || ref.read(sessionEpochProvider) != epoch) return;
    state = AsyncData(Set.unmodifiable(next));
  }
}
