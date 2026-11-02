// ignore_for_file: constant_identifier_names
import '../../core/network/json.dart';

const _err = 'INVALID_CATALOG_RESPONSE';

enum DeliveryMode { ONLINE, OFFLINE }

/// Lớp mở sớm nhất của khoá (hiện "KG dd/MM" trên thẻ khoá học)
class OpenClass {
  const OpenClass({required this.startDate, required this.deliveryMode});
  final String startDate; // YYYY-MM-DD
  final DeliveryMode deliveryMode;
}

/// `courseSchema` (home/schemas/homeResponse.schema.ts)
class Course {
  const Course({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.imgUrl,
    required this.priceAmount,
    required this.categoryId,
    required this.categoryName,
    this.openClass,
  });

  final String id;
  final String code;
  final String title;
  final String? description;
  final String? imgUrl;
  final int priceAmount;
  final String categoryId;
  final String categoryName;
  final OpenClass? openClass;

  Course withOpenClass(OpenClass? c) => Course(
        id: id,
        code: code,
        title: title,
        description: description,
        imgUrl: imgUrl,
        priceAmount: priceAmount,
        categoryId: categoryId,
        categoryName: categoryName,
        openClass: c,
      );

  factory Course.fromJson(Json j) {
    final img = j.strOrNull('imgUrl');
    if (img != null && !RegExp(r'^https?://').hasMatch(img)) j.fail();
    final cat = j.obj('category');
    return Course(
      id: j.uuid('id'),
      code: j.nonEmpty('code'),
      title: j.nonEmpty('title'),
      description: j.strOrNull('description'),
      imgUrl: img,
      priceAmount: j.amount('priceAmount'),
      categoryId: cat.uuid('id'),
      categoryName: cat.str('name'),
    );
  }
}

class CourseCategory {
  const CourseCategory({required this.id, required this.name, required this.isActive});
  final String id;
  final String name;
  final bool isActive;

  factory CourseCategory.fromJson(Json j) =>
      CourseCategory(id: j.uuid('id'), name: j.nonEmpty('name'), isActive: j.boolean('isActive'));
}

/// Lớp của khoá - `classSchema` (catalog.schema.ts)
class CourseClass {
  const CourseClass({
    required this.id,
    required this.courseId,
    required this.code,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.deliveryMode,
    required this.availableSeats,
    required this.mentorName,
  });

  final String id;
  final String courseId;
  final String code;
  final String name;
  final String startDate;
  final String endDate;
  final DeliveryMode deliveryMode;
  final int availableSeats;
  final String mentorName;

  bool get isFull => availableSeats <= 0;

  factory CourseClass.fromJson(Json j) {
    final seats = j.integer('availableSeats');
    if (seats < 0) j.fail();
    return CourseClass(
      id: j.uuid('id'),
      courseId: j.uuid('courseId'),
      code: j.nonEmpty('code'),
      name: j.nonEmpty('name'),
      startDate: j.day('startDate'),
      endDate: j.day('endDate'),
      deliveryMode: j.enumOf('deliveryMode', DeliveryMode.values),
      availableSeats: seats,
      mentorName: j.obj('mentor').str('displayName'),
    );
  }

  static const errorCode = _err;
}
