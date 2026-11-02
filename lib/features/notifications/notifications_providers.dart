import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import '../../core/session/session_controller.dart';
import 'notifications_api.dart';
import 'notifications_models.dart';

bool notificationsUnavailable(Object error) => error is ApiError && (error.status == 404 || error.status == 503);

final notificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(sessionEpochProvider);
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  try {
    return await ref.watch(notificationsApiProvider).count(cancel: cancel);
  } catch (error) {
    if (notificationsUnavailable(error)) return 0;
    rethrow;
  }
});

class NotificationFeed {
  const NotificationFeed({required this.page, this.disabled = false});
  final NotificationPage page;
  final bool disabled;
}

final notificationFeedProvider = AsyncNotifierProvider.autoDispose<NotificationFeedController, NotificationFeed>(
  NotificationFeedController.new,
);

class NotificationFeedController extends AsyncNotifier<NotificationFeed> {
  bool _pending = false;
  final _seenCursors = <String>{};
  @override
  Future<NotificationFeed> build() async {
    ref.watch(sessionEpochProvider);
    _pending = false;
    _seenCursors.clear();
    final cancel = CancelToken();
    ref.onDispose(cancel.cancel);
    try {
      return NotificationFeed(page: await ref.watch(notificationsApiProvider).page(cancel: cancel));
    } catch (error) {
      if (notificationsUnavailable(error)) {
        return NotificationFeed(
          page: NotificationPage(items: const [], nextCursor: null, hasMore: false),
          disabled: true,
        );
      }
      rethrow;
    }
  }

  bool _current(int epoch) => ref.mounted && ref.read(sessionEpochProvider) == epoch;
  Future<void> _run(Future<void> Function(int epoch) command) async {
    if (_pending) return;
    _pending = true;
    final epoch = ref.read(sessionEpochProvider);
    try {
      await command(epoch);
    } finally {
      if (_current(epoch)) _pending = false;
    }
  }

  Future<void> read(MindyNotification item) => _run((epoch) async {
    final result = await ref.read(notificationsApiProvider).read(item.id);
    if (!_current(epoch)) return;
    final page = state.value?.page;
    if (page == null) return;
    state = AsyncData(
      NotificationFeed(
        page: NotificationPage(
          items: [for (final n in page.items) n.id == result.id ? result : n],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      ),
    );
    ref.invalidate(notificationCountProvider);
  });

  Future<void> readAll() => _run((epoch) async {
    final api = ref.read(notificationsApiProvider);
    await api.readAll();
    if (!_current(epoch)) return;
    ref.invalidate(notificationCountProvider);
    final page = await api.page();
    if (!_current(epoch)) return;
    _seenCursors.clear();
    state = AsyncData(NotificationFeed(page: page));
  });

  Future<void> loadMore() => _run((epoch) async {
    final before = state.value?.page;
    if (before == null || !before.hasMore) return;
    final cursor = before.nextCursor!;
    if (_seenCursors.contains(cursor)) throw ApiError.invalidResponse(NotificationsApi.errorCode);
    final page = await ref.read(notificationsApiProvider).page(cursor: cursor);
    if (!_current(epoch)) return;
    final ids = before.items.map((item) => item.id).toSet();
    if (page.nextCursor == cursor || page.items.any((item) => !ids.add(item.id))) {
      throw ApiError.invalidResponse(NotificationsApi.errorCode);
    }
    _seenCursors.add(cursor);
    state = AsyncData(
      NotificationFeed(
        page: NotificationPage(
          items: [...before.items, ...page.items],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      ),
    );
  });
}
