import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_endpoints.dart';

/// One live position, streamed from a participant's `positions/<uid>` doc.
class LivePosition {
  final double lat;
  final double lng;
  final double? accuracyM;
  final double? heading;
  final DateTime? updatedAt;

  const LivePosition({
    required this.lat,
    required this.lng,
    this.accuracyM,
    this.heading,
    this.updatedAt,
  });

  LatLng get point => LatLng(lat, lng);

  static LivePosition? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    final lat = (data['lat'] as num?)?.toDouble();
    final lng = (data['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LivePosition(
      lat: lat,
      lng: lng,
      accuracyM: (data['accuracy_m'] as num?)?.toDouble(),
      heading: (data['heading'] as num?)?.toDouble(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
    );
  }
}

/// What Django says about a booking's tracking channel. Obtained from the
/// backend, never guessed: the channel id is only meaningful if Django agrees the
/// booking authorizes sharing (confirmed, not yet completed/cancelled).
class TrackChannel {
  final String channelId;
  final int bookingId;
  final String myUid;
  final String otherUid;
  final String otherName;
  final String otherRole;
  final bool writable;
  final String state; // 'active' | 'ended'

  const TrackChannel({
    required this.channelId,
    required this.bookingId,
    required this.myUid,
    required this.otherUid,
    required this.otherName,
    required this.otherRole,
    required this.writable,
    required this.state,
  });

  bool get isActive => state == 'active';
}

/// Mutual live-location tracking over Firestore — the sibling of [ChatService].
///
/// Division of labour, identical to chat:
///   * Django authorizes (is the booking confirmed?) and opens the channel.
///   * Firestore carries the positions — real-time, with an offline cache, so
///     the map keeps rendering the last-known point through a brief drop.
///   * Firestore security rules enforce membership AND the active-only window on
///     every write, so a client cannot leak a location outside a live tour or
///     write a position as the other party.
///
/// This class never elevates its own access: it reads the channel from the
/// backend and writes only its own `positions/<uid>` doc as the signed-in user.
class TrackingService {
  TrackingService({required ApiClient apiClient, FirebaseFirestore? firestore})
      : _apiClient = apiClient,
        _db = firestore ?? FirebaseFirestore.instance;

  final ApiClient _apiClient;
  final FirebaseFirestore _db;

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Asks Django whether this booking has an active tracking channel and who the
  /// other party is. Returns null when it doesn't (pending, ended, not a
  /// participant, or a participant has no Firebase identity).
  Future<TrackChannel?> openChannel(int bookingId) async {
    try {
      final data = await _apiClient.get(ApiEndpoints.bookingTracking(bookingId));
      if (data is! Map) return null;
      final other = (data['other_party'] as Map?) ?? const {};
      return TrackChannel(
        channelId: data['channel_id'] as String,
        bookingId: bookingId,
        myUid: (data['my_uid'] ?? '').toString(),
        otherUid: (other['uid'] ?? '').toString(),
        otherName: (other['name'] ?? '').toString(),
        otherRole: (other['role'] ?? '').toString(),
        writable: (data['writable'] as bool?) ?? false,
        state: (data['state'] ?? 'ended').toString(),
      );
    } catch (e) {
      debugPrint('TrackingService.openChannel($bookingId) refused: $e');
      return null;
    }
  }

  /// Writes this user's live position. Guarded by the rules to the caller's own
  /// uid and to an active channel, so a stale timer firing after the tour ends
  /// is rejected at the edge rather than leaking a location.
  Future<void> pushPosition(
    String channelId, {
    required String uid,
    required double lat,
    required double lng,
    double? accuracyM,
    double? heading,
  }) async {
    try {
      await _db
          .collection('tracking')
          .doc(channelId)
          .collection('positions')
          .doc(uid)
          .set({
        'lat': lat,
        'lng': lng,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (heading != null) 'heading': heading,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Permission-denied here is the expected, correct behaviour once the tour
      // ends (state flipped to 'ended'). Swallow — the screen watches state and
      // stops on its own.
      debugPrint('TrackingService.pushPosition failed (likely tour ended): $e');
    }
  }

  /// Live stream of the other participant's position, served from Firestore's
  /// cache first then reconciled — the reason this isn't a REST poll.
  Stream<LivePosition?> peerPosition(String channelId, String otherUid) {
    if (otherUid.isEmpty) return const Stream.empty();
    return _db
        .collection('tracking')
        .doc(channelId)
        .collection('positions')
        .doc(otherUid)
        .snapshots()
        .map((doc) => LivePosition.fromMap(doc.data()));
  }

  /// Live stream of the channel state ('active' | 'ended'). The screen watches
  /// this to stop sending and receiving the instant Django ends the tour.
  Stream<String> channelState(String channelId) {
    return _db
        .collection('tracking')
        .doc(channelId)
        .snapshots()
        .map((doc) => (doc.data()?['state'] ?? 'ended').toString());
  }
}
