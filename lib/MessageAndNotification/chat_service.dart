import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ali_app/MessageAndNotification/chat_message.dart';
import 'package:ali_app/MessageAndNotification/cloudinary_service.dart';
import 'package:ali_app/MessageAndNotification/chat_meta_service.dart';

class ChatService {
  ChatService({required this.jobId, required this.cloudinaryService});

  final String jobId;
  final CloudinaryService cloudinaryService;

  CollectionReference<Map<String, dynamic>> get _messages =>
      FirebaseFirestore.instance
          .collection('chats')
          .doc(jobId)
          .collection('messages');

  Stream<List<ChatMessage>> watchMessages() {
    return _messages.orderBy('timestamp', descending: false).snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatMessage.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> sendText({
    required String senderId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _messages.add({
      'senderId': senderId,
      'type': 'text',
      'text': trimmed,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
    });

    await ChatMetaService.updateLastMessage(
      jobId: jobId,
      senderId: senderId,
      preview: trimmed,
    );
  }

  Future<void> sendImage({
    required String senderId,
    required File imageFile,
    String? caption,
  }) async {
    final imageUrl = await cloudinaryService.uploadImage(imageFile);

    await _messages.add({
      'senderId': senderId,
      'type': 'image',
      'imageUrl': imageUrl,
      if (caption != null && caption.trim().isNotEmpty)
        'caption': caption.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'seen': false,
    });

    await ChatMetaService.updateLastMessage(
      jobId: jobId,
      senderId: senderId,
      preview: caption?.trim().isNotEmpty == true ? caption! : '📷 Photo',
    );
  }

  /// Call when the current user opens this chat. Marks every message NOT
  /// sent by them as seen, so the sender's ticks turn blue.
  Future<void> markMessagesSeen(String currentUserId) async {
    final unseen = await _messages
        .where('senderId', isNotEqualTo: currentUserId)
        .where('seen', isEqualTo: false)
        .get();

    if (unseen.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unseen.docs) {
      batch.update(doc.reference, {'seen': true});
    }
    await batch.commit();
  }
}