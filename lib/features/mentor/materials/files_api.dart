import '../../../core/network/files_api.dart';
export '../../../core/network/files_api.dart' show FilesApi;

// Tương thích tên cũ cho Mentor, cùng endpoint Files độc lập role.
typedef MentorFilesApi = FilesApi;
final mentorFilesApiProvider = filesApiProvider;
