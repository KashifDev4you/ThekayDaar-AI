// =============================================================================
// notification_model.dart
//
// Model for docs in the top-level `notifications` collection. Docs are
// created SERVER-SIDE by Cloud Functions (see functions/index.js) — the
// client only reads, marks-as-read, and deletes.
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum NotificationType {
  passwordChanged,
  chatMessage,
  planActivated,
  paymentApproved,
  paymentRejected,
  nicVerified,
  contractUpdate,
  newBid,
  bidAccepted,
  hireRequest,
  projectUpdate,
  generic;

  static NotificationType fromString(String? raw) {
    switch (raw) {
      case 'password_changed':
        return NotificationType.passwordChanged;
      case 'chat_message':
        return NotificationType.chatMessage;
      case 'plan_activated':
        return NotificationType.planActivated;
      case 'payment_approved':
        return NotificationType.paymentApproved;
      case 'payment_rejected':
        return NotificationType.paymentRejected;
      case 'nic_verified':
        return NotificationType.nicVerified;
      case 'contract_update':
        return NotificationType.contractUpdate;
      case 'new_bid':
        return NotificationType.newBid;
      case 'bid_accepted':
        return NotificationType.bidAccepted;
      case 'hire_request':
        return NotificationType.hireRequest;
      case 'project_update':
        return NotificationType.projectUpdate;
      default:
        return NotificationType.generic;
    }
  }
}

class NotificationModel {
  final String id;
  final String uid;
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.uid,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final ts = d['createdAt'];
    return NotificationModel(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      type: NotificationType.fromString(d['type'] as String?),
      title: d['title'] as String? ?? '',
      message: d['message'] as String? ?? '',
      data: (d['data'] as Map<String, dynamic>?) ?? {},
      isRead: d['isRead'] as bool? ?? false,
      createdAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  IconData get icon {
    switch (type) {
      case NotificationType.passwordChanged:
        return Icons.lock_reset_rounded;
      case NotificationType.chatMessage:
        return Icons.chat_bubble_rounded;
      case NotificationType.planActivated:
        return Icons.workspace_premium_rounded;
      case NotificationType.paymentApproved:
        return Icons.check_circle_rounded;
      case NotificationType.paymentRejected:
        return Icons.cancel_rounded;
      case NotificationType.nicVerified:
        return Icons.verified_rounded;
      case NotificationType.contractUpdate:
        return Icons.description_rounded;
      case NotificationType.newBid:
        return Icons.gavel_rounded;
      case NotificationType.bidAccepted:
        return Icons.emoji_events_rounded;
      case NotificationType.hireRequest:
        return Icons.handyman_rounded;
      case NotificationType.projectUpdate:
        return Icons.engineering_rounded;
      case NotificationType.generic:
        return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.passwordChanged:
        return const Color(0xFFDC2626);
      case NotificationType.chatMessage:
        return const Color(0xFF1A5C46);
      case NotificationType.planActivated:
        return const Color(0xFFC9A227);
      case NotificationType.paymentApproved:
        return const Color(0xFF10B981);
      case NotificationType.paymentRejected:
        return const Color(0xFFDC2626);
      case NotificationType.nicVerified:
        return const Color(0xFF10B981);
      case NotificationType.contractUpdate:
        return const Color(0xFF0E3B2E);
      case NotificationType.newBid:
        return const Color(0xFFC9A227);
      case NotificationType.bidAccepted:
        return const Color(0xFF10B981);
      case NotificationType.hireRequest:
        return const Color(0xFF1A5C46);
      case NotificationType.projectUpdate:
        return const Color(0xFF0E3B2E);
      case NotificationType.generic:
        return const Color(0xFF5D6B64);
    }
  }
}