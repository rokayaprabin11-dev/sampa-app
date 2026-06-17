import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import '../network/api_client.dart';
import '../network/api_constants.dart';

class OfflinePackDownloadService {
  final Dio _dio;
  final ApiClient? _apiClient;
  static const int _chunkSize = 5 * 1024 * 1024; // 5 MB

  OfflinePackDownloadService(this._dio, [this._apiClient]);

  Future<List<Map<String, dynamic>>> getMyDownloads() async {
    if (_apiClient == null) return [];
    final data = await _apiClient!.get(ApiEndpoints.downloads);
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> initiateDistrictDownload(int districtId) async {
    if (_apiClient == null) throw Exception('ApiClient not provided');
    final data = await _apiClient!.post(
      ApiEndpoints.downloads,
      data: {'district_id': districtId},
    );
    return data as Map<String, dynamic>;
  }

  Future<void> removeDistrictDownload(int districtId) async {
    if (_apiClient == null) return;
    await _apiClient!.delete('${ApiEndpoints.downloads}$districtId/');
  }

  /// Downloads [url] to [destPath] in 5MB chunks with resume support.
  Future<void> downloadWithResume({
    required String url,
    required String destPath,
    required ValueChanged<double> onProgress,
  }) async {
    final file = File(destPath);
    int downloadedBytes = file.existsSync() ? file.lengthSync() : 0;

    // Get total size
    final headResp = await _dio.head(url);
    final totalBytes =
        int.tryParse(headResp.headers.value('content-length') ?? '') ?? 0;

    if (downloadedBytes >= totalBytes && totalBytes > 0) {
      onProgress(1.0);
      return; // Already complete
    }

    final sink = file.openWrite(mode: FileMode.append);
    try {
      while (downloadedBytes < totalBytes) {
        final end = (downloadedBytes + _chunkSize - 1).clamp(0, totalBytes - 1);
        final response = await _dio.get<List<int>>(
          url,
          options: Options(
            responseType: ResponseType.bytes,
            headers: {'Range': 'bytes=$downloadedBytes-$end'},
          ),
        );
        sink.add(response.data!);
        downloadedBytes += response.data!.length;
        onProgress(downloadedBytes / totalBytes);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  Future<void> verifyChecksum(String filePath, String expectedSha256) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    final actual = digest.toString();

    if (actual != expectedSha256.toLowerCase()) {
      await file.delete();
      throw Exception('Checksum mismatch: expected $expectedSha256 but got $actual');
    }
  }
}







