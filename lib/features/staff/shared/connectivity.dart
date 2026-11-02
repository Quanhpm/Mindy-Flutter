import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final _connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield (await connectivity.checkConnectivity()).contains(
    ConnectivityResult.none,
  );
  yield* connectivity.onConnectivityChanged
      .map((results) => results.contains(ConnectivityResult.none))
      .distinct();
});

/// `NetInfo`: mất kết nối khóa thao tác ghi; có mạng lại thì query đọc lại.
final staffOfflineProvider = Provider<bool>(
  (ref) => ref.watch(_connectivityProvider).value ?? false,
);
