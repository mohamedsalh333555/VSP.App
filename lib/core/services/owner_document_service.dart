import 'package:image_picker/image_picker.dart' show XFile;
import '../repositories/user_repository.dart';
import 'storage_service.dart';

export '../repositories/user_repository.dart' show OwnerDocumentType;

class OwnerDocumentService {
  final StorageService _storage;
  final UserRepository _userRepository;

  OwnerDocumentService({
    StorageService? storage,
    UserRepository? userRepository,
  }) : _storage = storage ?? StorageService(),
       _userRepository = userRepository ?? UserRepository();

  Future<String> uploadAndSave({
    required OwnerDocumentType type,
    required XFile file,
    required String uid,
  }) async {
    // 1) رفع الملف على Storage
    final url = await _storage.uploadOwnerDocument(
      file: file,
      ownerId: uid,
      documentType: type.name,
    );
    if (url == null) throw 'Upload failed';

    // 2) تفويض التحديث في قاعدة البيانات إلى UserRepository عبر الواجهة المكتوبة بقوة والمحمية
    await _userRepository.updateVerificationDocument(uid, type, url);

    return url;
  }
}
