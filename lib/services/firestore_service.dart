import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ali_app/profile_sub_pages/project_model.dart';
import 'package:ali_app/model/notification_model.dart';
import 'package:ali_app/model/help_support_model.dart';

/// Central service for all Firestore reads used by the account/profile menu.
/// Adjust collection paths (`_projectsCollection`, etc.) to match your DB.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ---------------------------------------------------------------------
  // 1) MY PROJECTS
  // Real structure: top-level `projects` collection, each doc has a
  // `clientId` field equal to the client's Firestore doc ID (which is the
  // Firebase Auth UID, e.g. "Y7qBykZmCaZbt5UycEYUmc9XiOk2").
  // ---------------------------------------------------------------------

  Stream<List<ProjectModel>> streamMyProjects() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('projects')
        .where('clientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ProjectModel.fromFirestore(d)).toList());
  }

  Future<List<ProjectModel>> fetchMyProjectsOnce() async {
    final uid = _uid;
    if (uid == null) return [];

    final snap = await _db
        .collection('projects')
        .where('clientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => ProjectModel.fromFirestore(d)).toList();
  }

  // ---------------------------------------------------------------------
  // 2) NOTIFICATIONS
  // This collection doesn't exist yet. Created as a top-level `notifications`
  // collection to match the pattern of your other collections (payment_requests,
  // escalations, access_requests), each doc carrying a `recipientId` field
  // equal to the client's/theekaydaar's doc ID (Firebase Auth UID).
  //
  // Suggested fields when writing a notification doc elsewhere in your app:
  //   recipientId: string (uid)
  //   title: string
  //   message: string
  //   type: string   e.g. "bid_received", "payment", "project_update"
  //   isRead: bool
  //   createdAt: Timestamp (use FieldValue.serverTimestamp())
  // ---------------------------------------------------------------------

  Stream<List<NotificationModel>> streamNotifications() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();

    return _db
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => NotificationModel.fromFirestore(d)).toList());
  }

  Future<List<NotificationModel>> fetchNotificationsOnce() async {
    final uid = _uid;
    if (uid == null) return [];

    final snap = await _db
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs.map((d) => NotificationModel.fromFirestore(d)).toList();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _db
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Helper to create a notification doc elsewhere in your app
  /// (e.g. when a bid is placed or a payment request is sent).
  Future<void> createNotification({
    required String recipientId,
    required String title,
    required String message,
    String type = 'general',
  }) async {
    await _db.collection('notifications').add({
      'recipientId': recipientId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------
  // 3) HELP & SUPPORT
  // Assumes this is a shared, app-wide collection (not user-scoped):
  // help_support/{docId}
  // ---------------------------------------------------------------------

  Stream<List<HelpSupportModel>> streamHelpSupport() {
    return _db
        .collection('help_support')
        .orderBy('category')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => HelpSupportModel.fromFirestore(d)).toList());
  }

  Future<List<HelpSupportModel>> fetchHelpSupportOnce() async {
    final snap = await _db.collection('help_support').orderBy('category').get();
    return snap.docs.map((d) => HelpSupportModel.fromFirestore(d)).toList();
  }
}