import 'dart:async';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mindy_flutter/core/network/api_client.dart';
import 'package:mindy_flutter/core/network/api_error.dart';
import 'package:mindy_flutter/core/network/file_models.dart';
import 'package:mindy_flutter/core/network/upload_client.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_models.dart';
import 'package:mindy_flutter/features/mentor/classes/classes_providers.dart';
import 'package:mindy_flutter/features/mentor/materials/files_api.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_api.dart';
import 'package:mindy_flutter/features/mentor/materials/materials_models.dart';
import 'package:mindy_flutter/features/mentor/materials/upload_policy.dart';
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
    kind: currentStatus == FileStatus.READY ? validateUploadFile(name, size).kind : null,
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
  MemoryFilesApi? files;
  final rows = <MentorMaterialDetail>[];
  int creates = 0, lists = 0, details = 0;
  bool loseCreateResponse = false, loseCreateBeforeCommit = false;
  Object? createError;
  int commandCalls = 0, accesses = 0;
  int? failCommandAt;
  int failLists = 0;
  Object? commandError;
  bool loseCommandResponse = false;
  Completer<void>? commandGate;
  final commands = <({String kind, String id, int revision})>[];
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
    final ready = files?.current?.fileId == body['fileId'] ? files!.value : null;
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
          name: ready?.name ?? 'Bai hoc.pdf',
          mimeType: ready?.mimeType ?? (video ? 'video/mp4' : 'application/pdf'),
          size: ready?.size ?? 4,
          kind: ready?.kind ?? (video ? FileKind.VIDEO : FileKind.PDF),
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
    if (failLists > 0) {
      failLists--;
      throw ApiError.network();
    }
    return rows
        .where((r) => r.material.courseUnitId == unit.courseUnitId && _visible(r.material, classId))
        .map((r) => r.material)
        .toList();
  }

  @override
  Future<MentorMaterialDetail> detail(String classId, String id, {CancelToken? cancel}) async {
    details++;
    final row = _row(id);
    if (!_visible(row.material, classId)) {
      throw ApiError(status: 403, code: 'MATERIAL_ACCESS_DENIED');
    }
    return row;
  }

  bool _visible(MentorMaterial m, String classId) =>
      m.published || (m.createdBy == previewMentor.id && m.classId == classId);
  MentorMaterialDetail _row(String id) =>
      rows.where((r) => r.material.id == id).firstOrNull ?? (throw ApiError(status: 404, code: 'MATERIAL_NOT_FOUND'));
  Future<MentorMaterialDetail> _before(String kind, String classId, MentorMaterial material) async {
    commandCalls++;
    commands.add((kind: kind, id: material.id, revision: material.revision));
    if (commandGate != null) {
      await commandGate!.future;
    }
    if (failCommandAt == commandCalls) {
      throw commandError ?? ApiError.network();
    }
    final row = _row(material.id), m = row.material;
    if (m.revision != material.revision) {
      throw ApiError(status: 409, code: 'MATERIAL_REVIEW_CONFLICT');
    }
    if (!m.ownEditable(previewMentor.id, classId)) {
      throw ApiError(status: 403, code: 'MATERIAL_ACCESS_DENIED');
    }
    return row;
  }

  MentorMaterialDetail _after(MentorMaterialDetail old, MentorMaterial next) {
    final detail = MentorMaterialDetail(
      material: next,
      html: old.html,
      inlineImages: old.inlineImages,
      attachments: old.attachments,
    );
    rows[rows.indexOf(old)] = detail;
    if (loseCommandResponse) {
      loseCommandResponse = false;
      throw ApiError.network();
    }
    return detail;
  }

  @override
  Future<MentorMaterialDetail> patch(
    String classId,
    MentorMaterial material, {
    required String title,
    required String? description,
  }) async {
    final row = await _before('edit', classId, material);
    return _after(
      row,
      copyPreviewMaterial(
        row.material,
        title: title,
        description: description,
        clearDescription: description == null,
        revision: row.material.revision + 1,
        status: MaterialReviewStatus.DRAFT,
      ),
    );
  }

  @override
  Future<MentorMaterialDetail> submit(String classId, MentorMaterial material, {CancelToken? cancel}) async {
    final row = await _before('submit', classId, material);
    if (row.material.reviewStatus != MaterialReviewStatus.DRAFT) {
      throw ApiError(status: 409, code: 'MATERIAL_REVIEW_CONFLICT');
    }
    return _after(row, copyPreviewMaterial(row.material, status: MaterialReviewStatus.PENDING_REVIEW));
  }

  @override
  Future<void> delete(String classId, MentorMaterial material) async {
    final row = await _before('delete', classId, material);
    rows.remove(row);
    if (loseCommandResponse) {
      loseCommandResponse = false;
      throw ApiError.network();
    }
  }

  @override
  Future<MaterialFileAccess> access(
    String classId,
    MentorMaterial material,
    String fileId, {
    CancelToken? cancel,
  }) async {
    final detail = await this.detail(classId, material.id, cancel: cancel), m = detail.material;
    accesses++;
    if (m.revision != material.revision) {
      throw ApiError(status: 409, code: 'MATERIAL_REVIEW_CONFLICT');
    }
    final role = m.file?.id == fileId
        ? MaterialFileRole.PRIMARY
        : detail.inlineImages.any((f) => f.id == fileId)
        ? MaterialFileRole.INLINE_IMAGE
        : detail.attachments.any((f) => f.id == fileId)
        ? MaterialFileRole.ATTACHMENT
        : null;
    if (role == null || (!m.published && m.firstApprovedAt != null)) {
      throw ApiError(status: 403, code: 'MATERIAL_ACCESS_DENIED');
    }
    return MaterialFileAccess(
      materialId: m.id,
      fileId: fileId,
      revision: m.revision,
      role: role,
      url: Uri.parse('https://storage.example.test/$fileId?access=$accesses'),
      expiresAt: previewNow.add(const Duration(minutes: 1)),
    );
  }
}

MentorMaterial copyPreviewMaterial(
  MentorMaterial m, {
  String? title,
  String? description,
  bool clearDescription = false,
  int? revision,
  MaterialReviewStatus? status,
}) => MentorMaterial(
  id: m.id,
  courseUnitId: m.courseUnitId,
  type: m.type,
  title: title ?? m.title,
  description: clearDescription ? null : description ?? m.description,
  revision: revision ?? m.revision,
  reviewStatus: status ?? m.reviewStatus,
  approvedRevision: status == null ? m.approvedRevision : null,
  createdBy: m.createdBy,
  classId: m.classId,
  firstApprovedAt: m.firstApprovedAt,
  publishedAt: status == null ? m.publishedAt : null,
  createdAt: m.createdAt,
  updatedAt: previewNow,
  rejectionReason: status == null ? m.rejectionReason : null,
  canEdit:
      (status ?? m.reviewStatus) == MaterialReviewStatus.DRAFT ||
      (status ?? m.reviewStatus) == MaterialReviewStatus.REJECTED,
  file: m.file,
);

MentorMaterialDetail sampleMaterial(
  int index, {
  MaterialReviewStatus status = MaterialReviewStatus.DRAFT,
  bool article = false,
  bool published = false,
  bool shared = false,
}) {
  final approved = status == MaterialReviewStatus.APPROVED;
  return MentorMaterialDetail(
    material: MentorMaterial(
      id: fixtureId(800 + index),
      courseUnitId: fixtureId(21),
      type: article ? MaterialContentType.ARTICLE : MaterialContentType.FILE,
      title: article ? 'Bài đọc: My first trip abroad' : 'Unit 5 · Worksheet $index.pdf',
      description: article ? 'Đọc bài và trả lời các câu hỏi cuối bài.' : 'Tài liệu luyện tập sau buổi học.',
      revision: 1,
      reviewStatus: status,
      approvedRevision: approved ? 1 : null,
      createdBy: shared ? previewPrimaryMentor.id : previewMentor.id,
      classId: shared ? null : fixtureClassId,
      firstApprovedAt: approved ? previewNow : null,
      publishedAt: published ? previewNow : null,
      createdAt: previewNow.subtract(Duration(days: index)),
      updatedAt: previewNow,
      rejectionReason: status == MaterialReviewStatus.REJECTED ? 'Bổ sung đáp án cho phần câu hỏi đọc hiểu.' : null,
      canEdit: !shared && [MaterialReviewStatus.DRAFT, MaterialReviewStatus.REJECTED].contains(status),
      file: article
          ? null
          : BinaryFileSummary(
              id: fixtureId(900 + index),
              name: 'Worksheet $index.pdf',
              mimeType: 'application/pdf',
              size: 2457600,
              kind: FileKind.PDF,
            ),
    ),
    html: article
        ? '<h2>My first trip abroad</h2><p>I visited a new city with my family. We <strong>learned</strong> about local traditions.</p><h3>Questions</h3><ol><li>Where did the family go?</li><li>What did they learn?</li></ol><p><a href="https://example.test/reading">Further reading</a></p>'
        : null,
    inlineImages: [],
    attachments: [],
  );
}

MemoryMaterialsApi sampleMaterialsApi() => MemoryMaterialsApi()
  ..rows.addAll([
    sampleMaterial(1),
    sampleMaterial(2),
    sampleMaterial(3, status: MaterialReviewStatus.REJECTED, article: true),
    sampleMaterial(4, status: MaterialReviewStatus.PENDING_REVIEW),
    sampleMaterial(5, status: MaterialReviewStatus.APPROVED, published: true),
    sampleMaterial(6, status: MaterialReviewStatus.APPROVED, published: true, shared: true, article: true),
    sampleMaterial(7, status: MaterialReviewStatus.APPROVED),
  ]);
MentorWorkspace materialWorkspace(String id) {
  final m = sampleWorkspace(id: id), item = sampleClasses().where((c) => c.id == id).firstOrNull;
  return MentorWorkspace(
    id: id,
    code: item?.code ?? m.code,
    name: item?.name ?? m.name,
    courseId: m.courseId,
    courseTitle: m.courseTitle,
    status: item?.status ?? m.status,
    scope: m.scope,
    assignment: m.assignment,
    readonly: item?.status == MentorClassStatus.COMPLETED || item?.status == MentorClassStatus.CANCELLED,
    readClass: true,
    readRoster: true,
    readReports: true,
    authorMaterials: item?.status != MentorClassStatus.CANCELLED,
    unitCount: 1,
    sessionCount: 6,
    timeZone: m.timeZone,
    asOf: m.asOf,
  );
}

List<MentorUnit> materialUnits(String id) => [
  MentorUnit(
    id: id == fixtureClassId ? fixtureId(20) : fixtureId(40),
    classId: id,
    courseUnitId: fixtureId(21),
    title: 'Unit 5 · At work',
    position: 1,
    status: MentorUnitStatus.OPEN,
    unlockAt: null,
  ),
];
List<Override> materialsPreviewOverrides({MemoryMaterialsApi? api, MemoryFilesApi? files, MemoryUploadClient? upload}) {
  final f = files ?? MemoryFilesApi(), m = api ?? sampleMaterialsApi();
  m.files = f;
  return [
    mentorPrimaryWorkspaceProvider.overrideWith((ref, id) async => materialWorkspace(id)),
    mentorClassUnitsProvider.overrideWith((ref, id) async => materialUnits(id)),
    mentorMaterialsApiProvider.overrideWithValue(m),
    mentorFilesApiProvider.overrideWithValue(f),
    uploadClientProvider.overrideWithValue(upload ?? MemoryUploadClient()),
  ];
}
