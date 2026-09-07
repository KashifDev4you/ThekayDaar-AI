/// Represents a single bid placed by a theekaydaar (contractor) on a project.
/// Used both for entries in the `bids` array and the `acceptedBid` map.
class BidModel {
  final String amount;
  final String completionDays;
  final String note;
  final String status; // "pending", "accepted", "rejected"
  final DateTime? submittedAt;
  final String theekaydaarId;
  final String theekaydaarName;

  BidModel({
    required this.amount,
    required this.completionDays,
    required this.note,
    required this.status,
    this.submittedAt,
    required this.theekaydaarId,
    required this.theekaydaarName,
  });

  factory BidModel.fromMap(Map<String, dynamic> data) {
    return BidModel(
      amount: data['amount']?.toString() ?? '',
      completionDays: data['completionDays']?.toString() ?? '',
      note: data['note'] ?? '',
      status: data['status'] ?? '',
      // submittedAt is stored as an ISO string, not a Firestore Timestamp.
      submittedAt: data['submittedAt'] != null
          ? DateTime.tryParse(data['submittedAt'])
          : null,
      theekaydaarId: data['theekaydaarId'] ?? '',
      theekaydaarName: data['theekaydaarName'] ?? '',
    );
  }

  /// Safely parses the string amount (e.g. "11500000") into a number for
  /// formatting/sorting. Returns 0 if it can't be parsed.
  double get amountValue => double.tryParse(amount) ?? 0;
}