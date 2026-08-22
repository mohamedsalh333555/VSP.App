import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseStorageClient _storage = Supabase.instance.client.storage;

  String _getMimeType(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.heic':
        return 'image/heic';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String?> uploadFile({required XFile file, required String bucket, required String path}) async {
    final size = await file.length();
    if (size > 10 * 1024 * 1024) {
      throw Exception('File is too large. Please select a file under 10MB.');
    }

    try {
      String uploadPath = path;
      final mimeType = _getMimeType(file.name);
      
      if (kIsWeb) {
        // Web flow: upload via bytes to bypass dart:io File
        final bytes = await file.readAsBytes();
        await _storage.from(bucket).uploadBinary(
          uploadPath,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );
      } else {
        // Mobile/Desktop flow: compress and upload via File
        File finalFile = File(file.path);
        final extension = p.extension(file.path).toLowerCase();
        
        if (['.jpg', '.jpeg', '.png', '.heic'].contains(extension)) {
          final tempDir = await getTemporaryDirectory();

          // 🛡️ FIX: Preserve PNG transparency — use CompressFormat.png for .png files.
          // Using CompressFormat.jpeg on a PNG with transparency fills the alpha channel
          // with a solid black background. We must never convert .png to .jpeg.
          final bool isPng = extension == '.png';
          final CompressFormat compressFormat = isPng ? CompressFormat.png : CompressFormat.jpeg;
          final String outputExt = isPng ? 'png' : 'jpg';
          final int quality = isPng ? 100 : 70; // PNG is lossless; quality=100 retains all data.

          final targetPath = p.join(tempDir.path, "compressed_${DateTime.now().millisecondsSinceEpoch}.$outputExt");

          // Only rename .heic → .jpg (not .png → .jpg)
          if (uploadPath.toLowerCase().endsWith('.heic')) {
            uploadPath = uploadPath.replaceAll(RegExp(r'\.heic$', caseSensitive: false), '.jpg');
          }

          final compressedXFile = await FlutterImageCompress.compressAndGetFile(
            finalFile.absolute.path,
            targetPath,
            format: compressFormat,
            quality: quality,
          );
          
          if (compressedXFile != null) {
            finalFile = File(compressedXFile.path);
          }
        }

        await _storage.from(bucket).upload(
          uploadPath,
          finalFile,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );
      }

      final publicUrl = _storage.from(bucket).getPublicUrl(uploadPath);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading to Supabase Storage: $e');
      return null;
    }
  }

  Future<bool> deleteFile(String url) async {
    try {
      if (url.isEmpty || !url.startsWith('http')) return true;

      final storagePathMarker = '/storage/v1/object/public/';
      if (url.contains(storagePathMarker)) {
        final pathSegment = url.split(storagePathMarker).last;
        final parts = pathSegment.split('/');
        if (parts.length > 1) {
          final bucket = parts.first;
          final path = parts.sublist(1).join('/');
          await _storage.from(bucket).remove([path]);
          return true;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting from Supabase Storage: $e');
      return false;
    }
  }

  Future<String?> uploadProfilePicture({required XFile file, required String userId, String? oldImageUrl}) async {
    if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
      await deleteFile(oldImageUrl);
    }
    return await uploadFile(
      file: file, 
      bucket: 'profile-pictures', 
      path: '$userId/profile_${DateTime.now().millisecondsSinceEpoch}.jpg'
    );
  }

  Future<String?> uploadOwnerDocument({required XFile file, required String ownerId, required String documentType}) async {
    final ext = p.extension(file.name).toLowerCase();
    return await uploadFile(
      file: file, 
      // 🛡️ BLOCKER FIX: Unified bucket name to match the SQL migration.
      // supabase_atomic_booking.sql creates 'owner_documents', not 'verification-documents'.
      bucket: 'owner_documents', 
      path: '$ownerId/documents/$documentType$ext'
    );
  }

  Future<String?> getOwnerDocumentSignedUrl(String path, {int expiresIn = 3600}) async {
    try {
      String cleanPath = path;
      final storagePathMarker = '/storage/v1/object/public/owner_documents/';
      final signedMarker = '/storage/v1/object/sign/owner_documents/';
      if (cleanPath.contains(storagePathMarker)) {
        cleanPath = cleanPath.split(storagePathMarker).last;
      } else if (cleanPath.contains(signedMarker)) {
        cleanPath = cleanPath.split(signedMarker).last.split('?').first;
      }
      return await _storage.from('owner_documents').createSignedUrl(cleanPath, expiresIn);
    } catch (e) {
      debugPrint('Error generating owner document signed URL: $e');
      return null;
    }
  }
}
