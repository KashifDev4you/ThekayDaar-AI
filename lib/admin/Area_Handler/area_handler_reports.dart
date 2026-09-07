import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class AreaHandlerReportsScreen extends StatelessWidget {
  final String city, area;
  const AreaHandlerReportsScreen(
      {super.key, required this.city, required this.area});

  static const Color _navy  = Color(0xFF0E3B2E);

  static const Color _white = Color(0xFFFFFFFF);
  static const Color _bg    = Color(0xFFF7F5EF);

  Future<void> _escalate(BuildContext ctx, String issue) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await FirebaseFirestore.instance
        .collection('escalations')
        .add({
      'fromUid'  : uid,
      'city'     : city,
      'area'     : area,
      'issue'    : issue,
      'status'   : 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
        content: Text('Escalated to Super Admin ✓'),
        backgroundColor: Color(0xFF0E3B2E),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Area Reports',
            style: TextStyle(
                color: _white,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live stat cards
          const _SectionTitle('Live Statistics'),
          const SizedBox(height: 10),
          _LiveStatsGrid(city: city),
          const SizedBox(height: 24),

          // Escalation section
          const _SectionTitle('Escalate to Super Admin'),
          const SizedBox(height: 10),
          _EscalateCard(
            icon: Icons.report_problem_outlined,
            title: 'Suspicious activity',
            subtitle: 'Flag fraudulent users or gigs',
            color: Colors.redAccent,
            onTap: () =>
                _escalate(context, 'Suspicious activity'),
          ),
          const SizedBox(height: 8),
          _EscalateCard(
            icon: Icons.bug_report_outlined,
            title: 'Technical issue',
            subtitle:
                'Report a platform bug or data error',
            color: const Color(0xFFC9A227),
            onTap: () =>
                _escalate(context, 'Technical issue'),
          ),
          const SizedBox(height: 8),
          _EscalateCard(
            icon: Icons.group_add_outlined,
            title: 'Resource request',
            subtitle: 'Request more admin support',
            color: const Color(0xFFC9A227),
            onTap: () =>
                _escalate(context, 'Resource request'),
          ),
          const SizedBox(height: 8),
          _EscalateCard(
            icon: Icons.edit_note_rounded,
            title: 'Custom report',
            subtitle: 'Write a detailed escalation note',
            color: const Color(0xFF1A5C46),
            onTap: () => _customEscalate(context),
          ),
          const SizedBox(height: 24),

          // Past escalations
          const _SectionTitle('My Escalations'),
          const SizedBox(height: 10),
          _PastEscalations(city: city, area: area),
        ],
      ),
    );
  }

  void _customEscalate(BuildContext ctx) {
    final ctrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Custom Escalation',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe the issue…',
            hintStyle: TextStyle(
                color: Colors.grey.shade400, fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF7F5EF),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFFC9A227), width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Color(0xFF5D6B64))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (ctrl.text.trim().isNotEmpty) {
                _escalate(ctx, ctrl.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0E3B2E),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Send',
                style:
                    TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _LiveStatsGrid extends StatelessWidget {
  final String city;
  const _LiveStatsGrid({required this.city});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _MiniStat(
          label: 'Total users',
          color: const Color(0xFF1A5C46),
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('operationalCity', isEqualTo: city)
              .snapshots(),
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _MiniStat(
          label: 'Active gigs',
          color: const Color(0xFF10B981),
          stream: FirebaseFirestore.instance
              .collection('gigs')
              .where('isActive', isEqualTo: true)
              .snapshots(),
        )),
        const SizedBox(width: 10),
        Expanded(
            child: _MiniStat(
          label: 'Payments',
          color: const Color(0xFFC9A227),
          stream: FirebaseFirestore.instance
              .collection('payment_requests')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
        )),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final Color color;
  final Stream<QuerySnapshot> stream;
  const _MiniStat(
      {required this.label,
      required this.color,
      required this.stream});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E0D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (_, s) {
              final n =
                  s.hasData ? s.data!.docs.length : 0;
              return Text('$n',
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w800));
            },
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFFA6B2AB),
                  fontSize: 11)),
        ],
      ),
    );
  }
}

class _EscalateCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _EscalateCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFE3E0D5)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2A26))),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFA6B2AB))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: Color(0xFFA9B5AE)),
          ],
        ),
      ),
    );
  }
}

class _PastEscalations extends StatelessWidget {
  final String city, area;
  const _PastEscalations(
      {required this.city, required this.area});

  @override
  Widget build(BuildContext context) {
    final uid =
        FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('escalations')
          .where('fromUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Text('No escalations yet.',
              style: TextStyle(
                  color: Color(0xFFA6B2AB), fontSize: 13));
        }
        return Column(
          children: snap.data!.docs.map((d) {
            final data =
                d.data() as Map<String, dynamic>;
            final status =
                data['status'] as String? ?? '—';
            final issue =
                data['issue'] as String? ?? '—';
            final ts = data['createdAt'] as Timestamp?;
            final dateStr = ts != null
                ? '${ts.toDate().day}/${ts.toDate().month}'
                : '—';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFE3E0D5)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(issue,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                  color:
                                      Color(0xFF1F2A26))),
                          Text(dateStr,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color:
                                      Color(0xFFA6B2AB))),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (status == 'resolved'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFC9A227))
                            .withValues(alpha: 0.1),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: status == 'resolved'
                              ? const Color(0xFF10B981)
                              : const Color(0xFFA8861D),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xFF1F2A26),
          fontSize: 14,
          fontWeight: FontWeight.w700));
}