// rating_sheet.dart
// One generic star+review bottom sheet, reused for BOTH directions.
// Category labels come from ReviewDirection.categoryLabels so the UI text
// always matches who's rating whom.

import 'package:flutter/material.dart';
import 'package:ali_app/rating_system/review_model.dart';
import 'package:ali_app/rating_system/review_service.dart';

// Client rating the contractor.
Future<bool?> showRateContractorSheet({
  required BuildContext context,
  required String projectId,
  required String contractId,
  required String thekaydaarId,
  required String thekaydaarName,
  required String clientId,
  required String clientName,
}) {
  return _showRatingSheet(
    context: context,
    projectId: projectId,
    contractId: contractId,
    direction: ReviewDirection.clientToContractor,
    reviewerId: clientId,
    reviewerName: clientName,
    revieweeId: thekaydaarId,
    revieweeName: thekaydaarName,
  );
}

// Contractor rating the client.
Future<bool?> showRateClientSheet({
  required BuildContext context,
  required String projectId,
  required String contractId,
  required String clientId,
  required String clientName,
  required String thekaydaarId,
  required String thekaydaarName,
}) {
  return _showRatingSheet(
    context: context,
    projectId: projectId,
    contractId: contractId,
    direction: ReviewDirection.contractorToClient,
    reviewerId: thekaydaarId,
    reviewerName: thekaydaarName,
    revieweeId: clientId,
    revieweeName: clientName,
  );
}

Future<bool?> _showRatingSheet({
  required BuildContext context,
  required String projectId,
  required String contractId,
  required ReviewDirection direction,
  required String reviewerId,
  required String reviewerName,
  required String revieweeId,
  required String revieweeName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _RatingSheet(
      projectId: projectId,
      contractId: contractId,
      direction: direction,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
      revieweeId: revieweeId,
      revieweeName: revieweeName,
    ),
  );
}

class _RatingSheet extends StatefulWidget {
  final String projectId;
  final String contractId;
  final ReviewDirection direction;
  final String reviewerId;
  final String reviewerName;
  final String revieweeId;
  final String revieweeName;

  const _RatingSheet({
    required this.projectId,
    required this.contractId,
    required this.direction,
    required this.reviewerId,
    required this.reviewerName,
    required this.revieweeId,
    required this.revieweeName,
  });

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _r1 = 0;
  int _r2 = 0;
  int _r3 = 0;
  final TextEditingController _reviewCtrl = TextEditingController();
  bool _submitting = false;

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);

  Widget _starRow(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Row(
          children: List.generate(5, (i) {
            final filled = i < value;
            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                filled ? Icons.star_rounded : Icons.star_border_rounded,
                color: _amber,
                size: 30,
              ),
              onPressed: () => onChanged(i + 1),
            );
          }),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_r1 == 0 || _r2 == 0 || _r3 == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teeno categories mein rating dein.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final review = ReviewModel(
        reviewId: '',
        projectId: widget.projectId,
        contractId: widget.contractId,
        direction: widget.direction,
        reviewerId: widget.reviewerId,
        reviewerName: widget.reviewerName,
        revieweeId: widget.revieweeId,
        revieweeName: widget.revieweeName,
        rating1: _r1,
        rating2: _r2,
        rating3: _r3,
        reviewText: _reviewCtrl.text.trim(),
      );
      await ReviewService().submitReview(review);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labels = widget.direction.categoryLabels;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rate ${widget.revieweeName}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 16),
          _starRow(labels[0], _r1, (v) => setState(() => _r1 = v)),
          const SizedBox(height: 14),
          _starRow(labels[1], _r2, (v) => setState(() => _r2 = v)),
          const SizedBox(height: 14),
          _starRow(labels[2], _r3, (v) => setState(() => _r3 = v)),
          const SizedBox(height: 16),
          TextField(
            controller: _reviewCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Review (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: _navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const CircularProgressIndicator(color: _navy)
                  : const Text('Submit Rating', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}