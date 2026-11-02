// ignore_for_file: constant_identifier_names
import 'json.dart';

enum FileKind { PDF, IMAGE, DOCUMENT, PRESENTATION, SPREADSHEET, AUDIO, VIDEO, SOURCE_CODE }

enum FileStatus { PENDING_UPLOAD, PROCESSING, READY, FAILED, DELETED }

Uri httpFileUri(Json j, String key) {
  final uri = Uri.tryParse(j.nonEmpty(key));
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment) {
    j.fail();
  }
  return uri;
}

class BinaryFileSummary {
  const BinaryFileSummary({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.size,
    required this.kind,
  });
  final String id, name, mimeType;
  final int size;
  final FileKind kind;
  factory BinaryFileSummary.fromJson(Json j) {
    final size = j.integer('sizeBytes');
    if (size < 1) {
      j.fail();
    }
    return BinaryFileSummary(
      id: j.uuid('id'),
      name: j.nonEmpty('originalFilename'),
      mimeType: j.nonEmpty('mimeType'),
      size: size,
      kind: j.enumOf('kind', FileKind.values),
    );
  }
}

class FileUploadIntent {
  FileUploadIntent({
    required this.fileId,
    required this.url,
    required Map<String, String> headers,
    required this.uploadExpiresAt,
    required this.intentExpiresAt,
  }) : headers = Map.unmodifiable(headers);
  final String fileId;
  final Uri url;
  final Map<String, String> headers;
  final DateTime uploadExpiresAt, intentExpiresAt;
  factory FileUploadIntent.fromJson(Json j) {
    final headers = j.stringMap('requiredHeaders'),
        put = j.dateTime('uploadUrlExpiresAt'),
        intent = j.dateTime('intentExpiresAt');
    if (headers.isEmpty || put.isAfter(intent)) {
      j.fail();
    }
    for (final entry in headers.entries) {
      if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(entry.key) ||
          RegExp(r'[\r\n]').hasMatch(entry.value) ||
          [
            'cookie',
            'authorization',
            'origin',
            'proxy-authorization',
            'host',
            'connection',
          ].contains(entry.key.toLowerCase())) {
        j.fail();
      }
    }
    return FileUploadIntent(
      fileId: j.uuid('fileId'),
      url: httpFileUri(j, 'uploadUrl'),
      headers: headers,
      uploadExpiresAt: put,
      intentExpiresAt: intent,
    );
  }
}

class FileUploadStatus {
  const FileUploadStatus({
    required this.id,
    required this.courseUnitId,
    required this.name,
    required this.status,
    required this.declaredSize,
    required this.size,
    required this.mimeType,
    required this.kind,
    required this.intentExpiresAt,
    required this.readyAt,
    required this.errorCode,
  });
  final String id, courseUnitId, name;
  final FileStatus status;
  final int declaredSize;
  final int? size;
  final String? mimeType, errorCode;
  final FileKind? kind;
  final DateTime intentExpiresAt;
  final DateTime? readyAt;
  factory FileUploadStatus.fromJson(Json j, String expectedId) {
    final id = j.uuid('id'), status = j.enumOf('status', FileStatus.values), declared = j.integer('declaredSizeBytes');
    final size = j.has('sizeBytes') ? j.integer('sizeBytes') : null, mime = j.strOrNull('mimeType');
    final kind = j.has('kind') ? j.enumOf('kind', FileKind.values) : null, ready = j.dateTimeOrNull('readyAt');
    j.strOrNull('metadataStatus');
    if (id != expectedId ||
        declared < 1 ||
        (size != null && size < 0) ||
        (status == FileStatus.READY &&
            (size != declared || mime == null || mime.isEmpty || kind == null || ready == null))) {
      j.fail();
    }
    return FileUploadStatus(
      id: id,
      courseUnitId: j.uuid('courseUnitId'),
      name: j.nonEmpty('originalFilename'),
      status: status,
      declaredSize: declared,
      size: size,
      mimeType: mime,
      kind: kind,
      intentExpiresAt: j.dateTime('intentExpiresAt'),
      readyAt: ready,
      errorCode: j.strOrNull('errorCode'),
    );
  }
}
