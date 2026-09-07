// review_service.dart
// Handles writing reviews in EITHER direction and keeping the correct
// party's aggregate rating (ratingSum/ratingCount) accurate. Each side can
// rate independently and only once per project — tracked via two separate
// flags on the project doc: clientRated / contractorRated.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ali_app/rating_system/review_model.dart';

class ReviewService {
  final CollectionReference _reviewsRef =
      FirebaseFirestore.instance.collection('reviews');

  Future<void> submitReview(ReviewModel review) async {
    final db = FirebaseFirestore.instance;
    final projectRef = db.collection('projects').doc(review.projectId);

    final isClientReviewing = review.direction == ReviewDirection.clientToContractor;
    // Whoever is being rated gets their aggregate updated —
    // contractor's rating lives on `thekaydaars`, client's on `clients`.
    final revieweeRef = isClientReviewing
        ? db.collection('thekaydaars').doc(review.revieweeId)
        : db.collection('clients').doc(review.revieweeId);
    final lockField = isClientReviewing ? 'clientRated' : 'contractorRated';

    await db.runTransaction((tx) async {
      final projectSnap = await tx.get(projectRef);
      final projectData = projectSnap.data() ?? {};
      if (projectData[lockField] == true) {
        throw Exception('You have already submitted a rating for this project.');
      }

      final revieweeSnap = await tx.get(revieweeRef);
      final revieweeData = revieweeSnap.data() ?? {};
      final currentSum = (revieweeData['ratingSum'] ?? 0).toDouble();
      final currentCount = (revieweeData['ratingCount'] ?? 0) as int;

      final newSum = currentSum + review.overallRating;
      final newCount = currentCount + 1;
      final newAverage = newSum / newCount;

      final reviewRef = _reviewsRef.doc();
      tx.set(reviewRef, review.toMap());

      tx.update(revieweeRef, {
        'ratingSum': newSum,
        'ratingCount': newCount,
        'rating': newAverage,
      });

      tx.update(projectRef, {lockField: true});
    });
  }

  // All reviews written ABOUT a given contractor (client_to_contractor only).
  Stream<List<ReviewModel>> streamReviewsForContractor(String thekaydaarId) {
    return _reviewsRef
        .where('revieweeId', isEqualTo: thekaydaarId)
        .where('direction', isEqualTo: 'client_to_contractor')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReviewModel.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList());
  }

  // All reviews written ABOUT a given client (contractor_to_client only) —
  // useful later if you want to show a client's reliability score to
  // contractors before they bid.
  Stream<List<ReviewModel>> streamReviewsForClient(String clientId) {
    return _reviewsRef
        .where('revieweeId', isEqualTo: clientId)
        .where('direction', isEqualTo: 'contractor_to_client')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReviewModel.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList());
  }
}