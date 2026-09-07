import 'package:flutter/material.dart';

import 'package:ali_app/profile_sub_pages/project_model.dart';

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  // ── Brand design system (Navy / Amber) — matches rest of the app ──
  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _amberLight = Color(0xFFFBF6E3);
  static const _white = Color(0xFFFFFFFF);
  static const _sub = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _fill = Color(0xFFF7F5EF);
  static const _bg = Color(0xFFF7F5EF);
  static const _green = Color(0xFF10B981); // success/completed only
  static const _red = Color(0xFFDC2626);

  int _galleryIndex = 0;

  ProjectModel get project => widget.project;

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

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _fill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: _navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: _sub)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Open full-screen photo viewer ─────────────────────────────
  void _openFullScreenGallery(List<String> images, int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          images: images,
          initialIndex: startIndex,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  // ── Hero image + thumbnail strip ───────────────────────────────
  Widget _buildGallery() {
    // Combine coverImage first, then any other images (de-duplicated).
    final List<String> images = [];
    if (project.coverImage.isNotEmpty) images.add(project.coverImage);
    for (final img in project.images) {
      if (!images.contains(img)) images.add(img);
    }

    if (images.isEmpty) {
      return Container(
        width: double.infinity,
        height: 200,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction_rounded, size: 34, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No photos added for this project',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    final safeIndex = _galleryIndex.clamp(0, images.length - 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Hero image
          GestureDetector(
            onTap: () => _openFullScreenGallery(images, safeIndex),
            child: Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    images[safeIndex],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: _fill,
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: _amber,
                            strokeWidth: 2.5,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => Container(
                      color: _fill,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        size: 34,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.photo_library_rounded,
                          size: 13,
                          color: _white,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${safeIndex + 1}/${images.length}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Thumbnail strip
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final selected = i == safeIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _galleryIndex = i),
                      child: Container(
                        width: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected ? _amber : _border,
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            images[i],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: _fill,
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(project.status);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Project Details',
          style: TextStyle(color: _white, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: _navy,
        iconTheme: const IconThemeData(color: _white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo gallery
            _buildGallery(),

            // Header card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: _navy,
                          ),
                        ),
                      ),
                      if (project.urgentRequired) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.bolt, size: 16, color: _red),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _statusIcon(project.status),
                              size: 12,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              project.status.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.location_on_outlined, size: 14, color: _sub),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${project.area}, ${project.city}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _sub, fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Description card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _sub,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.description,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: _navy,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Budget & bids card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _amberLight,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _amber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Budget & Bids',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _sub,
                    ),
                  ),
                  _infoRow(
                    Icons.attach_money,
                    'Budget Range',
                    '${_formatCurrency(project.budgetMin)} - ${_formatCurrency(project.budgetMax)}',
                  ),
                  _infoRow(
                    Icons.people_outline,
                    'Total Bids',
                    '${project.bidCount}',
                  ),
                ],
              ),
            ),

            if (project.hasAcceptedBid) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _green.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 22, color: _green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Accepted Contractor',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _green,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            project.acceptedTkName ??
                                project.acceptedBid?.theekaydaarName ??
                                'N/A',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                          Text(
                            _formatCurrency(project.acceptedAmount ?? ''),
                            style: const TextStyle(fontSize: 13, color: _green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Full-screen photo viewer — swipe through all project photos, pinch to zoom.
// ============================================================================
class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({required this.images, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late final PageController _controller;
  late int _index;

  static const _white = Color(0xFFFFFFFF);
  static const _amber = Color(0xFFC9A227);

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: _white),
        title: Text(
          '${_index + 1} / ${widget.images.length}',
          style: const TextStyle(color: _white, fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: Center(
              child: Image.network(
                widget.images[i],
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const CircularProgressIndicator(color: _amber);
                },
                errorBuilder: (context, error, stack) => const Icon(
                  Icons.image_not_supported_outlined,
                  color: _white,
                  size: 40,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}