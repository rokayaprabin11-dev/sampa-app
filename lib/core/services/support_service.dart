import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_endpoints.dart';

/// A support ticket the user raised from the Help Center, plus the admin's
/// reply once one exists. Mirrors backend/apps/support.
class SupportTicket {
  final int id;
  final String kind;      // support | report | feedback
  final String category;
  final String subject;
  final String message;
  final int? rating;
  final String status;    // open | in_progress | resolved | closed
  final String adminResponse;
  final String respondedByName;
  final DateTime? respondedAt;
  final DateTime? createdAt;

  const SupportTicket({
    required this.id,
    required this.kind,
    required this.category,
    required this.subject,
    required this.message,
    required this.rating,
    required this.status,
    required this.adminResponse,
    required this.respondedByName,
    required this.respondedAt,
    required this.createdAt,
  });

  bool get hasReply => adminResponse.trim().isNotEmpty;

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: j['id'] as int,
        kind: (j['kind'] ?? 'support').toString(),
        category: (j['category'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        message: (j['message'] ?? '').toString(),
        rating: (j['rating'] as num?)?.toInt(),
        status: (j['status'] ?? 'open').toString(),
        adminResponse: (j['admin_response'] ?? '').toString(),
        respondedByName: (j['responded_by_name'] ?? '').toString(),
        respondedAt: DateTime.tryParse((j['responded_at'] ?? '').toString()),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );
}

/// Talks to the support backend: raise a ticket, and list/read your own.
class SupportService {
  SupportService({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  /// Resolved once per process — the build can't change under a running app.
  static String? _cachedVersion;

  String get _platform {
    try {
      return Platform.isIOS ? 'ios' : 'android';
    } catch (_) {
      return '';
    }
  }

  /// The real build, read from the package manifest — not a hand-maintained
  /// constant. A ticket that reports the wrong version is worse than one that
  /// reports none, since triage trusts it.
  Future<String> _appVersion() async {
    if (_cachedVersion != null) return _cachedVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      _cachedVersion = '${info.version}+${info.buildNumber}';
    } catch (e) {
      debugPrint('SupportService: package info unavailable: $e');
      _cachedVersion = '';
    }
    return _cachedVersion!;
  }

  /// Raise a ticket. [kind] is 'support' | 'report' | 'feedback'. Returns the
  /// created ticket (with its id + open status), or null on failure.
  Future<SupportTicket?> submit({
    required String kind,
    required String message,
    String category = '',
    String subject = '',
    String targetType = '',
    int? rating,
  }) async {
    try {
      final data = await _api.post(ApiEndpoints.supportTickets, data: {
        'kind': kind,
        'category': category,
        'subject': subject,
        'message': message,
        if (targetType.isNotEmpty) 'target_type': targetType,
        if (rating != null) 'rating': rating,
        'platform': _platform,
        'app_version': await _appVersion(),
      });
      if (data is Map<String, dynamic>) return SupportTicket.fromJson(data);
      return null;
    } catch (e) {
      debugPrint('SupportService.submit failed: $e');
      return null;
    }
  }

  /// The caller's own tickets, newest first.
  Future<List<SupportTicket>> myTickets() async {
    final data = await _api.get(ApiEndpoints.supportTickets);
    final list = data is Map && data['results'] is List
        ? data['results'] as List
        : (data is List ? data : const []);
    return list
        .whereType<Map<String, dynamic>>()
        .map(SupportTicket.fromJson)
        .toList();
  }
}
