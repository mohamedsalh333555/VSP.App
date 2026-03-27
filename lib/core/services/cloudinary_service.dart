import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class CloudinaryService {
  // من Cloudinary Dashboard
  static const String _cloudName = 'du0qye54d';    // غيّرها لو مختلف
  static const String _uploadPreset = 'vsp_unsigned';

  // TODO: CRITICAL SECURITY - Implement "Signed Uploads" via Firebase Cloud Function
  // Unsigned uploads for ID cards and sensitive contracts are a critical security risk.
  // The client should request a signature payload from our backend before calling Cloudinary.

  // SECURITY PATCH: Enforce strict file extensions for images to prevent malicious script uploads.
  Future<String> uploadImage(
    XFile file, {
    String folder = 'vsp_app',
  }) async {
    // SECURITY: Validate extension before upload
    final ext = p.extension(file.path).toLowerCase();
    if (!['.jpg', '.jpeg', '.png'].contains(ext)) {
      throw Exception('Security Error: Unauthorized file extension ($ext)');
    }

    // SECURITY: Validate file size (max 5MB)
    final fileSize = await File(file.path).length();
    if (fileSize > 5 * 1024 * 1024) {
      throw Exception('File size exceeds 5MB limit. Please choose a smaller image.');
    }
    final uploadUrl = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uploadUrl)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: p.basename(file.path),
        ),
      );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Cloudinary upload failed: ${response.statusCode} $body');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }

  // SECURITY PATCH: Strict extension checking for sensitive document uploads (e.g. Identity/Contracts).
  Future<String> uploadRawFile(
    String filePath, {
    String folder = 'vsp_app',
  }) async {
    final extension = p.extension(filePath).toLowerCase();
    // SECURITY: Explicitly allow only PDF and Safe Images
    if (!['.jpg', '.jpeg', '.png', '.pdf'].contains(extension)) {
      throw Exception('Security Error: Forbidden file type ($extension)');
    }

    final isPdfOrImage = ['.jpg', '.jpeg', '.png', '.pdf'].contains(extension);
    final resourceType = isPdfOrImage ? 'image' : 'raw';
    
    final uploadUrl = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload',
    );

    final request = http.MultipartRequest('POST', uploadUrl)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = folder
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: p.basename(filePath),
        ),
      );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Cloudinary upload failed: ${response.statusCode} $body');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }
}
