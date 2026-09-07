import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_meta.dart';
import 'package:flutter/foundation.dart';
import 'package:ali_app/profile_sub_pages/notifications/notification_service.dart';

class ChatMetaService {
  static final _db = FirebaseFirestore.instance;

  /// Call this when a client accepts a bid.
  static Future<void> createChat({
    required String jobId,
    required String jobTitle,
    required String clientId,
    required String clientName,
    required String contractorId,
    required String contractorName,
    String? clientPhotoUrl,
    String? contractorPhotoUrl,
  }) async {
    await _db.collection('chats').doc(jobId).set({
      'jobId': jobId,
      'jobTitle': jobTitle,
      'clientId': clientId,
      'clientName': clientName,
      'contractorId': contractorId,
      'contractorName': contractorName,
      'clientPhotoUrl': clientPhotoUrl ?? '',
      'contractorPhotoUrl': contractorPhotoUrl ?? '',
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': '',
      'unreadCounts': {clientId: 0, contractorId: 0},
      'jobStatus': 'active',
      'participants': [clientId, contractorId],
    }, SetOptions(merge: true));
  }

  /// Call this after every sendText / sendImage in ChatService.
  /// Only increments the unread count for the OTHER participant —
  /// never the sender's own badge.
  static Future<void> updateLastMessage({
    required String jobId,
    required String senderId,
    required String preview, // e.g. message text or '📷 Photo'
  }) async {
    final docRef = _db.collection('chats').doc(jobId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final data = snap.data()!;
    final clientId = data['clientId'] as String? ?? '';
    final contractorId = data['contractorId'] as String? ?? '';
    final recipientId = senderId == clientId ? contractorId : clientId;

    await docRef.update({
      'lastMessage': preview,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': senderId,
      'unreadCounts.$recipientId': FieldValue.increment(1),
    });

    // ── Push a notification so the recipient sees it in the bell ──
    // (fires for every text/photo message; notification creation is
    // fire-and-forget and never breaks the send flow)
    final senderName = senderId == clientId
        ? (data['clientName'] as String? ?? 'Client')
        : (data['contractorName'] as String? ?? 'Contractor');
    if (recipientId.isNotEmpty) {
      NotificationService.instance.notifyNewMessage(
        recipientUid: recipientId,
        senderName: senderName,
        preview: preview,
        chatId: jobId,
      );
    }
  }

  /// Call when the user opens a chat to clear their unread badge.
  static Future<void> markRead(String jobId, String currentUserId) async {
    await _db.collection('chats').doc(jobId).update({
      'unreadCounts.$currentUserId': 0,
    });
  }

  /// Stream all chats where current user is a participant.
  static Stream<List<ChatMeta>> watchInbox(String userId) {
    debugPrint('🔥 watchInbox called for userId: $userId');
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .handleError((error) {
          debugPrint('🔥🔥🔥 watchInbox ERROR: $error');
        })
        .map((snap) => snap.docs
            .map((d) => ChatMeta.fromFirestore(d.id, d.data()))
            .toList());
  }

  /// Stream the TOTAL unread count across all of this user's
  /// conversations — use this to drive the bottom-nav badge.
  static Stream<int> watchTotalUnread(String userId) {
    return watchInbox(userId).map(
      (chats) => chats.fold<int>(0, (sum, c) => sum + c.unreadCountFor(userId)),
    );
  }
}