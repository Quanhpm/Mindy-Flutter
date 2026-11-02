// ignore_for_file: constant_identifier_names
import 'dart:convert';
import '../../../core/network/file_models.dart';
import '../../../core/network/json.dart';

export '../../../core/network/file_models.dart';

enum StaffMaterialType { FILE, VIDEO, ARTICLE }

enum ReviewStatus { DRAFT, PENDING_REVIEW, APPROVED, REJECTED }

class StaffMaterial {
  StaffMaterial(Json j, {bool detail = false})
    : id = j.uuid('id'),
      unitId = j.uuid('courseUnitId'),
      type = j.enumOf('contentType', StaffMaterialType.values),
      title = j.str('title'),
      description = j.strOrNull('description'),
      revision = j.integer('revision'),
      status = j.enumOf('reviewStatus', ReviewStatus.values),
      createdBy = j.uuid('createdBy'),
      classId = j.uuidOrNull('createdInClassId'),
      editable = j.boolean('canEdit'),
      firstApprovedAt = j.dateTimeOrNull('firstApprovedAt'),
      publishedAt = j.dateTimeOrNull('publishedAt'),
      reviewedAt = j.dateTimeOrNull('reviewedAt'),
      updatedAt = j.dateTime('updatedAt'),
      availableAt = j.dateTimeOrNull('availableAt'),
      rejectionReason = j.strOrNull('rejectionReason'),
      file = j.objOrNull('file') == null
          ? null
          : BinaryFileSummary.fromJson(j.obj('file')),
      html = detail ? j.strOrNull('contentHtml') : null,
      inlineImages = detail
          ? j.list('inlineImages', BinaryFileSummary.fromJson)
          : const [],
      attachments = detail
          ? j.list('attachments', BinaryFileSummary.fromJson)
          : const [] {
    j.integer('sortOrder');
    j.uuidOrNull('sessionId');
    j.uuidOrNull('reviewedBy');
    j.dateTime('createdAt');
    if (revision < 1 ||
        (j.has('approvedRevision') && j.integer('approvedRevision') < 1)) {
      j.fail();
    }
    if (detail && j.has('contentSchemaVersion')) {
      j.integer('contentSchemaVersion');
    }
  }
  final String id, unitId, title, createdBy;
  final String? description, classId, rejectionReason, html;
  final StaffMaterialType type;
  final ReviewStatus status;
  final int revision;
  final bool editable;
  final DateTime? firstApprovedAt, publishedAt, reviewedAt, availableAt;
  final DateTime updatedAt;
  final BinaryFileSummary? file;
  final List<BinaryFileSummary> inlineImages, attachments;
  bool get canEdit =>
      editable &&
      firstApprovedAt == null &&
      [ReviewStatus.DRAFT, ReviewStatus.REJECTED].contains(status);
  String get stateLabel => status == ReviewStatus.APPROVED
      ? publishedAt == null
            ? 'unpublished'
            : 'published'
      : status.name;
}

const materialMimes = {
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'mp3': 'audio/mpeg',
  'mp4': 'video/mp4',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'csv': 'text/csv',
  'json': 'application/json',
  'js': 'text/javascript',
  'css': 'text/css',
  'ts': 'text/plain',
  'py': 'text/plain',
  'java': 'text/plain',
  'c': 'text/plain',
  'cpp': 'text/plain',
  'h': 'text/plain',
  'sql': 'text/plain',
};
String? materialFileError(String name, int size, StaffMaterialType type) {
  final ext = name.split('.').last.toLowerCase();
  if (name.isEmpty ||
      name.length > 250 ||
      name.trim() != name ||
      RegExp(r'[\x00-\x1f\x7f-\x9f\\/]').hasMatch(name)) {
    return 'badName';
  }
  if (size < 1) return 'unreadable';
  if (!materialMimes.containsKey(ext)) return 'unsupported';
  if ((type == StaffMaterialType.VIDEO) != (ext == 'mp4')) return 'wrongType';
  if (size > (type == StaffMaterialType.VIDEO ? 200 : 25) * 1024 * 1024) {
    return 'tooLarge';
  }
  return null;
}

String escapeArticle(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
String plainArticleHtml(String s) =>
    '<p>${escapeArticle(s).replaceAll(RegExp(r'\r\n?'), '\n').replaceAll('\n', '<br>')}</p>';
int articleBytes(String s) => utf8.encode(s).length;
