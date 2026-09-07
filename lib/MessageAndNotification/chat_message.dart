import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.timestamp,
    this.text,
    this.imageUrl,
    this.caption,
    this.seen = false,
  });

  final String id;
  final String senderId;
  final String type; // 'text' or 'image'
  final DateTime timestamp;
  final String? text;
  final String? imageUrl;
  final String? caption;
  final bool seen; // true once the other party has opened the chat after this was sent

  factory ChatMessage.fromFirestore(String id, Map<String, dynamic> data) {
    final ts = data['timestamp'];
    return ChatMessage(
      id: id,
      senderId: data['senderId'] as String,
      type: data['type'] as String,
      text: data['text'] as String?,
      imageUrl: data['imageUrl'] as String?,
      caption: data['caption'] as String?,
      seen: data['seen'] as bool? ?? false,
      // Falls back to now() for the brief moment before serverTimestamp()
      // resolves on the local optimistic write.
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
    );
  }
}