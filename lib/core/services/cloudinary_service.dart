import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

class CloudinaryService {
  // من Cloudinary Dashboard
  static const String _cloudName = 'du0qye54d';    // غيّرها لو مختلف
  static const String _uploadPreset = 'vsp_unsigned';

  Future<String> uploadImage(
    XFile file, {
    String folder = 'vsp_app',
  }) async {
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
}
