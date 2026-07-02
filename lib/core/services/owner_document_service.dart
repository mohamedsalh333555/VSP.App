import 'package:image_picker/image_picker.dart' show XFile;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';

enum OwnerDocumentType {
  commercialRegister,
  nationalIdFront,
  nationalIdBack,
  taxCard,
}

class OwnerDocumentService {
  final _supabase = Supabase.instance.client;
  final StorageService _storage = StorageService();

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

    // 2) تحديد اسم الحقل
    String fieldName;
    switch (type) {
      case OwnerDocumentType.commercialRegister:
        fieldName = 'commercialRegisterUrl';
        break;
      case OwnerDocumentType.nationalIdFront:
        fieldName = 'nationalIdFrontUrl';
        break;
      case OwnerDocumentType.nationalIdBack:
        fieldName = 'nationalIdBackUrl';
        break;
      case OwnerDocumentType.taxCard:
        fieldName = 'taxCardUrl';
        break;
    }

    // 3) جلب الـ additional_data الحالي لتعديل الـ verificationDocuments داخله
    final response = await _supabase
        .from('users')
        .select('additional_data')
        .eq('id', uid)
        .maybeSingle();

    final additionalData = Map<String, dynamic>.from(response?['additional_data'] ?? {});
    final verificationDocuments = Map<String, dynamic>.from(additionalData['verificationDocuments'] ?? {});
    verificationDocuments[fieldName] = url;
    additionalData['verificationDocuments'] = verificationDocuments;

    // 4) تحديث الحقل في جدول users
    await _supabase.from('users').update({
      'additional_data': additionalData,
      'verificationStatus': 'pending',
      'verification_status': 'pending',
    }).eq('id', uid);

    return url;
  }
}
