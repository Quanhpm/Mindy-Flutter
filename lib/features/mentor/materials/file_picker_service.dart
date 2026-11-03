import 'dart:io' show File, FileSystemException;

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_error.dart';
import 'upload_policy.dart';

final mentorFilePickerProvider = Provider((ref) => MentorFilePicker());

class MentorFilePicker {
  final ImagePicker _imagePicker = ImagePicker();

  Future<PickedUploadFile?> pick(UploadCategory category) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      withData: false,
      allowedExtensions: uploadFileRules.entries
          .where((e) => e.value.category == category)
          .map((e) => e.key)
          .toList(),
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    if (result.files.length != 1) {
      throw ApiError(status: 422, code: 'UPLOAD_FILE_INVALID');
    }
    final file = result.files.single;
    if (file.path == null) {
      throw ApiError(status: 422, code: 'UPLOAD_FILE_UNAVAILABLE');
    }
    final source = File(file.path!);
    final int size;
    try {
      size = await source.length();
    } on FileSystemException {
      throw ApiError(status: 422, code: 'UPLOAD_FILE_UNAVAILABLE');
    }
    final rule = validateUploadFile(file.name, size, category: category);
    return PickedUploadFile(
      name: file.name,
      size: size,
      mimeType: rule.mimeType,
      localPath: source.path,
      openRead: () => source.openRead(),
    );
  }

  Future<PickedUploadFile?> captureDocument() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2800,
      imageQuality: 92,
    );
    if (image == null) return null;
    final source = File(image.path);
    final int size;
    try {
      size = await source.length();
    } on FileSystemException {
      throw ApiError(status: 422, code: 'UPLOAD_FILE_UNAVAILABLE');
    }
    final extension = image.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final name =
        'mindy_document_${DateTime.now().millisecondsSinceEpoch}.$extension';
    final rule = validateUploadFile(name, size, category: UploadCategory.image);
    return PickedUploadFile(
      name: name,
      size: size,
      mimeType: rule.mimeType,
      localPath: source.path,
      openRead: () => source.openRead(),
    );
  }
}
