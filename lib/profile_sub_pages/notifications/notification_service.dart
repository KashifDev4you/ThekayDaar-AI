// =============================================================================
// notification_service.dart
//
// Client-side access to the `notifications` collection.
//
// NOTE: originally notifications were meant to be created server-side by
// Cloud Functions, but no functions are deployed in this project — so the
// create() helpers below write notification docs directly from the client
// whenever a key event happens (new bid, bid accepted, hire request,
// contract/payment updates). This keeps the whole notification system
// working with a Firestore-only backend.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ali_app/profile_sub_pages/notifications/notification_model.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('notifications');

  // ── CREATE ───────────────────────────────────────────────
  // Fire-and-forget: callers don't need to await or handle errors.

  /// Generic creator used by every typed helper below.
  Future<void> create({
    required String targetUid,
    required String type,
    required String title,
    required String message,
    Map<String, dynamic> data = const {},
  }) async {
    if (targetUid.isEmpty) return;
    try {
      await _col.add({
        'uid': targetUid,
        'type': type,
        'title': title,
        'message': message,
        'data': data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Never let a notification failure break the main flow.
    }
  }

  /// Contractor placed a bid on the client's project.
  Future<void> notifyNewBid({
    required String clientUid,
    required String contractorName,
    required String projectTitle,
    required String amount,
    required String projectId,
  }) =>
      create(
        targetUid: clientUid,
        type: 'new_bid',
        title: 'New Bid Received',
        message:
            '$contractorName placed a bid of Rs $amount on "$projectTitle".',
        data: {'projectId': projectId},
      );

  /// Client accepted a contractor's bid.
  Future<void> notifyBidAccepted({
    required String contractorUid,
    required String clientName,
    required String projectTitle,
    required String amount,
    required String projectId,
  }) =>
      create(
        targetUid: contractorUid,
        type: 'bid_accepted',
        title: 'Congratulations! Bid Accepted',
        message:
            '$clientName accepted your bid of Rs $amount on "$projectTitle". You are hired!',
        data: {'projectId': projectId},
      );

  /// Client sent a hire request from the contractor's gig.
  Future<void> notifyHireRequest({
    required String contractorUid,
    required String clientName,
    required String gigTitle,
    required String hireRequestId,
  }) =>
      create(
        targetUid: contractorUid,
        type: 'hire_request',
        title: 'New Hire Request',
        message: '$clientName wants to hire you for "$gigTitle". Review and respond.',
        data: {'hireRequestId': hireRequestId},
      );

  /// A project's status changed (completed, cancelled, disputed…).
  Future<void> notifyProjectUpdate({
    required String targetUid,
    required String projectTitle,
    required String status,
    required String projectId,
  }) =>
      create(
        targetUid: targetUid,
        type: 'project_update',
        title: 'Project Update',
        message: 'Project "$projectTitle" is now marked as $status.',
        data: {'projectId': projectId, 'status': status},
      );

  /// A new chat message arrived (used when recipient isn't in the chat).
  Future<void> notifyNewMessage({
    required String recipientUid,
    required String senderName,
    required String preview,
    required String chatId,
  }) =>
      create(
        targetUid: recipientUid,
        type: 'chat_message',
        title: 'New Message',
        message: '$senderName: $preview',
        data: {'chatId': chatId},
      );

  /// Contract created, signed, or milestone approved.
  Future<void> notifyContractUpdate({
    required String targetUid,
    required String contractTitle,
    required String event,
    required String contractId,
  }) =>
      create(
        targetUid: targetUid,
        type: 'contract_update',
        title: 'Contract Update',
        message: '$contractTitle — $event.',
        data: {'contractId': contractId},
      );

  /// Payment submitted / approved / released.
  Future<void> notifyPayment({
    required String targetUid,
    required String event,
    required String amount,
    required String projectId,
  }) =>
      create(
        targetUid: targetUid,
        type: 'payment_approved',
        title: 'Payment Update',
        message: '$event — Rs $amount.',
        data: {'projectId': projectId},
      );

  // ── READ ─────────────────────────────────────────────────

  /// Full notification list for the current user, newest first.
  ///
  /// NOTE: this query (uid == + orderBy createdAt) needs a composite index.
  /// The first time you run it, Firestore will throw an error in the console
  /// with a direct "create index" link — click it once and it's done.
  Stream<List<NotificationModel>> streamNotifications({int limit = 100}) {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _col
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => NotificationModel.fromDoc(d)).toList());
  }

  /// Just the most recent few, for the bell dropdown.
  Stream<List<NotificationModel>> streamRecent({int limit = 8}) =>
      streamNotifications(limit: limit);

  /// Live unread count, for the badge on the bell icon.
  Stream<int> streamUnreadCount() {
    final uid = _uid;
    if (uid == null) return Stream.value(0);
    return _col
        .where('uid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markAsRead(String notificationId) =>
      _col.doc(notificationId).update({'isRead': true});

  Future<void> markAllAsRead() async {
    final uid = _uid;
    if (uid == null) return;
    final unread = await _col
        .where('uid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> delete(String notificationId) =>
      _col.doc(notificationId).delete();

  /// Call this right after a password change succeeds
  /// (e.g. after `FirebaseAuth.instance.currentUser!.updatePassword(...)`
  /// completes without error).
  Future<void> logPasswordChanged() async {
    final uid = _uid;
    if (uid == null) return;
    await create(
      targetUid: uid,
      type: 'password_changed',
      title: 'Password Changed',
      message: 'Your account password was changed successfully.',
    );
  }
}