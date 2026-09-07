import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ali_app/services/contract_services.dart';

const _navy = Color(0xFF0E3B2E);
const _amber = Color(0xFFC9A227);
const _amberD = Color(0xFFA8861D);
const _amberL = Color(0xFFFBF6E3);
const _green = Color(0xFF10B981);
const _greenL = Color(0xFFD1FAE5);
const _red = Color(0xFFDC2626);
const _redL = Color(0xFFFEF2F2);
const _border = Color(0xFFE3E0D5);
const _surface = Color(0xFFF7F5EF);
const _white = Color(0xFFFFFFFF);
const _textPri = Color(0xFF0E3B2E);
const _textSec = Color(0xFF5D6B64);

class AdminPaymentsScreen extends StatefulWidget {
  final String city;
  final String area;
  const AdminPaymentsScreen({
    super.key,
    required this.city,
    required this.area,
  });

  @override
  State<AdminPaymentsScreen> createState() => _AdminPaymentsScreenState();
}

class _AdminPaymentsScreenState extends State<AdminPaymentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Approve ───────────────────────────────────────────────────────────────
  // Branches based on request `type`. Contract payouts (type ==
  // 'contract_payment') need a commission entry + a ContractService call to
  // actually close out the job/project. Everything else (plan-activation
  // requests, which have no `type` field on older docs) keeps the original
  // behaviour untouched.
  Future<void> _approve(String docId, Map<String, dynamic> data) async {
    final isContractPayment = data['type'] == 'contract_payment';

    if (isContractPayment) {
      await _approveContractPayment(docId, data);
      return;
    }

    final confirm = await _confirm(
      context,
      'Approve Payment',
      'Activate this plan for the user?',
      true,
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance
        .collection('payment_requests')
        .doc(docId)
        .update({
          'status': 'approved',
          'activated': false, // explicitly false so listener picks it up
          'reviewedAt': FieldValue.serverTimestamp(),
        });
    if (mounted) {
      _snack(
        'Payment approved — plan will activate automatically.',
        success: true,
      );
    }
  }

  Future<void> _approveContractPayment(String docId, Map<String, dynamic> data) async {
    final contractId = data['contractId'] as String? ?? '';
    if (contractId.isEmpty) {
      _snack('This request is missing its contract reference.');
      return;
    }

    final totalAmount = double.tryParse(
          (data['amount'] as String? ?? '').replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0;

    final commissionCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Payout', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total received: Rs $totalAmount', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            const Text(
              'Apna commission amount daaliye — baaki contractor ko manually send karein.',
              style: TextStyle(fontSize: 12, color: _textSec),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commissionCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Commission Amount (Rs)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: _white),
            child: const Text('Confirm Payout'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final commission = double.tryParse(commissionCtrl.text.trim()) ?? 0;

    try {
      await ContractService().confirmContractPayout(
        contractId: contractId,
        commissionAmount: commission,
      );
      await FirebaseFirestore.instance.collection('payment_requests').doc(docId).update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _snack('Payout confirmed — project marked completed.', success: true);
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  // ── Reject ────────────────────────────────────────────────────────────────
  Future<void> _reject(String docId, String uid, String collection) async {
    final confirm = await _confirm(
      context,
      'Reject Payment',
      'Reject this payment request? The user will be notified.',
      false,
    );
    if (confirm != true) return;

    // Normalize collection name in case old docs saved wrong value
    final safeCollection = collection == 'client'
        ? 'clients'
        : collection == 'thekaydaar'
        ? 'thekaydaars'
        : collection;

    final batch = FirebaseFirestore.instance.batch();

    // Update payment_requests — set activated:true so listener NEVER touches it
    batch.update(
      FirebaseFirestore.instance.collection('payment_requests').doc(docId),
      {
        'status': 'rejected',
        'activated': true, // permanently ignored by billing listener
        'reviewedAt': FieldValue.serverTimestamp(),
      },
    );

    // Clear pending flag from user doc only if collection is valid
    if (safeCollection.isNotEmpty) {
      batch.update(
        FirebaseFirestore.instance.collection(safeCollection).doc(uid),
        {'paymentPending': false, 'pendingPlan': FieldValue.delete()},
      );
    }

    await batch.commit();
    if (mounted) _snack('Payment rejected.');
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: _white,
        elevation: 0,
        title: const Text(
          'Payment Requests',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _amber,
          unselectedLabelColor: const Color(0xFFA6B2AB),
          indicatorColor: _amber,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _RequestList(
            status: 'pending',
            city: widget.city,
            area: widget.area,
            onApprove: _approve,
            onReject: _reject,
          ),
          _RequestList(
            status: 'approved',
            city: widget.city,
            area: widget.area,
            onApprove: _approve,
            onReject: _reject,
          ),
          _RequestList(
            status: 'rejected',
            city: widget.city,
            area: widget.area,
            onApprove: _approve,
            onReject: _reject,
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirm(
    BuildContext context,
    String title,
    String message,
    bool isApprove,
  ) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: _white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: _textPri,
        ),
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 13, color: _textSec, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: _textSec)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: isApprove ? _green : _red,
            foregroundColor: _white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            isApprove ? 'Approve' : 'Reject',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: _white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: success ? _green : _amberD,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// =============================================================================
// _RequestList
// =============================================================================
class _RequestList extends StatelessWidget {
  final String status;
  final String city;
  final String area;
  final Future<void> Function(String docId, Map<String, dynamic> data) onApprove;
  final Future<void> Function(String docId, String uid, String collection)
  onReject;

  const _RequestList({
    required this.status,
    required this.city,
    required this.area,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payment_requests')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _amber));
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    status == 'pending'
                        ? Icons.hourglass_empty_rounded
                        : status == 'approved'
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
                    size: 32,
                    color: _textSec,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No $status requests',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final doc = docs[i];
            final d = doc.data() as Map<String, dynamic>;
            final isContractPayment = d['type'] == 'contract_payment';

            final uid = d['uid'] as String? ?? '';
            final userName =
                d['userName'] as String? ??
                d['clientName'] as String? ??
                d['fullName'] as String? ??
                '';
            final userPhone =
                d['userPhone'] as String? ?? d['phone'] as String? ?? '';
            final planLabel = d['planLabel'] as String? ?? d['plan'] ?? '';
            final amount = d['amount'] as String? ?? '';
            final method = d['method'] as String? ?? '';
            final txnId = d['txnId'] as String? ?? '';
            final ts = d['requestedAt'] as Timestamp?;
            final date = ts != null
                ? '${ts.toDate().day}/${ts.toDate().month}/'
                      '${ts.toDate().year} '
                      '${ts.toDate().hour}:'
                      '${ts.toDate().minute.toString().padLeft(2, '0')}'
                : '—';

            // Normalize role → correct collection name
            final rawRole = d['role'] as String? ?? '';
            final role = rawRole == 'client'
                ? 'clients'
                : rawRole == 'thekaydaar'
                ? 'thekaydaars'
                : rawRole;
            final isThekaydaar = role == 'thekaydaars';

            return Container(
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isContractPayment ? _green.withValues(alpha: 0.4) : _border,
                  width: isContractPayment ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  // ── Header ────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _surface.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(13),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isContractPayment
                                ? _greenL
                                : isThekaydaar
                                ? _amberL
                                : const Color(0xFFE7F2ED),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isContractPayment
                                ? Icons.handshake_rounded
                                : isThekaydaar
                                ? Icons.construction_rounded
                                : Icons.business_center_outlined,
                            size: 18,
                            color: isContractPayment
                                ? _green
                                : isThekaydaar
                                ? _amberD
                                : const Color(0xFF1A5C46),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      planLabel,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _textPri,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isContractPayment
                                          ? _greenL
                                          : isThekaydaar
                                          ? _amberL
                                          : const Color(0xFFE7F2ED),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      isContractPayment
                                          ? 'Contract Payout'
                                          : isThekaydaar
                                          ? 'Thekaydaar'
                                          : 'Client',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: isContractPayment
                                            ? _green
                                            : isThekaydaar
                                            ? _amberD
                                            : const Color(0xFF1A5C46),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                amount,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _amberD,
                                ),
                              ),
                              if (userName.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    userName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _textPri,
                                    ),
                                  ),
                                ),
                              if (userPhone.isNotEmpty)
                                Text(
                                  userPhone,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: _textSec,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        _statusBadge(status),
                      ],
                    ),
                  ),

                  // ── Details ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: Column(
                      children: [
                        _row(Icons.fingerprint_rounded, 'UID', uid),
                        const SizedBox(height: 6),
                        _row(
                          Icons.account_balance_wallet_outlined,
                          'Method',
                          method,
                        ),
                        const SizedBox(height: 6),
                        _row(
                          Icons.confirmation_number_outlined,
                          'TXN ID',
                          txnId,
                        ),
                        const SizedBox(height: 6),
                        _row(Icons.schedule_rounded, 'Requested', date),
                        if (isContractPayment) ...[
                          const SizedBox(height: 6),
                          _row(
                            Icons.construction_rounded,
                            'Contractor',
                            d['thekaydaarName'] as String? ?? '',
                          ),
                        ],

                        // Action buttons — pending only
                        if (status == 'pending') ...[
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: _border),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => onReject(doc.id, uid, role),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                  ),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _red,
                                    side: BorderSide(
                                      color: _red.withValues(alpha: 0.4),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => onApprove(doc.id, d),
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                  ),
                                  label: Text(
                                    isContractPayment ? 'Confirm Payout' : 'Approve',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _green,
                                    foregroundColor: _white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _row(IconData icon, String label, String value) => Row(
    children: [
      Icon(icon, size: 13, color: _textSec),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(fontSize: 11.5, color: _textSec)),
      Expanded(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _textPri,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );

  Widget _statusBadge(String status) {
    Color color;
    Color bg;
    IconData icon;
    switch (status) {
      case 'approved':
        color = _green;
        bg = _greenL;
        icon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        color = _red;
        bg = _redL;
        icon = Icons.cancel_rounded;
        break;
      default:
        color = _amberD;
        bg = _amberL;
        icon = Icons.hourglass_top_rounded;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}