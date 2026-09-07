import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMeta {
  const ChatMeta({
    required this.jobId,
    required this.jobTitle,
    required this.clientId,
    required this.contractorId,
    required this.clientName,
    required this.contractorName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.lastSenderId,
    required this.unreadCounts,
    required this.jobStatus,
    this.clientPhotoUrl,
    this.contractorPhotoUrl,
  });

  final String jobId;
  final String jobTitle;
  final String clientId;
  final String contractorId;
  final String clientName;
  final String contractorName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final String lastSenderId;
  final Map<String, int> unreadCounts; // {uid: count}
  final String jobStatus; // 'active' | 'completed' | 'cancelled'
  final String? clientPhotoUrl;
  final String? contractorPhotoUrl;

  factory ChatMeta.fromFirestore(String id, Map<String, dynamic> d) {
    final ts = d['lastMessageTime'];
    final rawCounts = d['unreadCounts'] as Map<String, dynamic>? ?? {};
    return ChatMeta(
      jobId: id,
      jobTitle: d['jobTitle'] as String? ?? 'Untitled Job',
      clientId: d['clientId'] as String,
      contractorId: d['contractorId'] as String,
      clientName: d['clientName'] as String? ?? 'Client',
      contractorName: d['contractorName'] as String? ?? 'Contractor',
      lastMessage: d['lastMessage'] as String? ?? '',
      lastMessageTime: ts is Timestamp ? ts.toDate() : DateTime.now(),
      lastSenderId: d['lastSenderId'] as String? ?? '',
      unreadCounts: rawCounts.map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      jobStatus: d['jobStatus'] as String? ?? 'active',
      clientPhotoUrl: d['clientPhotoUrl'] as String?,
      contractorPhotoUrl: d['contractorPhotoUrl'] as String?,
    );
  }

  String otherPartyName(String currentUserId) =>
      currentUserId == clientId ? contractorName : clientName;

  String otherPartyId(String currentUserId) =>
      currentUserId == clientId ? contractorId : clientId;

  String? otherPartyPhotoUrl(String currentUserId) =>
      currentUserId == clientId ? contractorPhotoUrl : clientPhotoUrl;

  int unreadCountFor(String currentUserId) => unreadCounts[currentUserId] ?? 0;
}