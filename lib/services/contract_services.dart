// contract_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ali_app/model/contract_model.dart';
import 'package:ali_app/Payment&Requests/connects_config.dart';
import 'package:ali_app/profile_sub_pages/notifications/notification_service.dart';

class ContractService {
  final CollectionReference _contractsRef =
      FirebaseFirestore.instance.collection('contracts');

  // ── Notification helpers ────────────────────────────────────
  // Every state change in a contract's life notifies the OTHER party
  // (and admin-triggered events notify both). Fire-and-forget: a
  // failed notification never blocks the contract flow.
  void _notify({
    required String targetUid,
    required String contractTitle,
    required String event,
    required String contractId,
  }) {
    NotificationService.instance.notifyContractUpdate(
      targetUid: targetUid,
      contractTitle: contractTitle,
      event: event,
      contractId: contractId,
    );
  }

  // Contract docs have no single `title` field — compose a readable
  // label from the brief description / project type.
  String _titleOf(Map<String, dynamic> data) {
    final brief = data['projectBriefDescription'] as String? ?? '';
    if (brief.trim().isNotEmpty) return brief;
    final type = data['projectType'] as String? ?? '';
    if (type.trim().isNotEmpty) return type;
    return 'Work Agreement';
  }

  Future<String> createContract(ContractModel contract) async {
    final docRef = await _contractsRef.add(contract.toMap());

    // Tell the contractor a new work agreement awaits their signature.
    _notify(
      targetUid: contract.contractorId,
      contractTitle: _titleOf(contract.toMap()),
      event:
          'New work agreement from ${contract.clientName} — review and sign',
      contractId: docRef.id,
    );
    return docRef.id;
  }

  Stream<ContractModel?> streamContract(String contractId) {
    return _contractsRef.doc(contractId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ContractModel.fromMap(snap.id, snap.data() as Map<String, dynamic>);
    });
  }

  Stream<List<ContractModel>> streamContractsForUser({
    required String userId,
    required bool isContractor,
  }) {
    final field = isContractor ? 'contractorId' : 'clientId';
    return _contractsRef.where(field, isEqualTo: userId).snapshots().map((snap) {
      return snap.docs
          .map((d) => ContractModel.fromMap(d.id, d.data() as Map<String, dynamic>))
          .toList();
    });
  }

  // Small helper — every write method below calls this first so a
  // completed/disputed/cancelled contract can never be mutated again,
  // even if a stale UI somehow still shows an action button.
  Future<Map<String, dynamic>> _getLockCheckedData(DocumentReference docRef) async {
    final snap = await docRef.get();
    final data = snap.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? '';
    if (status == 'completed' || status == 'disputed' || status == 'cancelled') {
      throw Exception('This contract is closed and can no longer be modified.');
    }
    return data;
  }

  Future<void> signAsClient({
    required String contractId,
    required String fullName,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    // Captured inside the transaction so the notification below can
    // use them after it commits.
    String contractorId = '';
    String contractTitle = 'Work Agreement';
    bool nowActive = false;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status == 'completed' || status == 'disputed' || status == 'cancelled') {
        throw Exception('This contract is closed and can no longer be modified.');
      }
      final contractorSigned = (data['contractorSignature']?['agreed'] ?? false) == true;

      contractorId = data['contractorId'] as String? ?? '';
      contractTitle = _titleOf(data);
      nowActive = contractorSigned;

      tx.update(docRef, {
        'clientSignature': {
          'agreed': true,
          'fullName': fullName,
          'timestamp': Timestamp.now(),
        },
        'status': contractorSigned ? 'active' : 'pending_signatures',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Notify the contractor that the client signed (and whether the
    // contract is now fully active).
    _notify(
      targetUid: contractorId,
      contractTitle: contractTitle,
      event: nowActive
          ? 'Contract is now ACTIVE — you can start work'
          : 'Client signed the agreement — your signature is pending',
      contractId: contractId,
    );
  }

  Future<void> signAsContractor({
    required String contractId,
    required String fullName,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    // Captured inside the transaction so the notification below can
    // use them after it commits.
    String clientId = '';
    String contractTitle = 'Work Agreement';
    String contractorName = 'The contractor';
    bool nowActive = false;
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      final data = snap.data() as Map<String, dynamic>;
      final status = data['status'] as String? ?? '';
      if (status == 'completed' || status == 'disputed' || status == 'cancelled') {
        throw Exception('This contract is closed and can no longer be modified.');
      }
      final clientSigned = (data['clientSignature']?['agreed'] ?? false) == true;

      clientId = data['clientId'] as String? ?? '';
      contractTitle = _titleOf(data);
      contractorName = data['contractorName'] as String? ?? 'The contractor';
      nowActive = clientSigned;

      tx.update(docRef, {
        'contractorSignature': {
          'agreed': true,
          'fullName': fullName,
          'timestamp': Timestamp.now(),
        },
        'status': clientSigned ? 'active' : 'pending_signatures',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    // Notify the client that the contractor signed.
    _notify(
      targetUid: clientId,
      contractTitle: contractTitle,
      event: nowActive
          ? 'Contract is now ACTIVE — $contractorName can start work'
          : '$contractorName signed — your signature is pending',
      contractId: contractId,
    );
  }

  // ---------------------------------------------------------------------
  // Toggles a single scope-of-work task as done / not-done.
  // IMPORTANT: this should only ever be called from the CONTRACTOR's UI —
  // there is no separate "client marks task done" flow, because the whole
  // point is that only the person doing the work can say it's finished.
  // The client can only VIEW this status.
  // ---------------------------------------------------------------------
  Future<void> markScopeItemDone({
    required String contractId,
    required int scopeIndex,
    required bool isDone,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    final data = await _getLockCheckedData(docRef);
    final scope = List<Map<String, dynamic>>.from(data['scopeOfWork']);

    if (scopeIndex < 0 || scopeIndex >= scope.length) {
      throw Exception('Invalid task index.');
    }

    scope[scopeIndex]['isDone'] = isDone;
    scope[scopeIndex]['completedAt'] = isDone ? Timestamp.now() : null;

    await docRef.update({
      'scopeOfWork': scope,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Tell the client a scope-of-work task was ticked off.
    if (isDone) {
      _notify(
        targetUid: (data['clientId'] as String?) ?? '',
        contractTitle: _titleOf(data),
        event:
            '${data['contractorName'] ?? 'The contractor'} completed task "${scope[scopeIndex]['task'] ?? ''}"',
        contractId: contractId,
      );
    }
  }

  // Contractor uploads proof photo for a milestone -> awaiting client review.
  // This is progress tracking only; no payment is triggered here.
  Future<void> markMilestoneComplete({
    required String contractId,
    required int milestoneIndex,
    required String proofImageUrl,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    final data = await _getLockCheckedData(docRef);
    final milestones = List<Map<String, dynamic>>.from(data['milestones']);

    milestones[milestoneIndex]['status'] = 'awaiting_approval';
    milestones[milestoneIndex]['proofImageUrl'] = proofImageUrl;
    milestones[milestoneIndex]['completedAt'] = Timestamp.now();

    await docRef.update({
      'milestones': milestones,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Client needs to review the milestone proof photo.
    _notify(
      targetUid: (data['clientId'] as String?) ?? '',
      contractTitle: _titleOf(data),
      event:
          'Milestone "${milestones[milestoneIndex]['title'] ?? 'Milestone'}" is awaiting your approval',
      contractId: contractId,
    );
  }

  // CHANGED: milestones are now progress-only. Approving one no longer
  // creates a payment_requests doc and no longer cascades job/project
  // completion — that only happens at the very end via
  // confirmContractPayout(), once the client has paid the full amount and
  // admin has sent the contractor's share.
  Future<void> approveMilestone({
    required String contractId,
    required int milestoneIndex,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    final data = await _getLockCheckedData(docRef);
    final milestones = List<Map<String, dynamic>>.from(data['milestones']);

    milestones[milestoneIndex]['status'] = 'approved';
    milestones[milestoneIndex]['approvedAt'] = Timestamp.now();

    await docRef.update({
      'milestones': milestones,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Tell the contractor their milestone was approved.
    _notify(
      targetUid: (data['contractorId'] as String?) ?? '',
      contractTitle: _titleOf(data),
      event:
          '${data['clientName'] ?? 'The client'} approved milestone "${milestones[milestoneIndex]['title'] ?? 'Milestone'}"',
      contractId: contractId,
    );
  }

  // ---------------------------------------------------------------------
  // Contractor presses "Mark Project Complete" — one button for the whole
  // contract, independent of individual milestone approvals. Only valid
  // from 'active' status.
  // ---------------------------------------------------------------------
  Future<void> markProjectComplete({required String contractId}) async {
    final docRef = _contractsRef.doc(contractId);
    final data = await _getLockCheckedData(docRef);
    final status = data['status'] as String? ?? '';
    if (status != 'active') {
      throw Exception('Contract must be active before it can be marked complete.');
    }

    await docRef.update({
      'status': 'work_completed',
      'workCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // The client now needs to submit the escrow payment.
    _notify(
      targetUid: (data['clientId'] as String?) ?? '',
      contractTitle: _titleOf(data),
      event:
          'Work marked complete by ${data['contractorName'] ?? 'the contractor'} — please submit payment',
      contractId: contractId,
    );
  }

  // ---------------------------------------------------------------------
  // Client submits the transaction ID after sending the FULL amount to
  // the platform's EasyPaisa/JazzCash account (escrow).
  // The funds are HELD by the platform until admin verifies and releases
  // the contractor's share after deducting the platform commission.
  // ---------------------------------------------------------------------
  Future<void> submitContractPayment({
    required String contractId,
    required String txnId,
    required String method,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    final snap = await docRef.get();
    final data = snap.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? '';
    if (status != 'work_completed') {
      throw Exception('Contractor has not marked the work complete yet.');
    }

    final now = FieldValue.serverTimestamp();
    final commissionRate = (data['commissionRate'] as num?)?.toDouble() ?? ThekaydaarPlans.commissionRate;

    await docRef.update({
      'status': 'payment_submitted',
      'paymentStatus': 'submitted',
      'paymentMethod': method,
      'paymentTxnId': txnId,
      'paymentSubmittedAt': now,
      'updatedAt': now,
      // Escrow: client has paid, funds now with platform
      'escrowStatus': 'client_paid',
      'escrowHeldAt': now,
      'commissionRate': commissionRate,
    });

    final totalAmount = (data['totalAmount'] ?? 0).toDouble();
    final commissionAmount = totalAmount * commissionRate;
    final contractorPayout = totalAmount - commissionAmount;

    await FirebaseFirestore.instance.collection('payment_requests').add({
      'type': 'contract_payment',
      'contractId': contractId,
      'projectId': data['projectId'],
      'role': 'client',
      'uid': data['clientId'],
      'userName': data['clientName'],
      'clientName': data['clientName'],
      'thekaydaarId': data['contractorId'],
      'thekaydaarName': data['contractorName'],
      'planLabel': 'Project Payment (Escrow) — ${data['contractorName']}',
      'amount': 'Rs ${totalAmount.toStringAsFixed(0)}',
      'commissionRate': commissionRate,
      'commissionAmount': 'Rs ${commissionAmount.toStringAsFixed(0)}',
      'contractorPayout': 'Rs ${contractorPayout.toStringAsFixed(0)}',
      'method': method,
      'txnId': txnId,
      'escrowStatus': 'client_paid',
      'status': 'pending',
      'requestedAt': now,
    });

    // Tell the contractor the escrow payment was submitted.
    _notify(
      targetUid: (data['contractorId'] as String?) ?? '',
      contractTitle: _titleOf(data),
      event:
          'Payment of Rs ${totalAmount.toStringAsFixed(0)} submitted by ${data['clientName'] ?? 'the client'} — in escrow review',
      contractId: contractId,
    );
  }

  // ---------------------------------------------------------------------
  // Admin confirms escrow holding — payment received and verified.
  // Funds are now officially held in escrow by the platform.
  // ---------------------------------------------------------------------
  Future<void> confirmEscrowHolding({
    required String contractId,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    final data = await _getLockCheckedData(docRef);
    final escrowStatus = data['escrowStatus'] as String? ?? 'not_started';
    if (escrowStatus != 'client_paid') {
      throw Exception('Client payment not received yet.');
    }

    await docRef.update({
      'escrowStatus': 'escrow_holding',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Escrow confirmed — tell both parties their money is safely held.
    _notify(
      targetUid: (data['clientId'] as String?) ?? '',
      contractTitle: _titleOf(data),
      event: 'Your payment is now held safely in escrow',
      contractId: contractId,
    );
    _notify(
      targetUid: (data['contractorId'] as String?) ?? '',
      contractTitle: _titleOf(data),
      event: 'Escrow confirmed — funds secured for this contract',
      contractId: contractId,
    );
  }

  // ---------------------------------------------------------------------
  // Admin confirms the payout — releases escrowed funds to contractor
  // after deducting the platform commission (2.5%).
  // This is the point where the job/project actually close out.
  // ---------------------------------------------------------------------
  Future<void> confirmContractPayout({
    required String contractId,
    double? commissionAmount,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    final snap = await docRef.get();
    final data = snap.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? '';
    if (status != 'payment_submitted') {
      throw Exception('Client has not submitted payment yet.');
    }

    final total = (data['totalAmount'] ?? 0).toDouble();
    final rate = (data['commissionRate'] as num?)?.toDouble() ?? ThekaydaarPlans.commissionRate;
    final commission = commissionAmount ?? (total * rate);
    final payout = total - commission;
    final now = FieldValue.serverTimestamp();

    await docRef.update({
      'status': 'completed',
      'paymentStatus': 'confirmed',
      'commissionAmount': commission,
      'contractorPayoutAmount': payout,
      'payoutConfirmedAt': now,
      'updatedAt': now,
      // Escrow: funds released to contractor
      'escrowStatus': 'payout_released',
      'payoutReleasedAt': now,
    });

    final db = FirebaseFirestore.instance;
    final projectId = data['projectId'] as String? ?? '';

    final activeJobQuery = await db
        .collection('active_jobs')
        .where('projectId', isEqualTo: projectId)
        .limit(1)
        .get();
    if (activeJobQuery.docs.isNotEmpty) {
      await activeJobQuery.docs.first.reference.update({
        'status': 'completed',
        'completedAt': now,
      });
    }

    if (projectId.isNotEmpty) {
      await db.collection('projects').doc(projectId).update({
        'status': 'completed',
        'completedAt': now,
      });
    }

    final contractorId = data['contractorId'] as String? ?? '';
    if (contractorId.isNotEmpty) {
      await db.collection('thekaydaars').doc(contractorId).update({
        'activeJobs': FieldValue.increment(-1),
        'totalJobs': FieldValue.increment(1),
      });
    }

    // Payout released + project completed — notify both parties.
    NotificationService.instance.notifyPayment(
      targetUid: contractorId,
      event: 'Payout released',
      amount: payout.toStringAsFixed(0),
      projectId: projectId,
    );
    _notify(
      targetUid: contractorId,
      contractTitle: _titleOf(data),
      event:
          'Project completed — Rs ${payout.toStringAsFixed(0)} payout released to you',
      contractId: contractId,
    );
    _notify(
      targetUid: (data['clientId'] as String?) ?? '',
      contractTitle: _titleOf(data),
      event: 'Project completed — payment released to your contractor',
      contractId: contractId,
    );
  }

  // NOTE: raiseDispute deliberately does NOT use _getLockCheckedData, because
  // that helper also blocks 'completed' contracts — but a dispute must still
  // be raisable on a completed contract during its warranty/defect-liability
  // period (see ContractLegalTerms.warrantyDays). Only a contract that's
  // already disputed or cancelled is truly closed to further disputes.
  Future<void> raiseDispute({
    required String contractId,
    required String reason,
    required String raisedBy,
  }) async {
    final docRef = _contractsRef.doc(contractId);
    final snap = await docRef.get();
    final data = snap.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? '';
    if (status == 'disputed' || status == 'cancelled') {
      throw Exception('This contract already has an active dispute or is cancelled.');
    }
    await docRef.update({
      'status': 'disputed',
      'disputeReason': reason,
      'disputeRaisedBy': raisedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Alert the other party about the dispute.
    final otherUid = raisedBy == data['clientId']
        ? (data['contractorId'] as String? ?? '')
        : (data['clientId'] as String? ?? '');
    _notify(
      targetUid: otherUid,
      contractTitle: _titleOf(data),
      event: 'A dispute was raised: "$reason"',
      contractId: contractId,
    );
  }
}