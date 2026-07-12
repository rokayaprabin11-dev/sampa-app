import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/network/api_endpoints.dart';

/// One message in a booking chat.
class ChatMessage {
  final String id;
  final String from;
  final String text;
  final DateTime? sentAt;

  /// True while the write is still in flight (Firestore hands us the document
  /// optimistically from its local cache before the server acknowledges it).
  final bool isPending;

  const ChatMessage({
    required this.id,
    required this.from,
    required this.text,
    required this.sentAt,
    required this.isPending,
  });

  factory ChatMessage.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return ChatMessage(
      id: doc.id,
      from: (data['from'] ?? '') as String,
      text: (data['text'] ?? '') as String,
      sentAt: (data['sent_at'] as Timestamp?)?.toDate(),
      isPending: doc.metadata.hasPendingWrites,
    );
  }
}

/// What the backend says about a booking's chat. Obtained from Django, never
/// guessed by the client: the channel id is only meaningful if Django agrees the
/// booking authorizes it.
class ChatChannel {
  final String channelId;
  final int bookingId;
  final bool writable;

  const ChatChannel({
    required this.channelId,
    required this.bookingId,
    required this.writable,
  });
}

/// Booking chat over Firestore.
///
/// Division of labour:
///   * Django authorizes (is there a confirmed booking?) and opens the channel.
///   * Firestore carries the messages — real-time, with an offline cache, which
///     is why we're on it rather than polling our own REST endpoint.
///   * Firestore security rules enforce membership on every read and write, so a
///     compromised client cannot read someone else's booking chat.
///
/// This class never elevates its own access: it reads the channel id from the
/// backend and writes messages as the signed-in Firebase user.
class ChatService {
  ChatService({required ApiClient apiClient, FirebaseFirestore? firestore})
      : _apiClient = apiClient,
        _db = firestore ?? FirebaseFirestore.instance;

  final ApiClient _apiClient;
  final FirebaseFirestore _db;

  static const int messageMaxLength = 2000;

  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  /// Asks Django whether this booking has a chat and who may use it.
  /// Returns null when it doesn't (booking still pending, not a participant,
  /// or a participant has no Firebase identity).
  Future<ChatChannel?> openChannel(int bookingId) async {
    try {
      final data = await _apiClient.get(ApiEndpoints.bookingChat(bookingId));
      if (data is! Map) return null;
      return ChatChannel(
        channelId: data['channel_id'] as String,
        bookingId: bookingId,
        writable: (data['writable'] as bool?) ?? false,
      );
    } catch (e) {
      debugPrint('ChatService.openChannel($bookingId) refused: $e');
      return null;
    }
  }

  /// Live message stream, oldest first. Firestore serves this from its local
  /// cache first and reconciles with the server, so the thread renders instantly
  /// and survives going offline mid-tour — the reason this isn't a REST poll.
  Stream<List<ChatMessage>> messages(String channelId, {int limit = 200}) {
    return _db
        .collection('chats')
        .doc(channelId)
        .collection('messages')
        .orderBy('sent_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.reversed.map(ChatMessage.fromDoc).toList());
  }

  /// Writes the message to Firestore, then asks Django to push a notification to
  /// the other party. Two steps because there is no Cloud Function to trigger on
  /// the write — and the FCM credentials belong on the server, not in the app.
  ///
  /// The push is best-effort: a delivered message with no push beats a failed
  /// send, so a notify error is swallowed.
  Future<void> send({
    required ChatChannel channel,
    required String text,
  }) async {
    final uid = currentUid;
    final body = text.trim();
    if (uid == null || body.isEmpty) return;

    await _db
        .collection('chats')
        .doc(channel.channelId)
        .collection('messages')
        .add({
      'from': uid,
      'text': body.length > messageMaxLength
          ? body.substring(0, messageMaxLength)
          : body,
      'sent_at': FieldValue.serverTimestamp(),
    });

    try {
      await _apiClient.post(
        ApiEndpoints.bookingChatNotify(channel.bookingId),
        data: {'preview': body},
      );
    } catch (e) {
      debugPrint('ChatService: message sent, push failed: $e');
    }
  }

  /// Stamps this user's read receipt. Each participant may only write their own
  /// (enforced by the rules), which is what makes the other side's "seen" state
  /// trustworthy.
  Future<void> markRead(String channelId) async {
    final uid = currentUid;
    if (uid == null) return;
    try {
      await _db
          .collection('chats')
          .doc(channelId)
          .collection('read_receipts')
          .doc(uid)
          .set({'read_at': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('ChatService.markRead failed: $e');
    }
  }

  /// When the other participant last read the thread — backs the "Seen" marker.
  Stream<DateTime?> otherPartyReadAt(String channelId) {
    final uid = currentUid;
    return _db
        .collection('chats')
        .doc(channelId)
        .collection('read_receipts')
        .snapshots()
        .map((snap) {
      DateTime? latest;
      for (final doc in snap.docs) {
        if (doc.id == uid) continue; // our own receipt proves nothing
        final at = (doc.data()['read_at'] as Timestamp?)?.toDate();
        if (at == null) continue;
        final best = latest;
        if (best == null || at.isAfter(best)) latest = at;
      }
      return latest;
    });
  }
}
