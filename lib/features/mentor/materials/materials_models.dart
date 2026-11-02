// ignore_for_file: constant_identifier_names
import '../../../core/network/file_models.dart';
import '../../../core/network/json.dart';
import '../classes/classes_models.dart';

enum MaterialContentType { ARTICLE, FILE, VIDEO }

enum MaterialReviewStatus { DRAFT, PENDING_REVIEW, APPROVED, REJECTED }

enum MaterialFileRole { PRIMARY, INLINE_IMAGE, ATTACHMENT }

class MentorMaterial {
  const MentorMaterial({
    required this.id,
    required this.courseUnitId,
    required this.type,
    required this.title,
    required this.description,
    required this.revision,
    required this.reviewStatus,
    required this.approvedRevision,
    required this.createdBy,
    required this.classId,
    required this.firstApprovedAt,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.rejectionReason,
    required this.canEdit,
    required this.file,
  });
  final String id, courseUnitId, title, createdBy;
  final String? description, classId, rejectionReason;
  final MaterialContentType type;
  final MaterialReviewStatus reviewStatus;
  final int revision;
  final int? approvedRevision;
  final DateTime? firstApprovedAt, publishedAt;
  final DateTime createdAt, updatedAt;
  final bool canEdit;
  final BinaryFileSummary? file;
  bool get published =>
      reviewStatus == MaterialReviewStatus.APPROVED && approvedRevision == revision && publishedAt != null;
  bool ownEditable(String userId, String classId) =>
      canEdit &&
      createdBy == userId &&
      this.classId == classId &&
      firstApprovedAt == null &&
      [MaterialReviewStatus.DRAFT, MaterialReviewStatus.REJECTED].contains(reviewStatus);
  factory MentorMaterial.fromJson(Json j) {
    final revision = j.integer('revision'),
        approved = j.has('approvedRevision') ? j.integer('approvedRevision') : null,
        sort = j.integer('sortOrder');
    final type = j.enumOf('contentType', MaterialContentType.values),
        review = j.enumOf('reviewStatus', MaterialReviewStatus.values);
    final file = j.has('file') ? BinaryFileSummary.fromJson(j.obj('file')) : null;
    if (revision < 1 ||
        (approved != null && (approved < 1 || approved > revision)) ||
        sort < 0 ||
        ((type == MaterialContentType.ARTICLE) != (file == null)) ||
        (type == MaterialContentType.VIDEO && (file?.kind != FileKind.VIDEO || file?.mimeType != 'video/mp4')) ||
        (type == MaterialContentType.FILE && file?.kind == FileKind.VIDEO)) {
      j.fail();
    }
    j.uuidOrNull('sessionId');
    j.dateTimeOrNull('availableAt');
    j.uuidOrNull('reviewedBy');
    j.dateTimeOrNull('reviewedAt');
    return MentorMaterial(
      id: j.uuid('id'),
      courseUnitId: j.uuid('courseUnitId'),
      type: type,
      title: j.nonEmpty('title'),
      description: j.strOrNull('description'),
      revision: revision,
      reviewStatus: review,
      approvedRevision: approved,
      createdBy: j.uuid('createdBy'),
      classId: j.uuidOrNull('createdInClassId'),
      firstApprovedAt: j.dateTimeOrNull('firstApprovedAt'),
      publishedAt: j.dateTimeOrNull('publishedAt'),
      createdAt: j.dateTime('createdAt'),
      updatedAt: j.dateTime('updatedAt'),
      rejectionReason: j.strOrNull('rejectionReason'),
      canEdit: j.boolean('canEdit'),
      file: file,
    );
  }
}

class MentorMaterialDetail {
  MentorMaterialDetail({
    required this.material,
    required this.html,
    required List<BinaryFileSummary> inlineImages,
    required List<BinaryFileSummary> attachments,
  }) : inlineImages = List.unmodifiable(inlineImages),
       attachments = List.unmodifiable(attachments);
  final MentorMaterial material;
  final String? html;
  final List<BinaryFileSummary> inlineImages, attachments;
  factory MentorMaterialDetail.fromJson(Json j) {
    final material = MentorMaterial.fromJson(j), html = j.strOrNull('contentHtml');
    if (material.type == MaterialContentType.ARTICLE) {
      if (html == null || j.integer('contentSchemaVersion') != 1) {
        j.fail();
      }
    } else if (html != null || j.has('contentSchemaVersion')) {
      j.fail();
    }
    final images = j.list('inlineImages', BinaryFileSummary.fromJson),
        attachments = j.list('attachments', BinaryFileSummary.fromJson);
    if (images.map((f) => f.id).toSet().length != images.length ||
        attachments.length > 50 ||
        attachments.map((f) => f.id).toSet().length != attachments.length ||
        attachments.any((f) => f.id == material.file?.id) ||
        images.any((file) => file.kind != FileKind.IMAGE) ||
        (material.type != MaterialContentType.ARTICLE && images.isNotEmpty)) {
      j.fail();
    }
    return MentorMaterialDetail(material: material, html: html, inlineImages: images, attachments: attachments);
  }
}

class MaterialFileAccess {
  const MaterialFileAccess({
    required this.materialId,
    required this.fileId,
    required this.revision,
    required this.role,
    required this.url,
    required this.expiresAt,
  });
  final String materialId, fileId;
  final int revision;
  final MaterialFileRole role;
  final Uri url;
  final DateTime expiresAt;
  factory MaterialFileAccess.fromJson(
    Json j, {
    required String materialId,
    required String fileId,
    required int revision,
  }) {
    if (j.uuid('materialId') != materialId ||
        j.uuid('fileId') != fileId ||
        j.integer('revision') != revision ||
        revision < 1) {
      j.fail();
    }
    return MaterialFileAccess(
      materialId: materialId,
      fileId: fileId,
      revision: revision,
      role: j.enumOf('role', MaterialFileRole.values),
      url: httpFileUri(j, 'url'),
      expiresAt: j.dateTime('expiresAt'),
    );
  }
}

class UnitMaterials {
  UnitMaterials({required this.unit, required List<MentorMaterial> items}) : items = List.unmodifiable(items);
  final MentorUnit unit;
  final List<MentorMaterial> items;
}

class MentorMaterials {
  MentorMaterials({required this.workspace, required List<UnitMaterials> groups}) : groups = List.unmodifiable(groups);
  final MentorWorkspace workspace;
  final List<UnitMaterials> groups;
  int get publishedCount => groups.fold(0, (sum, group) => sum + group.items.where((m) => m.published).length);
}
