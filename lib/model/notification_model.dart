import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single notification document from the `notifications` collection.
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime? createdAt;
  final String? type; // e.g. "payment", "project_update", "system"

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdAt,
    this.type,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      type: data['type'],
    );
  }
}