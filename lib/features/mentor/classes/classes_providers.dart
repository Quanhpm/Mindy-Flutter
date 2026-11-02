import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_controller.dart';
import 'classes_api.dart';
import 'classes_models.dart';

final mentorClassesProvider = FutureProvider.autoDispose<List<MentorClass>>((ref) {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  return ref.watch(mentorClassesApiProvider).all(cancel: cancel);
});
