import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'cloudinary_service.dart';

enum OwnerDocumentType {
  commercialRegister,
  nationalIdFront,
  nationalIdBack,
  taxCard,
}

class OwnerDocumentService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  Future<String> uploadAndSave({
    required OwnerDocumentType type,
    required String filePath,
    required String uid,
  }) async {
    // 1) رفع الملف على Cloudinary
    final folder = 'users/$uid/documents';
    final url = await _cloudinary.uploadRawFile(filePath, folder: folder);

    // 2) تحديد اسم الحقل في Firestore
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

    // 3) حفظ الـ URL في users/{uid}.verificationDocuments
    await _firestore.collection('users').doc(uid).set({
      'verificationDocuments': {
        fieldName: url,
      },
      'verificationStatus': 'pending',
    }, SetOptions(merge: true));

    return url;
  }
}
