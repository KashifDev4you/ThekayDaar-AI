import 'package:flutter/material.dart';

import 'package:ali_app/profile_sub_pages/project_model.dart';
import 'package:ali_app/profile_sub_pages/project/project_detail_screen.dart';
import 'package:ali_app/services/firestore_service.dart';
import 'package:ali_app/Widgets/language_toggle_widget.dart';

class MyProjectsScreen extends StatelessWidget {
  const MyProjectsScreen({super.key});

  // ── Brand design system (Navy / Amber) — matches rest of the app ──
  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _white = Color(0xFFFFFFFF);
  static const _sub = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _fill = Color(0xFFF7F5EF);
  static const _bg = Color(0xFFF7F5EF);
  static const _green = Color(0xFF10B981); // success/completed only
  static const _red = Color(0xFFDC2626);

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return _green;
      case 'active':
      case 'in_progress':
        return _navy;
      case 'pending':
        return _amber;
      default:
        return _sub;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'active':
      case 'in_progress':
        return Icons.sync_rounded;
      case 'pending':
        return Icons.hourglass_top_rounded;
      default:
        return Icons.circle;
    }
  }

  String _formatCurrency(String value) {
    final n = double.tryParse(value);
    if (n == null || value.isEmpty) return 'N/A';
    return 'PKR ${n.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return LanguageBuilder(
      builder: (context, t) {
        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            title: Text(
              t.t('My Projects'),
              style: const TextStyle(color: _white, fontWeight: FontWeight.w700),
            ),
            elevation: 0,
            backgroundColor: _navy,
            iconTheme: const IconThemeData(color: _white),
            centerTitle: true,
          ),
          body: StreamBuilder<List<ProjectModel>>(
            stream: FirestoreService.instance.streamMyProjects(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: _amber),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: _sub),
                  ),
                );
              }
              final projects = snapshot.data ?? [];
              if (projects.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: _fill,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.folder_off_outlined,
                          size: 38,
                          color: _sub,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.t('No projects yet.'),
                        style: const TextStyle(
                          color: _navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.t('Projects you post will show up here.'),
                        style: const TextStyle(color: _sub, fontSize: 12.5),
                      ),
                    ],
                  ),
                );
              }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: projects.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final p = projects[index];
              final statusColor = _statusColor(p.status);

              return Material(
                color: _white,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                child: InkWell(
                  splashColor: _amber.withValues(alpha: 0.08),
                  highlightColor: _amber.withValues(alpha: 0.05),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProjectDetailScreen(project: p),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left accent bar
                          Container(
                            width: 5,
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                              ),
                            ),
                          ),

                          // ── Cover photo thumbnail ──────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                width: 84,
                                height: 84,
                                child: (p.coverImage.isNotEmpty)
                                    ? Image.network(
                                        p.coverImage,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, progress) {
                                              if (progress == null) {
                                                return child;
                                              }
                                              return Container(
                                                color: _fill,
                                                child: const Center(
                                                  child: SizedBox(
                                                    width: 18,
                                                    height: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: _amber,
                                                        ),
                                                  ),
                                                ),
                                              );
                                            },
                                        errorBuilder: (context, error, stack) =>
                                            Container(
                                              color: _fill,
                                              child: Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                                color: Colors.grey[400],
                                                size: 26,
                                              ),
                                            ),
                                      )
                                    : Container(
                                        color: _fill,
                                        child: const Icon(
                                          Icons.construction_rounded,
                                          color: _navy,
                                          size: 26,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: _navy,
                                          ),
                                        ),
                                      ),
                                      if (p.urgentRequired)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            left: 6,
                                          ),
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: _red.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.bolt,
                                            size: 13,
                                            color: _red,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on_rounded,
                                        size: 13,
                                        color: _sub,
                                      ),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          '${p.area}, ${p.city}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _sub,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    p.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: _sub,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Status + budget chip row
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _statusIcon(p.status),
                                              size: 12,
                                              color: statusColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              p.status.toUpperCase(),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _fill,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.attach_money_rounded,
                                              size: 13,
                                              color: _navy,
                                            ),
                                            Text(
                                              '${_formatCurrency(p.budgetMin)}-${_formatCurrency(p.budgetMax)}',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: _navy,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _fill,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.people_alt_rounded,
                                              size: 13,
                                              color: _navy,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${p.bidCount} bids',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: _navy,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (p.hasAcceptedBid) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _green.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: _green,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '${p.acceptedTkName ?? p.acceptedBid?.theekaydaarName ?? ''} • ${_formatCurrency(p.acceptedAmount ?? '')}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: _green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        'View details',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
      },
    );
  }
}