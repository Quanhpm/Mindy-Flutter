import '../../../core/network/api_error.dart';
import '../../../core/network/file_models.dart';

enum UploadCategory { document, video, image }

/// Port allowlist backend files/domain/file-upload-policy.ts. Chỉ khai báo trước;
/// chữ ký binary và MIME thật vẫn do worker server xác minh sau upload.
class UploadFileRule {
  const UploadFileRule(this.mimeType, this.kind, {this.maxSize = 25 * 1024 * 1024});
  final String mimeType;
  final FileKind kind;
  final int maxSize;
  UploadCategory get category => kind == FileKind.VIDEO
      ? UploadCategory.video
      : kind == FileKind.IMAGE
      ? UploadCategory.image
      : UploadCategory.document;
}

const _text = UploadFileRule('text/plain', FileKind.SOURCE_CODE);
const uploadFileRules = <String, UploadFileRule>{
  'pdf': UploadFileRule('application/pdf', FileKind.PDF),
  'png': UploadFileRule('image/png', FileKind.IMAGE),
  'jpg': UploadFileRule('image/jpeg', FileKind.IMAGE),
  'jpeg': UploadFileRule('image/jpeg', FileKind.IMAGE),
  'docx': UploadFileRule('application/vnd.openxmlformats-officedocument.wordprocessingml.document', FileKind.DOCUMENT),
  'pptx': UploadFileRule(
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    FileKind.PRESENTATION,
  ),
  'xlsx': UploadFileRule('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', FileKind.SPREADSHEET),
  'mp3': UploadFileRule('audio/mpeg', FileKind.AUDIO),
  'mp4': UploadFileRule('video/mp4', FileKind.VIDEO, maxSize: 200 * 1024 * 1024),
  'txt': _text,
  'md': UploadFileRule('text/markdown', FileKind.SOURCE_CODE),
  'csv': UploadFileRule('text/csv', FileKind.SOURCE_CODE),
  'json': UploadFileRule('application/json', FileKind.SOURCE_CODE),
  'js': UploadFileRule('application/javascript', FileKind.SOURCE_CODE),
  'ts': _text,
  'py': _text,
  'java': _text,
  'c': _text,
  'cpp': _text,
  'h': _text,
  'css': UploadFileRule('text/css', FileKind.SOURCE_CODE),
  'sql': _text,
};
UploadFileRule validateUploadFile(String name, int size, {String? declaredMimeType, UploadCategory? category}) {
  if (name.isEmpty ||
      name.length > 250 ||
      name != name.trim() ||
      RegExp(r'[\x00-\x1f\x7f-\x9f/\\]').hasMatch(name) ||
      size < 1) {
    throw ApiError(status: 422, code: 'UPLOAD_FILE_INVALID');
  }
  final dot = name.lastIndexOf('.'), extension = dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
  final rule = uploadFileRules[extension];
  if (rule == null ||
      (declaredMimeType != null && declaredMimeType != rule.mimeType) ||
      (category != null && rule.category != category)) {
    throw ApiError(status: 422, code: 'UPLOAD_FILE_UNSUPPORTED');
  }
  if (size > rule.maxSize) {
    throw ApiError(status: 413, code: 'UPLOAD_FILE_TOO_LARGE');
  }
  return rule;
}

class PickedUploadFile {
  const PickedUploadFile({required this.name, required this.size, required this.mimeType, required this.openRead});
  final String name, mimeType;
  final int size;

  /// Mỗi lần PUT/retry dùng stream mới, không giữ cả video 200 MiB trong RAM.
  final Stream<List<int>> Function() openRead;
}
