import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/file_models.dart';
import 'package:mindy_flutter/core/network/upload_client.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_models.dart';
import 'package:mindy_flutter/features/mentor/materials/files_api.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_api.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_models.dart';
import 'classes_fixtures.dart';
import 'mentor_fixtures.dart';

/// Storage/worker trong RAM cho debug/test. Không import từ lib/entrypoint release.
class MemoryFilesApi extends MentorFilesApi {
  MemoryFilesApi() : super(ApiClient(cookieJar: CookieJar()));
  int intents = 0, completes = 0, reads = 0, processingReads = 0;
  bool loseCompleteResponse = false, neverReady = false, failProcessing = false;
  int failStatusReads = 0;
  void Function()? onStatus;
  final events = <String>[];
  FileUploadIntent? current;
  FileStatus currentStatus = FileStatus.PENDING_UPLOAD;
  String name = 'Bai hoc.pdf', mime = 'application/pdf', courseUnitId = fixtureId(21);
  int size = 4;
  FileUploadStatus get value => FileUploadStatus(
    id: current!.fileId,
    courseUnitId: courseUnitId,
    name: name,
    status: currentStatus,
    declaredSize: size,
    size: currentStatus == FileStatus.READY ? size : null,
    mimeType: currentStatus == FileStatus.READY ? mime : null,
    kind: currentStatus == FileStatus.READY ? (mime == 'video/mp4' ? FileKind.VIDEO : FileKind.PDF) : null,
    intentExpiresAt: previewNow.add(const Duration(hours: 1)),
    readyAt: currentStatus == FileStatus.READY ? previewNow : null,
    errorCode: currentStatus == FileStatus.FAILED ? 'UPLOAD_FAILED' : null,
  );
  @override
  Future<FileUploadIntent> intent({
    required String classId,
    required String unitId,
    required String courseUnitId,
    required String name,
    required String mimeType,
    required int size,
    required CancelToken cancel,
  }) async {
    intents++;
    events.add('intent');
    this.courseUnitId = courseUnitId;
    this.name = name;
    mime = mimeType;
    this.size = size;
    currentStatus = FileStatus.PENDING_UPLOAD;
    return current = FileUploadIntent(
      fileId: fixtureId(600 + intents),
      url: Uri.parse('https://storage.example.test/upload/$intents'),
      headers: {'content-type': mimeType},
      uploadExpiresAt: previewNow.add(const Duration(minutes: 10)),
      intentExpiresAt: previewNow.add(const Duration(hours: 1)),
    );
  }

  @override
  Future<FileUploadStatus> complete(String id, {CancelToken? cancel}) async {
    completes++;
    events.add('complete');
    currentStatus = FileStatus.PROCESSING;
    if (loseCompleteResponse) {
      loseCompleteResponse = false;
      throw ApiError.network();
    }
    return value;
  }

  @override
  Future<FileUploadStatus> status(String id, {CancelToken? cancel}) async {
    reads++;
    onStatus?.call();
    events.add('status');
    if (failStatusReads > 0) {
      failStatusReads--;
      throw ApiError.network();
    }
    if (currentStatus == FileStatus.PROCESSING && !neverReady) {
      if (processingReads > 0) {
        processingReads--;
      } else {
        currentStatus = failProcessing ? FileStatus.FAILED : FileStatus.READY;
      }
    }
    return value;
  }
}

class MemoryUploadClient extends UploadClient {
  int puts = 0, readBytes = 0;
  Object? failNext;
  Completer<void>? gate;
  final urls = <Uri>[];
  @override
  Future<void> put(
    FileUploadIntent intent,
    Stream<List<int>> bytes,
    int size, {
    required CancelToken cancel,
    required void Function(int, int) onProgress,
  }) async {
    puts++;
    urls.add(intent.url);
    if (failNext != null) {
      final error = failNext!;
      failNext = null;
      throw error;
    }
    if (gate != null) {
      await Future.any<void>([
        gate!.future,
        cancel.whenCancel.then((_) => throw ApiError(status: 0, code: 'UPLOAD_CANCELLED')),
      ]);
    }
    var count = 0;
    await for (final chunk in bytes) {
      count += chunk.length;
      readBytes += chunk.length;
      onProgress(count, size);
    }
  }
}

class MemoryMaterialsApi extends MentorMaterialsApi {
  MemoryMaterialsApi() : super(ApiClient(cookieJar: CookieJar()));
  final rows = <MentorMaterialDetail>[];
  int creates = 0, lists = 0, details = 0;
  bool loseCreateResponse = false, loseCreateBeforeCommit = false;
  Object? createError;
  @override
  Future<MentorMaterialDetail> create(
    String classId,
    MentorUnit unit,
    Map<String, Object?> body, {
    CancelToken? cancel,
  }) async {
    creates++;
    if (createError != null) {
      throw createError!;
    }
    if (loseCreateBeforeCommit) {
      throw ApiError.network();
    }
    final video = body['contentType'] == 'VIDEO';
    final detail = MentorMaterialDetail(
      material: MentorMaterial(
        id: fixtureId(700 + creates),
        courseUnitId: unit.courseUnitId,
        type: video ? MaterialContentType.VIDEO : MaterialContentType.FILE,
        title: body['title']! as String,
        description: body['description'] as String?,
        revision: 1,
        reviewStatus: MaterialReviewStatus.DRAFT,
        approvedRevision: null,
        createdBy: previewMentor.id,
        classId: classId,
        firstApprovedAt: null,
        publishedAt: null,
        createdAt: previewNow,
        updatedAt: previewNow,
        rejectionReason: null,
        canEdit: true,
        file: BinaryFileSummary(
          id: body['fileId']! as String,
          name: 'Bai hoc.pdf',
          mimeType: video ? 'video/mp4' : 'application/pdf',
          size: 4,
          kind: video ? FileKind.VIDEO : FileKind.PDF,
        ),
      ),
      html: null,
      inlineImages: [],
      attachments: [],
    );
    rows.add(detail);
    if (loseCreateResponse) {
      loseCreateResponse = false;
      throw ApiError.network();
    }
    return detail;
  }

  @override
  Future<List<MentorMaterial>> all(String classId, MentorUnit unit, {CancelToken? cancel}) async {
    lists++;
    return rows.where((r) => r.material.courseUnitId == unit.courseUnitId).map((r) => r.material).toList();
  }

  @override
  Future<MentorMaterialDetail> detail(String classId, String id, {CancelToken? cancel}) async {
    details++;
    return rows.singleWhere((r) => r.material.id == id);
  }
}
