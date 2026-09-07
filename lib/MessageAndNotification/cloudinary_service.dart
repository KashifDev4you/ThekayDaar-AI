import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Uploads images to Cloudinary using an unsigned upload preset and
/// returns the `secure_url` to store as a plain string in Firestore.
///
/// Unsigned presets are convenient for getting started, but anyone who
/// knows your cloud name + preset name can upload through it. For
/// production, point this at a Cloud Function that performs a signed
/// upload instead, and keep the same uploadImage() signature so the
/// rest of the app doesn't change.
class CloudinaryService {
  CloudinaryService({required this.cloudName, required this.uploadPreset});

  final String cloudName;
  final String uploadPreset;

  Future<String> uploadImage(File imageFile) async {
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    final streamedResponse = await request.send();
    final body = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      throw Exception('Cloudinary upload failed (${streamedResponse.statusCode}): $body');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    return data['secure_url'] as String;
  }
}