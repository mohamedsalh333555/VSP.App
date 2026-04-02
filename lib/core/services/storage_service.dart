import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadFile({required File file, required String path}) async {
    try {
      // 🚀 Image Compression Optimization
      File finalFile = file;
      final extension = p.extension(file.path).toLowerCase();
      
      if (['.jpg', '.jpeg', '.png', '.heic'].contains(extension)) {
        final tempDir = await getTemporaryDirectory();
        final targetPath = p.join(tempDir.path, "compressed_${DateTime.now().millisecondsSinceEpoch}$extension");
        
        final compressedXFile = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: 70, // Significant savings with minimal loss
        );
        
        if (compressedXFile != null) {
          finalFile = File(compressedXFile.path);
        }
      }

      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(
        finalFile,
        SettableMetadata(contentType: 'image/jpeg'), 
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
