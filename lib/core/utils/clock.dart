import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chỉ cập nhật đồng hồ trình bày khi app foreground; không cấp quyền từ giờ máy.
final appNowProvider = StreamProvider.autoDispose<DateTime>((ref) {
  final clock = _ForegroundClock();
  ref.onDispose(clock.dispose);
  return clock.stream;
});

class _ForegroundClock with WidgetsBindingObserver {
  final _controller = StreamController<DateTime>();
  Timer? _timer;
  _ForegroundClock() {
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }
  Stream<DateTime> get stream => _controller.stream;
  void _sync() {
    _timer?.cancel();
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    _controller.add(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _controller.add(DateTime.now()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _sync();
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.close();
  }
}
