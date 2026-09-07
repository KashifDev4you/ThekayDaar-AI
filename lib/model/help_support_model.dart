import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single FAQ / help topic document from the `help_support` collection.
class HelpSupportModel {
  final String id;
  final String question;
  final String answer;
  final String? category; // e.g. "Billing", "Account", "Projects"

  HelpSupportModel({
    required this.id,
    required this.question,
    required this.answer,
    this.category,
  });

  factory HelpSupportModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return HelpSupportModel(
      id: doc.id,
      question: data['question'] ?? '',
      answer: data['answer'] ?? '',
      category: data['category'],
    );
  }
}