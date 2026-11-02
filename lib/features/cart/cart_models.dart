import '../../core/network/json.dart';
import '../courses/courses_models.dart';

const cartError = 'INVALID_CART_RESPONSE';

/// `modules/cart/schemas/cart.schema.ts`
class CartItem {
  const CartItem({
    required this.classId,
    required this.classCode,
    required this.className,
    required this.courseId,
    required this.courseTitle,
    required this.deliveryMode,
    required this.startDate,
    required this.endDate,
    required this.priceSnapshot,
    required this.currentPriceAmount,
    required this.isPurchasable,
  });

  final String classId;
  final String classCode;
  final String className;
  final String courseId;
  final String courseTitle;
  final DeliveryMode deliveryMode;
  final String startDate;
  final String endDate;
  final int priceSnapshot;
  final int currentPriceAmount;
  final bool isPurchasable;

  bool get priceChanged => priceSnapshot != currentPriceAmount;

  factory CartItem.fromJson(Json j) {
    j.dateTime('addedAt');
    return CartItem(
      classId: j.uuid('classId'),
      classCode: j.str('classCode'),
      className: j.str('className'),
      courseId: j.uuid('courseId'),
      courseTitle: j.str('courseTitle'),
      deliveryMode: j.enumOf('deliveryMode', DeliveryMode.values),
      startDate: j.day('startDate'),
      endDate: j.day('endDate'),
      priceSnapshot: j.amount('priceSnapshot'),
      currentPriceAmount: j.amount('currentPriceAmount'),
      isPurchasable: j.boolean('isPurchasable'),
    );
  }
}

class Cart {
  const Cart({this.items = const [], this.totalAmount = 0});
  final List<CartItem> items;
  final int totalAmount;

  static const maxItems = 20;
  static const empty = Cart();

  /// Lớp đang có trong giỏ của 1 khoá (mỗi khoá tối đa 1 lớp)
  String? classIdOfCourse(String courseId) {
    for (final i in items) {
      if (i.courseId == courseId) return i.classId;
    }
    return null;
  }

  factory Cart.fromJson(Json j) {
    final items = j.list('items', CartItem.fromJson);
    if (items.length > maxItems) j.fail();
    return Cart(items: items, totalAmount: j.amount('totalAmount'));
  }
}
