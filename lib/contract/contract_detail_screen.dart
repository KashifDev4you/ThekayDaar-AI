// contract_detail_screen.dart
// Shows the full contract to both parties: scope of work, milestone
// progress, signature status, and — once work is done — the end-of-contract
// payment flow. Both client and contractor view this SAME screen — the
// buttons shown just differ based on `isContractor`.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ali_app/model/contract_model.dart';
import 'package:ali_app/services/contract_services.dart';
import 'package:ali_app/contract/contract_pdf_generator.dart';
import 'package:ali_app/rating_system/rating_sheet.dart';
import 'package:ali_app/Widgets/language_toggle_widget.dart';

const Color kNavy = Color(0xFF0E3B2E);
const Color kAmber = Color(0xFFC9A227);
const Color kGreen = Color(0xFF10B981);

class ContractDetailScreen extends StatefulWidget {
  final String contractId;
  final String currentUserId;
  final String currentUserFullName;
  final bool isContractor; // true if the logged-in user is the Thekaydaar

  const ContractDetailScreen({
    super.key,
    required this.contractId,
    required this.currentUserId,
    required this.currentUserFullName,
    required this.isContractor,
  });

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  final ContractService _service = ContractService();
  bool _isSigning = false;
  bool _isApproving = false;
  int? _togglingScopeIndex; // shows a small spinner on the row being toggled
  bool _isGeneratingPdf = false;
  bool _isMarkingComplete = false;
  bool _isSubmittingPayment = false;
  final _txnIdCtrl = TextEditingController();
  String _selectedMethod = 'EasyPaisa';

  @override
  void dispose() {
    _txnIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _signContract() async {
    setState(() => _isSigning = true);
    try {
      if (widget.isContractor) {
        await _service.signAsContractor(
          contractId: widget.contractId,
          fullName: widget.currentUserFullName,
        );
      } else {
        await _service.signAsClient(
          contractId: widget.contractId,
          fullName: widget.currentUserFullName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSigning = false);
    }
  }

  Future<void> _confirmSignDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Digital Signature'),
        content: Text(
          'Aap "${widget.currentUserFullName}" ke naam se is contract '
          'ko digitally sign karne wale hain. Ye legally binding agreement '
          'hai in payment terms aur scope of work par. Confirm karein?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kAmber),
            child: const Text('I Agree & Sign'),
          ),
        ],
      ),
    );
    if (confirmed == true) _signContract();
  }

  Future<void> _raiseDisputeDialog() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Raise Dispute'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Reason likhein (Support Desk review karega)...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed == true && reasonCtrl.text.trim().isNotEmpty) {
      try {
        await _service.raiseDispute(
          contractId: widget.contractId,
          reason: reasonCtrl.text.trim(),
          raisedBy: widget.currentUserId,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  // Client approves the currently-actionable milestone after reviewing the
  // contractor's proof photo. This is PROGRESS tracking only now — no
  // payment is released here; the actual payment happens once at the end
  // of the whole contract (see _confirmMarkComplete / _submitPayment below).
  Future<void> _confirmApproveMilestone(
    int index,
    String title,
    double amount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Milestone?'),
        content: Text(
          'Aap "$title" (Rs. ${amount.toStringAsFixed(0)}) ko approve kar rahe hain — '
          'ye sirf progress confirm karta hai, koi payment abhi nahi ho rahi. '
          'Confirm karein?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kGreen),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isApproving = true);
    try {
      await _service.approveMilestone(
        contractId: widget.contractId,
        milestoneIndex: index,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Milestone approved.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
    }
  }

  // ---------------------------------------------------------------------
  // Contractor-only toggle for a scope-of-work task. Client never sees
  // this checkbox as tappable — see the `enabled:` check below.
  // ---------------------------------------------------------------------
  Future<void> _toggleScopeItem(int index, bool currentValue) async {
    setState(() => _togglingScopeIndex = index);
    try {
      await _service.markScopeItemDone(
        contractId: widget.contractId,
        scopeIndex: index,
        isDone: !currentValue,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _togglingScopeIndex = null);
    }
  }

  // ---------------------------------------------------------------------
  // Contractor presses the single "Mark Project Complete" button for the
  // whole contract. Unlocks the client's payment-submission form.
  // ---------------------------------------------------------------------
  Future<void> _confirmMarkComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Project Complete?'),
        content: const Text(
          'Aap confirm kar rahe hain ke poora kaam mukammal ho chuka hai. '
          'Client ko payment submit karne ka option milega. Confirm karein?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: kGreen),
            child: const Text('Yes, Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isMarkingComplete = true);
    try {
      await _service.markProjectComplete(contractId: widget.contractId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Project marked complete — waiting for client payment.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isMarkingComplete = false);
    }
  }

  // Client submits transaction ID after sending the full amount to admin.
  Future<void> _submitPayment() async {
    if (_txnIdCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the transaction ID.')),
      );
      return;
    }
    setState(() => _isSubmittingPayment = true);
    try {
      await _service.submitContractPayment(
        contractId: widget.contractId,
        txnId: _txnIdCtrl.text.trim(),
        method: _selectedMethod,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment submitted — admin will verify shortly.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmittingPayment = false);
    }
  }

  Future<void> _downloadContractPdf(ContractModel contract) async {
    setState(() => _isGeneratingPdf = true);
    try {
      // New official PDF: bordered legal design, CONFIDENTIAL stamp,
      // full scope conditions, and TTF fonts so Urdu words render too.
      await ContractPdfGenerator.shareContractPdf(contract: contract);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('PDF error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ---------------------------------------------------------------------
  // End-of-project rating — both parties rate each other ONCE. This is
  // what feeds the rating/review system, so a completed contract always
  // ends with a rating prompt that builds confidence for both users.
  // ---------------------------------------------------------------------
  bool _ratingLoaded = false;
  bool _alreadyRated = false;

  Future<void> _checkAlreadyRated(String projectId) async {
    if (_ratingLoaded) return;
    _ratingLoaded = true;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .get();
      final flag = widget.isContractor ? 'contractorRated' : 'clientRated';
      if (mounted) {
        setState(() => _alreadyRated = (snap.data()?[flag] as bool?) ?? false);
      }
    } catch (_) {
      // If the check fails we still show the button — the transaction
      // in ReviewService will block a true double submission.
    }
  }

  // Sync helper — opens the right sheet for the logged-in party. Keeping
  // this non-async lets us pass `context` without crossing an async gap.
  Future<bool?> _showRatingSheet(BuildContext sheetContext, ContractModel contract) {
    return widget.isContractor
        ? showRateClientSheet(
            context: sheetContext,
            projectId: contract.projectId,
            contractId: contract.contractId,
            clientId: contract.clientId,
            clientName: contract.clientName,
            thekaydaarId: contract.contractorId,
            thekaydaarName: contract.contractorName,
          )
        : showRateContractorSheet(
            context: sheetContext,
            projectId: contract.projectId,
            contractId: contract.contractId,
            thekaydaarId: contract.contractorId,
            thekaydaarName: contract.contractorName,
            clientId: contract.clientId,
            clientName: contract.clientName,
          );
  }

  Future<void> _openRatingSheet(ContractModel contract) async {
    final submitted = await _showRatingSheet(context, contract);
    if (submitted == true && mounted) {
      setState(() => _alreadyRated = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shukriya! Aapki rating record ho gayi.'),
          backgroundColor: kGreen,
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return kGreen;
      case 'work_completed':
        return kAmber;
      case 'payment_submitted':
        return const Color(0xFF1A5C46);
      case 'disputed':
        return Colors.red;
      case 'completed':
        return kNavy;
      default:
        return kAmber;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        title: const Text('Work Agreement'),
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
            child: LanguageToggleChip(compact: true),
          ),
        ],
      ),
      body: StreamBuilder<ContractModel?>(
        stream: _service.streamContract(widget.contractId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final contract = snapshot.data;
          if (contract == null) {
            return const Center(child: Text('Contract not found'));
          }

          // One-shot check (guarded inside) — needed by the Rate & Review
          // card once the contract reaches "completed".
          if (contract.status == 'completed') {
            _checkAlreadyRated(contract.projectId);
          }

          final myAgreed = widget.isContractor
              ? contract.contractorSignature.agreed
              : contract.clientSignature.agreed;

          final nextIndex = contract.milestones.indexWhere(
            (m) => !m.isApproved,
          );

          // SafeArea bottom — keeps content clear of the Android
          // gesture bar / iOS home indicator (top is handled by AppBar).
          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(contract.status).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  contract.status.toUpperCase().replaceAll('_', ' '),
                  style: TextStyle(
                    color: _statusColor(contract.status),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _card(
                title: 'Parties',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client: ${contract.clientName}'),
                    Text('Contractor: ${contract.contractorName}'),
                  ],
                ),
              ),

              _card(
                title:
                    'Scope of Work  (${contract.doneTaskCount}/${contract.totalTaskCount} done)',
                child: Column(
                  children: contract.scopeOfWork
                      .asMap()
                      .entries
                      .where((entry) => entry.value.included)
                      .map((entry) {
                        final i = entry.key;
                        final s = entry.value;
                        final isTogglingThis = _togglingScopeIndex == i;

                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: widget.isContractor
                              ? (isTogglingThis
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Checkbox(
                                        value: s.isDone,
                                        activeColor: kGreen,
                                        onChanged: contract.isLocked
                                            ? null
                                            : (_) =>
                                                  _toggleScopeItem(i, s.isDone),
                                      ))
                              : Icon(
                                  s.isDone
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  color: s.isDone ? kGreen : Colors.grey,
                                  size: 20,
                                ),
                          title: Text(s.task),
                          subtitle: s.timelineDays > 0
                              ? Text('${s.timelineDays} days')
                              : null,
                          trailing: Text(
                            s.isDone ? 'Done' : 'Pending',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: s.isDone ? kGreen : kAmber,
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),

              _card(
                title: 'Progress Milestones',
                child: Column(
                  children: contract.milestones.asMap().entries.map((entry) {
                    final i = entry.key;
                    final m = entry.value;
                    final isApproved = m.isApproved;
                    final isAwaiting = m.status == 'awaiting_approval';
                    final isNext = i == nextIndex;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isApproved
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: isApproved
                                  ? kGreen
                                  : (isAwaiting ? kAmber : Color(0xFFA6B2AB)),
                            ),
                            title: Text(m.title),
                            subtitle: Text(
                              isApproved
                                  ? 'approved'
                                  : m.status.replaceAll('_', ' '),
                            ),
                            trailing: Text('${m.percent.toStringAsFixed(0)}%'),
                          ),

                          if (m.proofImageUrl != null &&
                              m.proofImageUrl!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                m.proofImageUrl!,
                                height: 140,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      height: 140,
                                      color: Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      child: const Text(
                                        'Could not load proof photo',
                                      ),
                                    ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],

                          if (!widget.isContractor && isAwaiting && isNext)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isApproving
                                    ? null
                                    : () => _confirmApproveMilestone(
                                        i,
                                        m.title,
                                        m.amount,
                                      ),
                                icon: _isApproving
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check, size: 16),
                                label: const Text('Approve Milestone'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kGreen,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),

                          if (!widget.isContractor &&
                              isNext &&
                              !isAwaiting &&
                              !isApproved)
                            const Text(
                              'Waiting for contractor to mark this milestone done.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── Project Brief Description ──────────────────────────────
              if (contract.projectBriefDescription.isNotEmpty)
                _card(
                  title: 'Project Brief',
                  child: Text(
                    contract.projectBriefDescription,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),

              // ── Escrow Status Card ──────────────────────────────────────
              if (contract.status == 'payment_submitted' ||
                  contract.status == 'completed' ||
                  contract.status == 'work_completed')
                _buildEscrowCard(contract),

              if (contract.status == 'active' ||
                  contract.status == 'work_completed' ||
                  contract.status == 'payment_submitted' ||
                  contract.status == 'completed')
                _card(
                  title: 'Project Completion',
                  child: _buildCompletionSection(contract),
                ),

              // ── Rate & Review — feeds the rating system once the ─────
              // contract is fully completed. Both sides rate each other,
              // which is what builds confidence for future users.
              if (contract.status == 'completed') ...[
                _card(
                  title: 'Rate & Review',
                  child: _alreadyRated
                      ? Row(
                          children: [
                            const Icon(Icons.verified_rounded,
                                size: 18, color: kGreen),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.isContractor
                                    ? 'Aapne is client ko rate kar diya — shukriya! Aapki rating contractors ke liye client ka trust score banati hai.'
                                    : 'Aapne is thekaydaar ko rate kar diya — shukriya! Aapki rating baqi clients ke liye trust banati hai.',
                                style: const TextStyle(
                                    fontSize: 12, color: Color(0xFF5D6B64)),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.isContractor
                                  ? 'Client ko rate karein — timely payment, clear instructions aur cooperation par.'
                                  : 'Thekaydaar ko rate karein — on-time delivery, work quality aur communication par.',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF5D6B64)),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _openRatingSheet(contract),
                                icon: const Icon(Icons.star_rounded, size: 18),
                                label: const Text(
                                  'Give Rating',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kAmber,
                                  foregroundColor: kNavy,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],

              _card(
                title: 'Signatures',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _signatureRow(
                      'Client',
                      contract.clientSignature.agreed,
                      contract.clientSignature.fullName,
                    ),
                    const Divider(),
                    _signatureRow(
                      'Contractor',
                      contract.contractorSignature.agreed,
                      contract.contractorSignature.fullName,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              if (!myAgreed && contract.status == 'pending_signatures')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSigning ? null : _confirmSignDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAmber,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isSigning
                        ? const CircularProgressIndicator(color: kNavy)
                        : const Text(
                            'Sign This Agreement',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: kNavy,
                            ),
                          ),
                  ),
                ),

              if (contract.status == 'active' ||
                  contract.status == 'work_completed' ||
                  contract.status == 'payment_submitted' ||
                  contract.status == 'completed') ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _raiseDisputeDialog,
                  icon: const Icon(
                    Icons.report_problem_outlined,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Raise a Dispute',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                if (contract.status == 'completed' &&
                    contract.legalTerms.warrantyDays > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'Warranty window: ${contract.legalTerms.warrantyDays} din tak free repair claim kar sakte hain.',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
              // ── Print / Download Contract ──────────────────────────────
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isGeneratingPdf
                      ? null
                      : () => _downloadContractPdf(contract),
                  icon: _isGeneratingPdf
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.print_outlined, size: 18),
                  label: const Text(
                    'Print / Download Contract (PDF)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kNavy,
                    side: const BorderSide(color: kNavy),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
            ),
          );
        },
      ),
    );
  }

  // ── Escrow status card ─────────────────────────────────────────────
  Widget _buildEscrowCard(ContractModel contract) {
    final total = contract.totalAmount;
    final rate = contract.commissionRate;
    final commission = total * rate;
    final payout = total - commission;
    final escrow = contract.escrowStatus;

    Color escrowColor;
    IconData escrowIcon;
    String escrowLabel;
    String escrowMsg;

    switch (escrow) {
      case 'client_paid':
        escrowColor = kAmber;
        escrowIcon = Icons.hourglass_top_rounded;
        escrowLabel = 'Payment Received';
        escrowMsg = 'Funds held securely by Thekaydaar.pk. Admin verification pending.';
        break;
      case 'escrow_holding':
        escrowColor = const Color(0xFF1A5C46);
        escrowIcon = Icons.verified_user_rounded;
        escrowLabel = 'Escrow Holding';
        escrowMsg = 'Payment verified and held securely. Will be released on project confirmation.';
        break;
      case 'payout_released':
        escrowColor = kGreen;
        escrowIcon = Icons.check_circle_rounded;
        escrowLabel = 'Payout Released';
        escrowMsg = widget.isContractor
            ? 'Your payout of Rs. ${payout.toStringAsFixed(0)} has been released.'
            : 'Payment released to contractor after ${(rate * 100).toStringAsFixed(1)}% platform fee.';
        break;
      default:
        escrowColor = Colors.grey;
        escrowIcon = Icons.lock_outline_rounded;
        escrowLabel = 'Escrow';
        escrowMsg = 'Escrow not started.';
    }

    return _card(
      title: 'Escrow Payment',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: escrowColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: escrowColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(escrowIcon, size: 18, color: escrowColor),
                const SizedBox(width: 8),
                Text(
                  escrowLabel,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: escrowColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(escrowMsg, style: const TextStyle(fontSize: 12, color: Color(0xFF5D6B64))),
          const SizedBox(height: 14),

          // Payment breakdown
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F5EF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                _amountRow('Total Amount', 'Rs. ${total.toStringAsFixed(0)}', false),
                const SizedBox(height: 6),
                _amountRow(
                  'Platform Fee (${(rate * 100).toStringAsFixed(1)}%)',
                  '- Rs. ${commission.toStringAsFixed(0)}',
                  false,
                  color: Colors.red.shade700,
                ),
                const Divider(height: 16),
                _amountRow(
                  'Contractor Payout',
                  'Rs. ${payout.toStringAsFixed(0)}',
                  true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(String label, String value, bool bold, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? const Color(0xFF0E3B2E),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 14 : 12,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? const Color(0xFF0E3B2E),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionSection(ContractModel contract) {
    if (contract.status == 'active') {
      if (widget.isContractor) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isMarkingComplete ? null : _confirmMarkComplete,
            icon: _isMarkingComplete
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.task_alt_rounded, size: 16),
            label: const Text('Mark Project Complete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kNavy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      }
      return const Text(
        'Waiting for the contractor to mark the project complete.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    if (contract.status == 'work_completed') {
      if (!widget.isContractor) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total amount: Rs. ${contract.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kaam mukammal ho chuka hai. Neeche di gayi admin details par '
              'poori amount bhej kar transaction ID submit karein.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'EasyPaisa', child: Text('EasyPaisa')),
                DropdownMenuItem(value: 'JazzCash', child: Text('JazzCash')),
              ],
              onChanged: (v) =>
                  setState(() => _selectedMethod = v ?? 'EasyPaisa'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _txnIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Transaction ID',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmittingPayment ? null : _submitPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSubmittingPayment
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Submit Payment'),
              ),
            ),
          ],
        );
      }
      return const Text(
        'Kaam complete mark ho chuka hai. Client ko payment submit karne ka '
        'intezar hai.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    if (contract.status == 'payment_submitted') {
      return Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 16, color: kAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Payment submitted (${contract.paymentMethod} — ${contract.paymentTxnId}). '
              'Admin verification ka intezar hai.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.verified_rounded, size: 16, color: kGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.isContractor && contract.contractorPayoutAmount != null
                ? 'Payment confirmed. Aapka share: Rs. ${contract.contractorPayoutAmount!.toStringAsFixed(0)}'
                : 'Payment confirmed and project closed.',
            style: const TextStyle(
              fontSize: 12,
              color: kGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _signatureRow(String role, bool agreed, String name) {
    return Row(
      children: [
        Icon(
          agreed ? Icons.verified : Icons.pending_outlined,
          color: agreed ? kGreen : Color(0xFFA6B2AB),
          size: 20,
        ),
        const SizedBox(width: 8),
        Text('$role: '),
        Text(
          agreed ? '$name (Signed)' : 'Not signed yet',
          style: TextStyle(
            color: agreed ? Colors.black : Color(0xFFA6B2AB),
            fontWeight: agreed ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: kNavy,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
