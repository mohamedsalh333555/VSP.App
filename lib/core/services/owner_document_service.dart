import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:io';
import 'storage_service.dart';

enum OwnerDocumentType {
  commercialRegister,
  nationalIdFront,
  nationalIdBack,
  taxCard,
}

class OwnerDocumentService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final StorageService _storage = StorageService();

  Future<String> uploadAndSave({
    required OwnerDocumentType type,
    required String filePath,
    required String uid,
  }) async {
    // 1) رفع الملف على Storage
    final url = await _storage.uploadOwnerDocument(
        file: File(filePath),
        ownerId: uid,
        documentType: type.name,
    );
    if (url == null) throw 'Upload failed';

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
