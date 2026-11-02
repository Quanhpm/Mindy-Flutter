import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// read(future) không giữ autoDispose provider qua các frame. Lệnh đang chạy cần
/// listener tới khi đọc xong, kể cả khi sheet không có widget watch nguồn đó.
Future<T> awaitProvider<T>(Ref ref, ProviderListenable<Future<T>> provider) async {
  final subscription = ref.listen(provider, (_, _) {});
  try {
    return await subscription.read();
  } finally {
    subscription.close();
  }
}

Future<T> awaitWidgetProvider<T>(WidgetRef ref, ProviderListenable<Future<T>> provider) async {
  final subscription = ref.listenManual(provider, (_, _) {});
  try {
    return await subscription.read();
  } finally {
    subscription.close();
  }
}
