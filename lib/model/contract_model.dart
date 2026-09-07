// contract_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ali_app/contract/scope_of_work/scope_templates.dart' show ScopeDecision;

// ---------------------------------------------------------------------------
// 3-way scope decision — koi bhi item "assume" nahi hota. Har task ke liye
// explicitly batana zaroori hai ke ye Thekaydaar ki zimmedari hai, bilkul
// contract se bahar hai, ya sirf labour Thekaydaar ka hai (material client
// ka). Isse "ye mera duty nahi tha" wala dispute nahi hota — signed PDF mein
// teeno categories saaf likhi hoti hain.
// ---------------------------------------------------------------------------

ScopeDecision _decisionFromString(String? s) {
  switch (s) {
    case 'excluded':
      return ScopeDecision.excluded;
    case 'clientMaterial':
      return ScopeDecision.clientMaterial;
    case 'included':
      return ScopeDecision.included;
    default:
      return ScopeDecision.undecided;
  }
}

class ScopeItem {
  final String id;
  final String task;
  final String description;
  final String category;
  final int timelineDays;
  String? note;

  ScopeDecision decision;
  bool isDone;
  DateTime? completedAt;

  @Deprecated('ScopeItem no longer has a cost — payment is milestone-level only')
  double get cost => 0.0;

  ScopeItem({
    this.id = '',
    required this.task,
    this.description = '',
    this.category = '',
    this.timelineDays = 0,
    this.note,
    this.decision = ScopeDecision.included,
    this.isDone = false,
    this.completedAt,
  });

  bool get included => decision == ScopeDecision.included;
  bool get excluded => decision == ScopeDecision.excluded;
  bool get clientMaterial => decision == ScopeDecision.clientMaterial;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task': task,
      'description': description,
      'category': category,
      'timelineDays': timelineDays,
      'note': note,
      'decision': decision.name,
      'included': included,
      'isDone': isDone,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  factory ScopeItem.fromMap(Map<String, dynamic> map) {
    final hasDecisionField = map.containsKey('decision');
    final decision = hasDecisionField
        ? _decisionFromString(map['decision'])
        : ((map['included'] ?? true) ? ScopeDecision.included : ScopeDecision.excluded);

    return ScopeItem(
      id: map['id'] ?? '',
      task: map['task'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      timelineDays: (map['timelineDays'] ?? 0).toInt(),
      note: map['note'],
      decision: decision,
      isDone: map['isDone'] ?? false,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class Milestone {
  final String title;
  final double percent;
  final double amount;
  String status; // "pending" | "awaiting_approval" | "approved"
  String? proofImageUrl;
  DateTime? completedAt;
  DateTime? approvedAt;

  Milestone({
    required this.title,
    required this.percent,
    required this.amount,
    this.status = 'pending',
    this.proofImageUrl,
    this.completedAt,
    this.approvedAt,
  });

  bool get isApproved => status == 'approved' || status == 'paid';

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'percent': percent,
      'amount': amount,
      'status': status,
      'proofImageUrl': proofImageUrl,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
    };
  }

  factory Milestone.fromMap(Map<String, dynamic> map) {
    return Milestone(
      title: map['title'] ?? '',
      percent: (map['percent'] ?? 0).toDouble(),
      amount: (map['amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'pending',
      proofImageUrl: map['proofImageUrl'],
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
      approvedAt: (map['approvedAt'] as Timestamp?)?.toDate() ??
          (map['paidAt'] as Timestamp?)?.toDate(),
    );
  }
}

class ContractSignature {
  final bool agreed;
  final String fullName;
  final DateTime? timestamp;

  ContractSignature({this.agreed = false, this.fullName = '', this.timestamp});

  Map<String, dynamic> toMap() {
    return {
      'agreed': agreed,
      'fullName': fullName,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : null,
    };
  }

  factory ContractSignature.fromMap(Map<String, dynamic>? map) {
    if (map == null) return ContractSignature();
    return ContractSignature(
      agreed: map['agreed'] ?? false,
      fullName: map['fullName'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}

// ---------------------------------------------------------------------------
// Legal terms block — "boring but essential" clauses jo real work agreements
// mein disputes rokte hain.
// ---------------------------------------------------------------------------
class ContractLegalTerms {
  final String clientCnic;
  final String contractorCnic;
  final String clientPhone;
  final String contractorPhone;
  final String clientAddress;
  final String contractorAddress; // = site/work address

  final String materialsResponsibility; // "client" | "contractor" | "shared"
  final double delayPenaltyPercent;
  final int warrantyDays;

  final Map<String, String> thekaydaarRequirements;

  ContractLegalTerms({
    this.clientCnic = '',
    this.contractorCnic = '',
    this.clientPhone = '',
    this.contractorPhone = '',
    this.clientAddress = '',
    this.contractorAddress = '',
    this.materialsResponsibility = 'contractor',
    this.delayPenaltyPercent = 0,
    this.warrantyDays = 7,
    Map<String, String>? thekaydaarRequirements,
  }) : thekaydaarRequirements = thekaydaarRequirements ?? {};

  Map<String, dynamic> toMap() {
    return {
      'clientCnic': clientCnic,
      'contractorCnic': contractorCnic,
      'clientPhone': clientPhone,
      'contractorPhone': contractorPhone,
      'clientAddress': clientAddress,
      'contractorAddress': contractorAddress,
      'materialsResponsibility': materialsResponsibility,
      'delayPenaltyPercent': delayPenaltyPercent,
      'warrantyDays': warrantyDays,
      'thekaydaarRequirements': thekaydaarRequirements,
    };
  }

  factory ContractLegalTerms.fromMap(Map<String, dynamic>? map) {
    if (map == null) return ContractLegalTerms();
    return ContractLegalTerms(
      clientCnic: map['clientCnic'] ?? '',
      contractorCnic: map['contractorCnic'] ?? '',
      clientPhone: map['clientPhone'] ?? '',
      contractorPhone: map['contractorPhone'] ?? '',
      clientAddress: map['clientAddress'] ?? '',
      contractorAddress: map['contractorAddress'] ?? '',
      materialsResponsibility: map['materialsResponsibility'] ?? 'contractor',
      delayPenaltyPercent: (map['delayPenaltyPercent'] ?? 0).toDouble(),
      warrantyDays: (map['warrantyDays'] ?? 7).toInt(),
      thekaydaarRequirements: (map['thekaydaarRequirements'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
          {},
    );
  }
}

class ContractModel {
  final String contractId;
  final String projectId;
  final String clientId;
  final String contractorId;
  final String clientName;
  final String contractorName;

  final String projectType;

  /// Brief description of the project (e.g., "2-story house, 5 marla, grey structure + finishing")
  final String projectBriefDescription;

  String status;

  final double advancePercent;
  final double advanceAmount;
  final double totalAmount;

  final List<ScopeItem> scopeOfWork;
  final List<Milestone> milestones;

  final DateTime? expectedStartDate;
  final DateTime? expectedEndDate;

  ContractSignature clientSignature;
  ContractSignature contractorSignature;

  final ContractLegalTerms legalTerms;

  DateTime? workCompletedAt;
  String paymentStatus;
  String? paymentMethod;
  String? paymentTxnId;
  DateTime? paymentSubmittedAt;
  DateTime? payoutConfirmedAt;
  double? commissionAmount;
  double? contractorPayoutAmount;

  // ── Escrow fields ────────────────────────────────────────────────────
  String escrowStatus; // not_started | client_paid | escrow_holding | payout_released
  final double commissionRate;
  DateTime? escrowHeldAt;
  DateTime? payoutReleasedAt;

  final DateTime? createdAt;
  DateTime? updatedAt;

  ContractModel({
    required this.contractId,
    required this.projectId,
    required this.clientId,
    required this.contractorId,
    required this.clientName,
    required this.contractorName,
    this.projectType = '',
    this.projectBriefDescription = '',
    this.status = 'pending_signatures',
    required this.advancePercent,
    required this.advanceAmount,
    required this.totalAmount,
    required this.scopeOfWork,
    required this.milestones,
    this.expectedStartDate,
    this.expectedEndDate,
    ContractSignature? clientSignature,
    ContractSignature? contractorSignature,
    ContractLegalTerms? legalTerms,
    this.workCompletedAt,
    this.paymentStatus = 'not_started',
    this.paymentMethod,
    this.paymentTxnId,
    this.paymentSubmittedAt,
    this.payoutConfirmedAt,
    this.commissionAmount,
    this.contractorPayoutAmount,
    this.escrowStatus = 'not_started',
    this.commissionRate = 0.025,
    this.escrowHeldAt,
    this.payoutReleasedAt,
    this.createdAt,
    this.updatedAt,
  })  : clientSignature = clientSignature ?? ContractSignature(),
        contractorSignature = contractorSignature ?? ContractSignature(),
        legalTerms = legalTerms ?? ContractLegalTerms();

  bool get isFullySigned => clientSignature.agreed && contractorSignature.agreed;
  bool get isLocked => status == 'completed' || status == 'disputed' || status == 'cancelled';
  bool get isWorkCompleted => status == 'work_completed';
  bool get isPaymentSubmitted => status == 'payment_submitted';

  int get doneTaskCount => scopeOfWork.where((s) => s.included && s.isDone).length;
  int get totalTaskCount => scopeOfWork.where((s) => s.included).length;

  Map<String, String> get thekaydaarRequirements => legalTerms.thekaydaarRequirements;

  Map<String, dynamic> toMap() {
    return {
      'projectId': projectId,
      'clientId': clientId,
      'contractorId': contractorId,
      'clientName': clientName,
      'contractorName': contractorName,
      'projectType': projectType,
      'projectBriefDescription': projectBriefDescription,
      'status': status,
      'advancePercent': advancePercent,
      'advanceAmount': advanceAmount,
      'totalAmount': totalAmount,
      'scopeOfWork': scopeOfWork.map((e) => e.toMap()).toList(),
      'milestones': milestones.map((e) => e.toMap()).toList(),
      'expectedStartDate': expectedStartDate != null ? Timestamp.fromDate(expectedStartDate!) : null,
      'expectedEndDate': expectedEndDate != null ? Timestamp.fromDate(expectedEndDate!) : null,
      'clientSignature': clientSignature.toMap(),
      'contractorSignature': contractorSignature.toMap(),
      'legalTerms': legalTerms.toMap(),
      'workCompletedAt': workCompletedAt != null ? Timestamp.fromDate(workCompletedAt!) : null,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentTxnId': paymentTxnId,
      'paymentSubmittedAt': paymentSubmittedAt != null ? Timestamp.fromDate(paymentSubmittedAt!) : null,
      'payoutConfirmedAt': payoutConfirmedAt != null ? Timestamp.fromDate(payoutConfirmedAt!) : null,
      'commissionAmount': commissionAmount,
      'contractorPayoutAmount': contractorPayoutAmount,
      'escrowStatus': escrowStatus,
      'commissionRate': commissionRate,
      'escrowHeldAt': escrowHeldAt != null ? Timestamp.fromDate(escrowHeldAt!) : null,
      'payoutReleasedAt': payoutReleasedAt != null ? Timestamp.fromDate(payoutReleasedAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ContractModel.fromMap(String id, Map<String, dynamic> map) {
    return ContractModel(
      contractId: id,
      projectId: map['projectId'] ?? '',
      clientId: map['clientId'] ?? '',
      contractorId: map['contractorId'] ?? '',
      clientName: map['clientName'] ?? '',
      contractorName: map['contractorName'] ?? '',
      projectType: map['projectType'] ?? '',
      projectBriefDescription: map['projectBriefDescription'] ?? '',
      status: map['status'] ?? 'pending_signatures',
      advancePercent: (map['advancePercent'] ?? 0).toDouble(),
      advanceAmount: (map['advanceAmount'] ?? 0).toDouble(),
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      scopeOfWork: ((map['scopeOfWork'] ?? []) as List)
          .map((e) => ScopeItem.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      milestones: ((map['milestones'] ?? []) as List)
          .map((e) => Milestone.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      expectedStartDate: (map['expectedStartDate'] as Timestamp?)?.toDate(),
      expectedEndDate: (map['expectedEndDate'] as Timestamp?)?.toDate(),
      clientSignature: ContractSignature.fromMap(map['clientSignature']),
      contractorSignature: ContractSignature.fromMap(map['contractorSignature']),
      legalTerms: ContractLegalTerms.fromMap(map['legalTerms']),
      workCompletedAt: (map['workCompletedAt'] as Timestamp?)?.toDate(),
      paymentStatus: map['paymentStatus'] ?? 'not_started',
      paymentMethod: map['paymentMethod'],
      paymentTxnId: map['paymentTxnId'],
      paymentSubmittedAt: (map['paymentSubmittedAt'] as Timestamp?)?.toDate(),
      payoutConfirmedAt: (map['payoutConfirmedAt'] as Timestamp?)?.toDate(),
      commissionAmount: (map['commissionAmount'] as num?)?.toDouble(),
      contractorPayoutAmount: (map['contractorPayoutAmount'] as num?)?.toDouble(),
      escrowStatus: map['escrowStatus'] ?? 'not_started',
      commissionRate: (map['commissionRate'] as num?)?.toDouble() ?? 0.025,
      escrowHeldAt: (map['escrowHeldAt'] as Timestamp?)?.toDate(),
      payoutReleasedAt: (map['payoutReleasedAt'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}