import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_endpoints.dart';

/// Uploads an image to Cloudinary through the backend's signed-upload endpoint.
///
/// The signature is minted server-side and is short-lived and folder-scoped, so
/// the app never holds a Cloudinary secret and cannot write outside the folder
/// it asked for. This is the only image upload path in the app; anything that
/// needs to store a picture — a guide's ID card, a payment screenshot — goes
/// through here rather than re-deriving the handshake.
class CloudinaryUploader {
  final ApiClient _api;

  const CloudinaryUploader({required ApiClient apiClient}) : _api = apiClient;

  /// Returns the secure URL of the stored image, or null if Cloudinary accepted
  /// the upload but returned nothing usable.
  Future<String?> upload(XFile file, String folder) async {
    final signature = await _api.post(
      ApiEndpoints.uploadSignature,
      data: {'folder': folder},
    ) as Map<String, dynamic>;

    final bytes = await File(file.path).readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    // Sensitive folders (KYC, payment screenshots) come back with type
    // 'authenticated' — the asset is then private and delivered via a signed
    // URL. It has to be sent because the server folded it into the signature;
    // public folders return an empty type and upload normally.
    final deliveryType = '${signature['type'] ?? ''}';
    final response = await _api.dio.post<Map<String, dynamic>>(
      'https://api.cloudinary.com/v1_1/${signature['cloud_name']}/image/upload',
      data: {
        'file': 'data:image/$ext;base64,${base64Encode(bytes)}',
        'api_key': signature['api_key'],
        'timestamp': signature['timestamp'].toString(),
        'signature': signature['signature'],
        // The folder the *server* signed, not the one we asked for: they are the
        // same, but trusting the signed value is what makes that guaranteed.
        'folder': signature['folder'],
        if (deliveryType.isNotEmpty) 'type': deliveryType,
      },
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
    return response.data?['secure_url'] as String?;
  }
}
