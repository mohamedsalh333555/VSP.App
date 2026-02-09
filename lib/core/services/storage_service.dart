import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  // Active Instance
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload file and return download URL
  Future<String?> uploadFile({
    required File file,
    required String path,
    String? fileName,
  }) async {
    try {
      // Generate unique filename if not provided
      String uploadFileName = fileName ?? DateTime.now().millisecondsSinceEpoch.toString();
      
      // Create reference
      Reference ref = _storage.ref().child('$path/$uploadFileName');
      
      // Upload file
      UploadTask uploadTask = ref.putFile(file);
      
      // Wait for upload to complete
      TaskSnapshot snapshot = await uploadTask;
      
      // Get download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  // Upload owner document (ID, Tax card, etc.)
  Future<String?> uploadOwnerDocument({
    required File file,
    required String ownerId,
    required String documentType, // 'nationalIdFront', 'nationalIdBack', 'taxCard', 'commercialRegister'
  }) async {
    return await uploadFile(
      file: file,
      path: 'owners/$ownerId/documents',
      fileName: '${documentType}_${DateTime.now().millisecondsSinceEpoch}',
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
      fileName: 'image_$imageIndex',
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
      fileName: 'cover',
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
      fileName: 'profile_picture',
    );
  }

  // Delete file
  Future<bool> deleteFile(String downloadUrl) async {
    try {
      Reference ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      return false;
    }
  }

  // Get file metadata
  Future<FullMetadata?> getFileMetadata(String downloadUrl) async {
    try {
      Reference ref = _storage.refFromURL(downloadUrl);
      return await ref.getMetadata();
    } catch (e) {
      debugPrint('Error getting metadata: $e');
      return null;
    }
  }
}
