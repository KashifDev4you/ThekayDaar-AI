// review_model.dart
// A review — can be CLIENT rating CONTRACTOR, or CONTRACTOR rating CLIENT.
// `direction` decides which 3 categories the ratings represent, so the UI
// can render the right labels without guessing.

import 'package:cloud_firestore/cloud_firestore.dart';

enum ReviewDirection { clientToContractor, contractorToClient }

extension ReviewDirectionX on ReviewDirection {
  String get value =>
      this == ReviewDirection.clientToContractor ? 'client_to_contractor' : 'contractor_to_client';

  static ReviewDirection fromValue(String v) =>
      v == 'contractor_to_client' ? ReviewDirection.contractorToClient : ReviewDirection.clientToContractor;

  // Category labels shown in the UI for this direction.
  List<String> get categoryLabels {
    if (this == ReviewDirection.clientToContractor) {
      return ['On-Time Delivery', 'Work Quality', 'Behavior & Communication'];
    }
    return ['Timely Payment', 'Clear Instructions', 'Cooperative Behavior'];
  }
}

class ReviewModel {
  final String reviewId;
  final String projectId;
  final String contractId;
  final ReviewDirection direction;

  final String reviewerId;
  final String reviewerName;
  final String revieweeId;
  final String revieweeName;

  final int rating1; // meaning depends on `direction` — see categoryLabels
  final int rating2;
  final int rating3;
  final String reviewText;

  final DateTime? createdAt;

  ReviewModel({
    required this.reviewId,
    required this.projectId,
    required this.contractId,
    required this.direction,
    required this.reviewerId,
    required this.reviewerName,
    required this.revieweeId,
    required this.revieweeName,
    required this.rating1,
    required this.rating2,
    required this.rating3,
    this.reviewText = '',
    this.createdAt,
  });

  double get overallRating => (rating1 + rating2 + rating3) / 3;

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'contractId': contractId,
      'direction': direction.value,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'revieweeId': revieweeId,
      'revieweeName': revieweeName,
      'rating1': rating1,
      'rating2': rating2,
      'rating3': rating3,
      'overallRating': overallRating,
      'reviewText': reviewText,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory ReviewModel.fromMap(String id, Map<String, dynamic> map) {
    return ReviewModel(
      reviewId: id,
      projectId: map['projectId'] ?? '',
      contractId: map['contractId'] ?? '',
      direction: ReviewDirectionX.fromValue(map['direction'] ?? 'client_to_contractor'),
      reviewerId: map['reviewerId'] ?? '',
      reviewerName: map['reviewerName'] ?? '',
      revieweeId: map['revieweeId'] ?? '',
      revieweeName: map['revieweeName'] ?? '',
      rating1: (map['rating1'] ?? 0).toInt(),
      rating2: (map['rating2'] ?? 0).toInt(),
      rating3: (map['rating3'] ?? 0).toInt(),
      reviewText: map['reviewText'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}