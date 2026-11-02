import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/json.dart';
import '../../../core/network/pagination.dart';
import 'classes_models.dart';

final mentorClassesApiProvider = Provider((ref) => MentorClassesApi(ref.watch(apiClientProvider)));

class MentorClassesApi {
  MentorClassesApi(this._api);
  final ApiClient _api;
  static const errorCode = 'INVALID_MENTOR_CLASSES_RESPONSE';

  Future<List<MentorClass>> all({MentorClassFilter? assignment, MentorClassStatus? status, CancelToken? cancel}) =>
      readAllPages(
        (page) async => Paged.fromJson(
          Json(
            await _api.get(
              'mentor/classes',
              query: {'assignment': assignment?.name ?? 'ANY', 'status': status?.name, 'page': page, 'pageSize': 100},
              cancel: cancel,
            ),
            errorCode,
          ),
          MentorClass.fromJson,
        ),
        idOf: (item) => item.id,
        errorCode: errorCode,
      );
}
