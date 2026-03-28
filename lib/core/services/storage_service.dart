import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadFile({required File file, required String path}) async {
    try {
      // ضغط الصورة تلقائياً يتم عن طريق حزمة flutter_image_compress قبل الإرسال (يفضل إضافتها)
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'), // تحديد النوع
      );
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading to Firebase Storage: $e');
      return null;
    }
  }

  Future<bool> deleteFile(String url) async {
    try {
      if (url.isEmpty || !url.startsWith('http')) return true;
      final ref = _storage.refFromURL(url);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting from Firebase Storage: $e');
      return false;
    }
  }

  Future<String?> uploadProfilePicture({required File file, required String userId, String? oldImageUrl}) async {
    if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
      await deleteFile(oldImageUrl);
    }
    return await uploadFile(file: file, path: 'users/$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
  }

  Future<String?> uploadOwnerDocument({required File file, required String ownerId, required String documentType}) async {
    return await uploadFile(file: file, path: 'owners/$ownerId/documents/$documentType.jpg');
  }
}
