import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'cloudinary_service.dart';

class StorageService {
  final CloudinaryService _cloudinary = CloudinaryService();

  // Upload file and return download URL
  Future<String?> uploadFile({
    required File file,
    required String path,
    String? fileName,
  }) async {
    try {
      final xFile = XFile(file.path);
      final url = await _cloudinary.uploadImage(xFile, folder: path);
      return url;
    } catch (e) {
      debugPrint('Error uploading to Cloudinary: $e');
      return null;
    }
  }

  // Upload owner document (ID, Tax card, etc.)
  Future<String?> uploadOwnerDocument({
    required File file,
    required String ownerId,
    required String documentType,
  }) async {
    return await uploadFile(
      file: file,
      path: 'owners/$ownerId/documents',
    );
  }

  // Upload stadium image
  Future<String?> uploadStadiumImage({
    required File file,
    required String stadiumId,
    required int imageIndex,
  }) async {
    return await uploadFile(
      file: file,
      path: 'stadiums/$stadiumId/images',
    );
  }

  // Upload tournament cover
  Future<String?> uploadTournamentCover({
    required File file,
    required String tournamentId,
  }) async {
    return await uploadFile(
      file: file,
      path: 'tournaments/$tournamentId',
    );
  }

  // Upload profile picture
  Future<String?> uploadProfilePicture({
    required File file,
    required String userId,
  }) async {
    return await uploadFile(
      file: file,
      path: 'users/$userId',
    );
  }

  // NOTE: Cloudinary delete via client-side is restricted for security.
  // We should implement deletion via a back-end or skip for now if not critical.
  Future<bool> deleteFile(String downloadUrl) async {
    debugPrint('Delete from Cloudinary requested for: $downloadUrl (Not implemented client-side)');
    return true; 
  }
}
