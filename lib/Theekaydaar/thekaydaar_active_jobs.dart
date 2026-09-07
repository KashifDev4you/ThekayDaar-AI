import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:ali_app/contract/contract_detail_screen.dart';
import 'package:ali_app/model/contract_model.dart';
import 'package:ali_app/services/contract_services.dart';
import 'package:ali_app/rating_system/rating_sheet.dart';
import 'package:ali_app/MessageAndNotification/cloudinary_service.dart';
import 'package:ali_app/MessageAndNotification/cloudinary_config.dart';
import 'package:ali_app/utils/app_theme.dart';

// =============================================================================
// THEKAYDAAR ACTIVE JOBS SCREEN
// Shows all active jobs assigned to this thekaydaar. Completion is now
// milestone-driven (Advance/Mid/Final) instead of a single "Mark Complete"
// button — payment only releases per-milestone, after client approval.
// =============================================================================
class ThekaydaarActiveJobsScreen extends StatefulWidget {
  const ThekaydaarActiveJobsScreen({super.key});

  @override
  State<ThekaydaarActiveJobsScreen> createState() =>
      _ThekaydaarActiveJobsScreenState();
}

class _ThekaydaarActiveJobsScreenState extends State<ThekaydaarActiveJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _white = Color(0xFFFFFFFF);
  static const _bg = AppTheme.bg;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _jobsStream(String status) => FirebaseFirestore.instance
      .collection('active_jobs')
      .where('thekaydaarId', isEqualTo: _uid)
      .where('status', isEqualTo: status)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Jobs',
          style: TextStyle(
            color: _white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          labelColor: _amber,
          unselectedLabelColor: AppTheme.textMuted,
          indicatorColor: _amber,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _JobList(
            stream: _jobsStream('active'),
            emptyIcon: Icons.work_outline_rounded,
            emptyMsg:
                'No active jobs right now.\nBrowse projects and place bids!',
          ),
          _JobList(
            stream: _jobsStream('completed'),
            emptyIcon: Icons.check_circle_outline_rounded,
            emptyMsg: 'No completed jobs yet.',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// JOB LIST
// =============================================================================
class _JobList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final IconData emptyIcon;
  final String emptyMsg;

  static const _amber = Color(0xFFC9A227);
  static const _sub = Color(0xFF5D6B64);

  const _JobList({
    required this.stream,
    required this.emptyIcon,
    required this.emptyMsg,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _amber));
        }
        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        var docs = snap.data?.docs ?? [];
        docs.sort((a, b) {
          final aT = (a.data() as Map<String, dynamic>)['createdAt'];
          final bT = (b.data() as Map<String, dynamic>)['createdAt'];
          if (aT == null && bT == null) return 0;
          if (aT == null) return 1;
          if (bT == null) return -1;
          return (bT as Timestamp).compareTo(aT as Timestamp);
        });

        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(emptyIcon, size: 52, color: const Color(0xFFA9B5AE)),
                  const SizedBox(height: 14),
                  Text(
                    emptyMsg,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _sub,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final doc = docs[i];
            final d = doc.data() as Map<String, dynamic>;
            return _JobCard(jobId: doc.id, data: d);
          },
        );
      },
    );
  }
}

// =============================================================================
// JOB CARD — milestone-driven completion + rating
// =============================================================================
class _JobCard extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> data;

  const _JobCard({required this.jobId, required this.data});

  @override
  State<_JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<_JobCard> {
  final ContractService _contractService = ContractService();
  final CloudinaryService _cloudinary = CloudinaryService(
    cloudName: CloudinaryConfig.cloudName,
    uploadPreset: CloudinaryConfig.uploadPreset,
  );

  bool _loading = false;
  bool _uploadingMilestone = false;
  String? _contractId;

  static const _white = Color(0xFFFFFFFF);
  static const _label = Color(0xFF1F2A26);
  static const _sub = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _fill = AppTheme.bg;
  static const _green = Color(0xFF10B981);
  static const _amber = Color(0xFFC9A227);
  static const _navy = Color(0xFF0E3B2E);

  @override
  void initState() {
    super.initState();
    _findContract();
  }

  Future<void> _findContract() async {
    final projectId = widget.data['projectId'] as String? ?? '';
    if (projectId.isEmpty) return;
    final query = await FirebaseFirestore.instance
        .collection('contracts')
        .where('projectId', isEqualTo: projectId)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty && mounted) {
      setState(() => _contractId = query.docs.first.id);
    }
  }

  Future<void> _completeMilestone(int index) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (picked == null) return;

    setState(() => _uploadingMilestone = true);
    try {
      // ADJUST if your CloudinaryService method has a different name/signature.
      final url = await _cloudinary.uploadImage(File(picked.path));

      await _contractService.markMilestoneComplete(
        contractId: _contractId!,
        milestoneIndex: index,
        proofImageUrl: url,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milestone submitted — waiting for client approval.'),
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
      if (mounted) setState(() => _uploadingMilestone = false);
    }
  }

  Future<void> _openContract() async {
    if (_contractId == null) return;
    setState(() => _loading = true);
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final contractorName = widget.data['thekaydaarName'] as String? ?? '';
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContractDetailScreen(
              contractId: _contractId!,
              currentUserId: currentUid,
              currentUserFullName: contractorName,
              isContractor: true,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final title = d['projectTitle'] as String? ?? 'Project';
    final clientName = d['clientName'] as String? ?? '—';
    final amount = d['amount'] as String? ?? '—';
    final area = d['area'] as String? ?? '—';
    final city = d['city'] as String? ?? '';
    final days = d['completionDays'] as String? ?? '—';
    final status = d['status'] as String? ?? 'active';
    final isActive = status == 'active';
    final isCompleted = status == 'completed';
    final statusColor = isActive
        ? _amber
        : isCompleted
        ? _green
        : _sub;
    final statusLabel = isActive
        ? 'Active'
        : isCompleted
        ? 'Completed'
        : status;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? _amber.withValues(alpha: 0.3) : _border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isActive
                            ? Icons.construction_rounded
                            : Icons.check_circle_rounded,
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _label,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Client: $clientName',
                            style: const TextStyle(fontSize: 12, color: _sub),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _fill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _stat('Rs $amount', 'Payment'),
                      _vDiv(),
                      _stat(
                        '$area${city.isNotEmpty ? ', $city' : ''}',
                        'Location',
                      ),
                      _vDiv(),
                      _stat('$days days', 'Timeline'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: (_loading || _contractId == null)
                    ? null
                    : _openContract,
                icon: const Icon(Icons.description_outlined, size: 16),
                label: const Text(
                  'View Work Agreement',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: _navy),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),

          if (isActive) ...[
            const SizedBox(height: 14),
            if (_contractId == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _fill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Work agreement not created yet for this job.',
                    style: TextStyle(fontSize: 12, color: _sub),
                  ),
                ),
              )
            else
              StreamBuilder<ContractModel?>(
                stream: _contractService.streamContract(_contractId!),
                builder: (_, snap) {
                  if (!snap.hasData || snap.data == null) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: LinearProgressIndicator(
                        color: _amber,
                        minHeight: 2,
                      ),
                    );
                  }
                  final contract = snap.data!;

                  if (!contract.isFullySigned) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Waiting for both parties to sign the work agreement.',
                          style: TextStyle(fontSize: 12, color: _label),
                        ),
                      ),
                    );
                  }

                  final nextIndex = contract.milestones.indexWhere(
                    (m) => m.status != 'paid',
                  );

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MILESTONES',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _sub,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...contract.milestones.asMap().entries.map((e) {
                          final i = e.key;
                          final m = e.value;
                          final isNext = i == nextIndex;
                          final isPaid = m.status == 'paid';
                          final isAwaiting = m.status == 'awaiting_approval';
                          Color dotColor = isPaid
                              ? _green
                              : isAwaiting
                              ? _amber
                              : (isNext ? _navy : _border);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${m.title} — Rs ${m.amount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isPaid || isAwaiting
                                          ? _sub
                                          : _label,
                                    ),
                                  ),
                                ),
                                if (isPaid)
                                  const Text(
                                    'Paid',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _green,
                                    ),
                                  )
                                else if (isAwaiting)
                                  const Text(
                                    'Awaiting approval',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _amber,
                                    ),
                                  )
                                else if (isNext)
                                  SizedBox(
                                    height: 30,
                                    child: ElevatedButton(
                                      onPressed: _uploadingMilestone
                                          ? null
                                          : () => _completeMilestone(i),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _navy,
                                        foregroundColor: _white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: _uploadingMilestone
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                color: _white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'Mark Done',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  )
                                else
                                  const Text(
                                    'Locked',
                                    style: TextStyle(fontSize: 11, color: _sub),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
          ] else if (isCompleted) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _green.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _green.withValues(alpha: 0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_rounded, color: _green, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'All Milestones Paid',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('projects')
                        .doc(d['projectId'])
                        .get(),
                    builder: (_, snap) {
                      final projectData =
                          snap.data?.data() as Map<String, dynamic>?;
                      final alreadyRated =
                          projectData?['contractorRated'] == true;

                      if (alreadyRated) {
                        return Row(
                          children: const [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: _green,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'You rated this client',
                              style: TextStyle(
                                fontSize: 12,
                                color: _green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      }

                      return SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: ElevatedButton.icon(
                          onPressed: _contractId == null
                              ? null
                              : () async {
                                  final currentUid =
                                      FirebaseAuth.instance.currentUser?.uid ??
                                      '';
                                  await showRateClientSheet(
                                    context: context,
                                    projectId: d['projectId'] as String? ?? '',
                                    contractId: _contractId!,
                                    clientId: d['clientId'] as String? ?? '',
                                    clientName:
                                        d['clientName'] as String? ?? '',
                                    thekaydaarId: currentUid,
                                    thekaydaarName:
                                        d['thekaydaarName'] as String? ?? '',
                                  );
                                },
                          icon: const Icon(Icons.star_rounded, size: 18),
                          label: const Text(
                            'Rate Client',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _amber,
                            foregroundColor: _navy,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: _label,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: _sub)),
      ],
    ),
  );

  Widget _vDiv() => Container(
    width: 1,
    height: 32,
    color: const Color(0xFFE3E0D5),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );
}
